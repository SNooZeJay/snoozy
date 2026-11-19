import AVFoundation
import Foundation

public struct AudioMeterReadings: Equatable, Sendable {
    public let averageLeftDb: Float
    public let averageRightDb: Float
    public let peakLeftDb: Float
    public let peakRightDb: Float

    public static let silence = AudioMeterReadings(
        averageLeftDb: -80,
        averageRightDb: -80,
        peakLeftDb: -80,
        peakRightDb: -80
    )
}

public enum SnoozyAudioEngineError: LocalizedError {
    case noPreparedTrack
    case invalidAudioFile

    public var errorDescription: String? {
        switch self {
        case .noPreparedTrack:
            return "The next track was not prepared for a transition."
        case .invalidAudioFile:
            return "The audio file has no playable samples."
        }
    }
}

/// Lock-protected meter mailbox so the audio render thread never touches the
/// main actor. The playback timer reads the latest snapshot on the main thread.
final class AudioMeterStore: @unchecked Sendable {
    private let lock = NSLock()
    private var readings: AudioMeterReadings = .silence

    func store(_ value: AudioMeterReadings) {
        lock.lock()
        readings = value
        lock.unlock()
    }

    func latest() -> AudioMeterReadings {
        lock.lock()
        defer { lock.unlock() }
        return readings
    }

    static func measure(_ buffer: AVAudioPCMBuffer, into store: AudioMeterStore) {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else {
            store.store(.silence)
            return
        }
        let frameCount = Int(buffer.frameLength)
        let channelCount = min(2, Int(buffer.format.channelCount))
        guard channelCount > 0 else {
            store.store(.silence)
            return
        }

        var averageDb = [Float](repeating: -80, count: 2)
        var peakDb = [Float](repeating: -80, count: 2)

        for channel in 0..<channelCount {
            let samples = channels[channel]
            var sum: Float = 0
            var peak: Float = 0
            for frame in 0..<frameCount {
                let sample = samples[frame]
                sum += sample * sample
                peak = max(peak, abs(sample))
            }
            let rms = sqrt(sum / Float(frameCount))
            averageDb[channel] = decibels(rms)
            peakDb[channel] = decibels(peak)
        }

        if channelCount == 1 {
            averageDb[1] = averageDb[0]
            peakDb[1] = peakDb[0]
        }

        store.store(AudioMeterReadings(
            averageLeftDb: averageDb[0],
            averageRightDb: averageDb[1],
            peakLeftDb: peakDb[0],
            peakRightDb: peakDb[1]
        ))
    }

    private static func decibels(_ value: Float) -> Float {
        guard value > 0.000_000_1 else { return -80 }
        return Float(20.0 * log10(Double(value)))
    }
}

/// Dual-node playback graph: two player nodes feed one mixer, then the shared
/// ten-band equalizer, varispeed, and a safety limiter before the output.
@MainActor
public final class SnoozyAudioEngine {
    public var onTrackFinished: (() -> Void)?

    public var hasScheduledTrack: Bool { activeFile != nil && activeDuration > 0 }
    public var hasPreparedNextTrack: Bool { idleFile != nil }
    public var duration: Double { activeDuration }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: EqualizerBands.count)
    private let varispeed = AVAudioUnitVarispeed()
    private let limiter = AVAudioUnitDynamicsProcessor()
    private let meterStore = AudioMeterStore()

    private var activePlayer: AVAudioPlayerNode
    private var idlePlayer: AVAudioPlayerNode
    private var activeFile: AVAudioFile?
    private var idleFile: AVAudioFile?
    private var activeStartSeconds: Double = 0
    private var activeDuration: Double = 0
    private var idleDuration: Double = 0
    private var pausedPosition: Double = 0
    private var masterVolume: Double = 1.0

    private var activeToken: UUID?
    private var idleToken: UUID?
    private var isPlayingNode = false
    private var isTransitioning = false
    private var fadeTimer: Timer?
    private var fadeStartedAt: Date?
    private var fadeDuration: Double = 0
    private var transitionFinished: (() -> Void)?
    private var configurationObserver: NSObjectProtocol?

    private var eqRampTimer: Timer?
    private var eqRampStartedAt: Date?
    private var eqRampDuration: Double = 0.08
    private var appliedGains: [Double] = Array(repeating: 0.0, count: EqualizerBands.count)
    private var appliedPreamp: Double = 0.0
    private var rampStartGains: [Double] = Array(repeating: 0.0, count: EqualizerBands.count)
    private var rampStartPreamp: Double = 0.0
    private var targetGains: [Double] = Array(repeating: 0.0, count: EqualizerBands.count)
    private var targetPreamp: Double = 0.0

    public init() {
        activePlayer = playerA
        idlePlayer = playerB
        configureGraph()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleConfigurationChange()
            }
        }
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    // MARK: - Transport

    @discardableResult
    public func load(url: URL, startAt seconds: Double, rate: Double, volume: Double) throws -> Double {
        stopInternal()
        let file = try AVAudioFile(forReading: url)
        let duration = Self.duration(of: file)
        guard duration > 0 else {
            throw SnoozyAudioEngineError.invalidAudioFile
        }

        activePlayer = playerA
        idlePlayer = playerB
        connectOutput(of: activePlayer, for: file.processingFormat)
        activeFile = file
        activeDuration = duration
        masterVolume = Self.clampVolume(volume)
        varispeed.rate = Float(PlaybackQueueOps.clampPlaybackSpeed(rate))

        let start = (seconds > 0 && seconds < duration) ? seconds : 0.0
        activeStartSeconds = start
        pausedPosition = start
        activeToken = schedule(file, on: activePlayer, from: start)
        activePlayer.volume = Float(masterVolume)
        idlePlayer.volume = 0.0
        return duration
    }

    public func play() throws {
        try startEngineIfNeeded()
        guard activeFile != nil else { return }
        activePlayer.play()
        isPlayingNode = true
    }

    public func pause() {
        if isTransitioning {
            finishTransitionImmediately()
        }
        pausedPosition = currentTime()
        activePlayer.pause()
        idlePlayer.pause()
        isPlayingNode = false
        meterStore.store(.silence)
        if engine.isRunning {
            engine.pause()
        }
    }

    public func stop() {
        stopInternal()
        engine.stop()
    }

    public func seek(to seconds: Double) throws {
        guard let file = activeFile else { return }
        let wasPlaying = isPlayingNode
        let target = min(max(0.0, seconds), max(0.0, activeDuration - 0.05))
        activeToken = schedule(file, on: activePlayer, from: target)
        activeStartSeconds = target
        pausedPosition = target
        activePlayer.volume = Float(masterVolume)
        if wasPlaying {
            try startEngineIfNeeded()
            activePlayer.play()
        }
    }

    public func setRate(_ rate: Double) {
        varispeed.rate = Float(PlaybackQueueOps.clampPlaybackSpeed(rate))
    }

    public func setVolume(_ volume: Double) {
        masterVolume = Self.clampVolume(volume)
        if isTransitioning {
            stepFade()
        } else {
            activePlayer.volume = Float(masterVolume)
        }
    }

    public func currentTime() -> Double {
        guard activeFile != nil else { return 0.0 }
        guard activePlayer.isPlaying,
              let renderTime = activePlayer.lastRenderTime,
              let playerTime = activePlayer.playerTime(forNodeTime: renderTime),
              playerTime.sampleRate > 0
        else {
            return pausedPosition
        }
        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        return min(activeDuration, max(0.0, activeStartSeconds + elapsed))
    }

    public func latestMeterReadings() -> AudioMeterReadings {
        meterStore.latest()
    }

    // MARK: - Automix preparation

    @discardableResult
    public func preloadNext(url: URL) throws -> Double {
        guard !isTransitioning else { return idleDuration }
        let file = try AVAudioFile(forReading: url)
        let duration = Self.duration(of: file)
        guard duration > 0 else {
            throw SnoozyAudioEngineError.invalidAudioFile
        }
        connectOutput(of: idlePlayer, for: file.processingFormat)
        idleFile = file
        idleDuration = duration
        idlePlayer.volume = 0.0
        idleToken = schedule(file, on: idlePlayer, from: 0.0)
        return duration
    }

    public func cancelPreload() {
        guard !isTransitioning else { return }
        idlePlayer.stop()
        idlePlayer.volume = 0.0
        idleFile = nil
        idleDuration = 0
        idleToken = nil
    }

    public func startTransition(overlapSeconds: Double, onFinished: @escaping () -> Void) throws {
        guard !isTransitioning, idleFile != nil else {
            throw SnoozyAudioEngineError.noPreparedTrack
        }
        try startEngineIfNeeded()

        let outgoing = activePlayer
        let incoming = idlePlayer

        activeToken = nil
        activePlayer = incoming
        idlePlayer = outgoing
        activeFile = idleFile
        activeDuration = idleDuration
        activeStartSeconds = 0.0
        pausedPosition = 0.0
        idleFile = nil
        idleDuration = 0.0
        activeToken = idleToken
        idleToken = nil

        isTransitioning = true
        transitionFinished = onFinished
        fadeDuration = max(0.02, overlapSeconds)
        fadeStartedAt = Date()

        incoming.volume = 0.0
        outgoing.volume = Float(masterVolume)
        incoming.play()
        isPlayingNode = true

        stepFade()
        fadeTimer?.invalidate()
        fadeTimer = makeTimer(interval: 1.0 / 60.0, repeats: true) { [weak self] in
            self?.stepFade()
        }
    }

    // MARK: - Equalizer

    public func applyEqualizer(enabled: Bool, gainsDb: [Double], preampDb: Double) {
        let gains = EqualizerLogic.sanitizedGains(gainsDb)
        let effectivePreamp = EqualizerLogic.effectivePreampDb(
            userPreampDb: preampDb,
            gainsDb: gains
        )

        targetGains = enabled ? gains : Array(repeating: 0.0, count: EqualizerBands.count)
        targetPreamp = enabled ? effectivePreamp : 0.0
        rampStartGains = appliedGains
        rampStartPreamp = appliedPreamp
        eqRampStartedAt = Date()
        stepEqualizerRamp()

        eqRampTimer?.invalidate()
        eqRampTimer = makeTimer(interval: 1.0 / 60.0, repeats: true) { [weak self] in
            self?.stepEqualizerRamp()
        }
    }

    private func stepEqualizerRamp() {
        guard let startedAt = eqRampStartedAt else { return }
        let progress = min(1.0, max(0.0, Date().timeIntervalSince(startedAt) / max(0.01, eqRampDuration)))

        for index in 0..<EqualizerBands.count {
            let value = rampStartGains[index] + (targetGains[index] - rampStartGains[index]) * progress
            appliedGains[index] = value
            let band = equalizer.bands[index]
            band.bypass = false
            band.gain = Float(value)
        }
        let preamp = rampStartPreamp + (targetPreamp - rampStartPreamp) * progress
        appliedPreamp = preamp
        equalizer.globalGain = Float(preamp)

        if progress >= 1.0 {
            eqRampTimer?.invalidate()
            eqRampTimer = nil
            eqRampStartedAt = nil
        }
    }

    // MARK: - Graph

    private func configureGraph() {
        engine.attach(playerA)
        engine.attach(playerB)
        engine.attach(mixer)
        engine.attach(equalizer)
        engine.attach(varispeed)
        engine.attach(limiter)

        engine.connect(playerA, to: mixer, format: nil)
        engine.connect(playerB, to: mixer, format: nil)

        // The chain after the mixer uses the hardware input format so the
        // engine never negotiates a mismatched output connection at start.
        let hardware = engine.outputNode.inputFormat(forBus: 0)
        let chainFormat: AVAudioFormat? = hardware.sampleRate > 0 && hardware.channelCount > 0 ? hardware : nil
        engine.connect(mixer, to: equalizer, format: chainFormat)
        engine.connect(equalizer, to: varispeed, format: chainFormat)
        engine.connect(varispeed, to: limiter, format: chainFormat)
        engine.connect(limiter, to: engine.outputNode, format: chainFormat)

        for (index, frequency) in EqualizerBands.frequencies.enumerated() {
            let band = equalizer.bands[index]
            band.filterType = .parametric
            band.frequency = Float(frequency)
            band.bandwidth = 1.0
            band.gain = 0.0
            band.bypass = false
        }

        limiter.threshold = -3.0
        limiter.headRoom = 3.0
        limiter.expansionRatio = 1.0
        limiter.expansionThreshold = -60.0
        limiter.attackTime = 0.001
        limiter.releaseTime = 0.05
        limiter.masterGain = 0.0

        mixer.installTap(onBus: 0, bufferSize: 4_096, format: nil) { [meterStore] buffer, _ in
            AudioMeterStore.measure(buffer, into: meterStore)
        }
    }

    private func startEngineIfNeeded() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    /// Player nodes adopt their connection format. Files can differ in sample
    /// rate, so reconnect before scheduling instead of throwing at render time.
    private func connectOutput(of player: AVAudioPlayerNode, for format: AVAudioFormat) {
        if player.outputFormat(forBus: 0).isEqual(format) { return }
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: mixer, format: format)
    }

    private func handleConfigurationChange() {
        let position = currentTime()
        let wasPlaying = isPlayingNode
        let rate = varispeed.rate

        playerA.stop()
        playerB.stop()
        activeToken = nil
        idleToken = nil
        idleFile = nil
        idleDuration = 0
        idlePlayer.volume = 0.0

        do {
            try startEngineIfNeeded()
        } catch {
            isPlayingNode = false
            return
        }

        guard let file = activeFile, activeDuration > 0 else { return }
        activePlayer = playerA
        idlePlayer = playerB
        let target = min(max(0.0, position), max(0.0, activeDuration - 0.05))
        activeStartSeconds = target
        pausedPosition = target
        activeToken = schedule(file, on: activePlayer, from: target)
        activePlayer.volume = Float(masterVolume)
        varispeed.rate = rate

        if wasPlaying {
            activePlayer.play()
            isPlayingNode = true
        } else {
            isPlayingNode = false
        }
    }

    // MARK: - Scheduling

    private func schedule(_ file: AVAudioFile, on player: AVAudioPlayerNode, from seconds: Double) -> UUID {
        let token = UUID()
        player.stop()
        player.volume = 0.0

        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0, file.length > 0 else { return token }

        var startFrame = AVAudioFramePosition(max(0.0, seconds) * sampleRate)
        if startFrame >= file.length {
            startFrame = 0
        }
        let remaining = file.length - startFrame
        guard remaining > 0 else { return token }
        let frameCount = AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max)))

        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nodeDidFinish(token)
            }
        }
        return token
    }

    private func nodeDidFinish(_ token: UUID) {
        guard token == activeToken, isPlayingNode, !isTransitioning else { return }
        activeToken = nil
        isPlayingNode = false
        onTrackFinished?()
    }

    // MARK: - Crossfade

    private func stepFade() {
        guard isTransitioning, let startedAt = fadeStartedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        let progress = min(1.0, max(0.0, elapsed / max(0.02, fadeDuration)))
        let gains = AutomixLogic.equalPowerGains(progress: progress)

        idlePlayer.volume = Float(masterVolume * gains.outgoing)
        activePlayer.volume = Float(masterVolume * gains.incoming)

        if progress >= 1.0 {
            finishTransitionImmediately()
        }
    }

    private func finishTransitionImmediately() {
        guard isTransitioning else { return }
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadeStartedAt = nil
        idlePlayer.stop()
        idlePlayer.volume = 0.0
        activePlayer.volume = Float(masterVolume)
        isTransitioning = false
        let finished = transitionFinished
        transitionFinished = nil
        finished?()
    }

    private func stopInternal() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadeStartedAt = nil
        transitionFinished = nil
        isTransitioning = false

        playerA.stop()
        playerB.stop()
        playerA.volume = 0.0
        playerB.volume = 0.0

        activePlayer = playerA
        idlePlayer = playerB
        activeFile = nil
        idleFile = nil
        activeStartSeconds = 0.0
        activeDuration = 0.0
        idleDuration = 0.0
        pausedPosition = 0.0
        activeToken = nil
        idleToken = nil
        isPlayingNode = false
        meterStore.store(.silence)
    }

    // MARK: - Helpers

    private func makeTimer(interval: TimeInterval, repeats: Bool, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            Task { @MainActor in
                block()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private static func duration(of file: AVAudioFile) -> Double {
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0.0 }
        return Double(file.length) / sampleRate
    }

    private static func clampVolume(_ value: Double) -> Double {
        guard value.isFinite else { return 1.0 }
        return min(1.0, max(0.0, value))
    }
}
