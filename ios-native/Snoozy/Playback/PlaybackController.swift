import AVFoundation
import Combine
import Foundation
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
public final class PlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private let repository: LibraryRepository

    @Published public private(set) var activeTrack: Track? = nil
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var queueTracks: [Track] = []
    @Published public private(set) var queueIndex: Int = -1
    @Published public private(set) var positionSeconds: Double = 0.0
    @Published public private(set) var durationSeconds: Double = 0.0
    @Published public private(set) var repeatMode: RepeatState = .off
    @Published public private(set) var shuffle: Bool = false
    @Published public private(set) var playbackRate: Double = 1.0
    @Published public private(set) var volume: Double = 1.0
    @Published public private(set) var activeLyrics: ParsedLyrics? = nil
    @Published public private(set) var activePalette: ArtworkPalette = .emeraldDefault
    @Published public private(set) var audioLevels: AudioReactiveLevels = .zero
    @Published public var playbackError: String? = nil

    private var audioPlayer: AVAudioPlayer? = nil
    private var progressTimer: Timer? = nil
    private var ticksSinceSave: Int = 0
    private var coldStartRestored: Bool = false
    private var interruptionState = PlaybackInterruptionState()
    private var listeningTracker = PlaybackListeningTracker()
    private var sessionStartedAtMs: Int64? = nil
    private var originalQueueTracks: [Track] = []
    private var isAppInForeground: Bool = true
    private var cachedNowPlayingArtworkKey: String? = nil
    private var cachedNowPlayingArtwork: MPMediaItemArtwork? = nil
    private var notificationTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    public init(repository: LibraryRepository) {
        self.repository = repository
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        observeAudioNotifications()
        observeLibraryChanges()
    }

    deinit {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    public func restoreColdStartIfNeeded() {
        guard !coldStartRestored else { return }
        let tracks = repository.tracks
        guard !tracks.isEmpty else { return }
        coldStartRestored = true

        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let saved = repository.store.load().playbackSession
        guard let resolved = PlaybackQueueOps.resolvePlaybackSession(session: saved, tracksById: byId) else {
            return
        }

        self.originalQueueTracks = resolved.queueTracks
        self.queueTracks = resolved.queueTracks
        self.queueIndex = resolved.activeIndex
        self.activeTrack = resolved.activeTrack
        self.positionSeconds = resolved.positionSeconds
        self.durationSeconds = resolved.activeTrack.duration
        self.shuffle = resolved.shuffle
        self.repeatMode = resolved.repeatMode
        self.playbackRate = resolved.playbackRate

        preparePlayer(for: resolved.activeTrack, seekTo: resolved.positionSeconds, autoPlay: false)
        loadAuxiliaryTrackData(for: resolved.activeTrack)
        updateNowPlayingInfo()
    }

    public func prepareInitialTrackIfNeeded(_ track: Track, queue: [Track]) {
        guard activeTrack == nil else { return }
        let ordered = queue.isEmpty ? [track] : queue
        self.originalQueueTracks = ordered
        self.queueTracks = ordered
        self.queueIndex = ordered.firstIndex(where: { $0.id == track.id }) ?? 0
        self.activeTrack = track
        self.positionSeconds = 0.0
        self.durationSeconds = track.duration
        preparePlayer(for: track, seekTo: 0.0, autoPlay: false)
        loadAuxiliaryTrackData(for: track)
        persistSession()
    }

    public func playTrack(
        _ track: Track,
        queue: [Track] = [],
        shuffleOverride: Bool? = nil,
        repeatOverride: RepeatState? = nil
    ) {
        triggerHaptic(.light)
        flushCurrentPlayHistoryIfQualified()

        let baseQueue: [Track] = {
            if !queue.isEmpty {
                return queue.contains(where: { $0.id == track.id }) ? queue : ([track] + queue)
            }
            let all = repository.sortedSongs
            return all.contains(where: { $0.id == track.id }) ? all : [track]
        }()

        self.originalQueueTracks = baseQueue

        let nextShuffle = shuffleOverride ?? self.shuffle
        let nextRepeat = repeatOverride ?? self.repeatMode

        let orderedQueue: [Track]
        if nextShuffle {
            let others = baseQueue.filter { $0.id != track.id }.shuffled()
            orderedQueue = [track] + others
        } else {
            orderedQueue = baseQueue
        }

        let startIdx = orderedQueue.firstIndex(where: { $0.id == track.id }) ?? 0

        self.queueTracks = orderedQueue
        self.queueIndex = startIdx
        self.activeTrack = track
        self.shuffle = nextShuffle
        self.repeatMode = nextRepeat
        self.positionSeconds = 0.0
        self.durationSeconds = track.duration
        self.listeningTracker.start(atMs: 0)
        self.playbackError = nil

        repository.recordRecent(track.id)
        preparePlayer(for: track, seekTo: 0.0, autoPlay: true)
        loadAuxiliaryTrackData(for: track)
        persistSession()
    }

    public func togglePlayback() {
        triggerHaptic(.light)
        if isPlaying {
            pause()
            return
        }

        if audioPlayer == nil, let active = activeTrack {
            preparePlayer(for: active, seekTo: positionSeconds, autoPlay: true)
            return
        }

        if audioPlayer == nil, let first = repository.sortedSongs.first {
            playTrack(first, queue: repository.sortedSongs)
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.rate = Float(playbackRate)
            audioPlayer?.play()
            isPlaying = true
            sessionStartedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
            startProgressTimer()
            updateNowPlayingInfo()
        } catch {
            playbackError = error.localizedDescription
            repository.logError(category: "Playback", message: error.localizedDescription, trackId: activeTrack?.id)
        }
    }

    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
        audioLevels = .zero
        stopProgressTimer()
        finishActiveListeningSession()
        persistSession()
        updateNowPlayingInfo()
    }

    public func next() {
        triggerHaptic(.light)
        guard !queueTracks.isEmpty else { return }
        flushCurrentPlayHistoryIfQualified()

        let nextIdx: Int
        if queueIndex + 1 < queueTracks.count {
            nextIdx = queueIndex + 1
        } else {
            nextIdx = 0
        }
        jumpToQueueIndex(nextIdx, autoPlay: true)
    }

    public func previous() {
        triggerHaptic(.light)
        guard !queueTracks.isEmpty else { return }
        let currentPos = audioPlayer?.currentTime ?? positionSeconds
        if PlaybackQueueOps.shouldRestartOnPrevious(positionSeconds: currentPos) {
            seek(to: 0.0)
            return
        }
        flushCurrentPlayHistoryIfQualified()
        let prevIdx = queueIndex > 0 ? (queueIndex - 1) : (queueTracks.count - 1)
        jumpToQueueIndex(prevIdx, autoPlay: true)
    }

    public func seek(to seconds: Double) {
        let clamped = max(0.0, min(seconds, max(durationSeconds, 0.0)))
        audioPlayer?.currentTime = clamped
        positionSeconds = clamped
        listeningTracker.reposition(toMs: Int64(clamped * 1000.0))
        persistSession()
        updateNowPlayingInfo()
    }

    public func playNext(_ track: Track) {
        triggerHaptic(.soft)
        if queueTracks.isEmpty {
            playTrack(track, queue: [track])
            return
        }
        let ids = queueTracks.map(\.id)
        let mutation = PlaybackQueueOps.playNextOrder(
            queue: ids,
            activeIndex: queueIndex,
            trackId: track.id
        )
        guard mutation.insertIndex >= 0 else { return }
        var updated = queueTracks
        if mutation.removeIndex >= 0, updated.indices.contains(mutation.removeIndex) {
            updated.remove(at: mutation.removeIndex)
        }
        let target = min(max(0, mutation.insertIndex), updated.count)
        updated.insert(track, at: target)
        queueTracks = updated
        if let active = activeTrack, let newIdx = updated.firstIndex(where: { $0.id == active.id }) {
            queueIndex = newIdx
        }
        repository.bannerMessage = "Playing \"\(track.title)\" next."
        persistSession()
    }

    public func addToQueue(_ track: Track) {
        triggerHaptic(.soft)
        if queueTracks.isEmpty {
            playTrack(track, queue: [track])
            return
        }
        guard !queueTracks.contains(where: { $0.id == track.id }) else {
            repository.bannerMessage = "\"\(track.title)\" is already in the queue."
            return
        }
        queueTracks.append(track)
        repository.bannerMessage = "Added \"\(track.title)\" to queue."
        persistSession()
    }

    public func playQueueItem(at index: Int) {
        guard queueTracks.indices.contains(index) else { return }
        triggerHaptic(.light)
        flushCurrentPlayHistoryIfQualified()
        jumpToQueueIndex(index, autoPlay: true)
    }

    public func moveQueueItem(from: Int, to: Int) {
        guard queueTracks.indices.contains(from),
              queueTracks.indices.contains(to),
              from != to
        else { return }
        var updated = queueTracks
        let item = updated.remove(at: from)
        updated.insert(item, at: to)
        queueTracks = updated
        if let active = activeTrack, let newIdx = updated.firstIndex(where: { $0.id == active.id }) {
            queueIndex = newIdx
        }
        persistSession()
    }

    public func removeQueueItem(at index: Int) {
        guard queueTracks.indices.contains(index) else { return }
        let removingActive = (index == queueIndex)
        queueTracks.remove(at: index)
        if queueTracks.isEmpty {
            clearQueue()
            return
        }
        if removingActive {
            let nextIdx = min(index, queueTracks.count - 1)
            jumpToQueueIndex(nextIdx, autoPlay: isPlaying)
        } else if let active = activeTrack, let newIdx = queueTracks.firstIndex(where: { $0.id == active.id }) {
            queueIndex = newIdx
            persistSession()
        }
    }

    public func clearQueue() {
        flushCurrentPlayHistoryIfQualified()
        finishActiveListeningSession()
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        activeTrack = nil
        isPlaying = false
        queueTracks = []
        queueIndex = -1
        positionSeconds = 0.0
        durationSeconds = 0.0
        activeLyrics = nil
        _ = repository.store.update { $0.playbackSession = nil }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func cycleRepeat() {
        triggerHaptic(.selection)
        repeatMode = repeatMode.next()
        persistSession()
    }

    public func toggleShuffle() {
        triggerHaptic(.selection)
        shuffle.toggle()
        guard let active = activeTrack, queueTracks.count > 1 else {
            persistSession()
            return
        }
        if shuffle {
            if originalQueueTracks.isEmpty {
                originalQueueTracks = queueTracks
            }
            let others = queueTracks.filter { $0.id != active.id }.shuffled()
            queueTracks = [active] + others
            queueIndex = 0
        } else {
            let validById = Dictionary(uniqueKeysWithValues: queueTracks.map { ($0.id, $0) })
            var restored = originalQueueTracks.compactMap { validById[$0.id] }
            for extra in queueTracks where !restored.contains(where: { $0.id == extra.id }) {
                restored.append(extra)
            }
            if !restored.isEmpty {
                queueTracks = restored
                queueIndex = restored.firstIndex(where: { $0.id == active.id }) ?? 0
            }
        }
        persistSession()
    }

    public func setSpeed(_ speed: Double) {
        triggerHaptic(.selection)
        let clamped = PlaybackQueueOps.clampPlaybackSpeed(speed)
        playbackRate = clamped
        audioPlayer?.enableRate = true
        audioPlayer?.rate = Float(clamped)
        persistSession()
        updateNowPlayingInfo()
    }

    public func setVolume(_ newVolume: Double) {
        let clamped = min(1.0, max(0.0, newVolume))
        volume = clamped
        audioPlayer?.volume = Float(clamped)
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.handleTrackFinished()
        }
    }

    private func handleTrackFinished() {
        flushCurrentPlayHistoryIfQualified()

        switch repeatMode {
        case .one:
            if let active = activeTrack {
                listeningTracker.start(atMs: 0)
                preparePlayer(for: active, seekTo: 0.0, autoPlay: true)
            }
        case .all:
            next()
        case .off:
            if queueIndex + 1 < queueTracks.count {
                jumpToQueueIndex(queueIndex + 1, autoPlay: true)
            } else {
                isPlaying = false
                positionSeconds = 0.0
                audioPlayer?.currentTime = 0.0
                stopProgressTimer()
                finishActiveListeningSession()
                persistSession()
                updateNowPlayingInfo()
            }
        }
    }

    private func jumpToQueueIndex(_ index: Int, autoPlay: Bool) {
        guard queueTracks.indices.contains(index) else { return }
        let track = queueTracks[index]
        queueIndex = index
        activeTrack = track
        positionSeconds = 0.0
        durationSeconds = track.duration
        listeningTracker.start(atMs: 0)
        if autoPlay {
            repository.recordRecent(track.id)
        }
        preparePlayer(for: track, seekTo: 0.0, autoPlay: autoPlay)
        loadAuxiliaryTrackData(for: track)
        persistSession()
    }

    private func preparePlayer(for track: Track, seekTo seconds: Double, autoPlay: Bool) {
        finishActiveListeningSession()
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer = nil

        let url = repository.fileURL(for: track)
        guard FileManager.default.fileExists(atPath: url.path) else {
            let msg = "Audio file not found: \(track.relativePath)"
            playbackError = msg
            isPlaying = false
            repository.logError(category: "MissingFile", message: msg, trackId: track.id)
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            if autoPlay {
                try AVAudioSession.sharedInstance().setActive(true)
            }
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.enableRate = true
            player.isMeteringEnabled = true
            player.rate = Float(playbackRate)
            player.volume = Float(volume)
            player.prepareToPlay()
            if player.duration > 0 {
                durationSeconds = player.duration
            }
            if seconds > 0, seconds < player.duration {
                player.currentTime = seconds
                positionSeconds = seconds
            } else {
                positionSeconds = 0.0
            }
            self.audioPlayer = player
            listeningTracker.reposition(toMs: Int64(positionSeconds * 1000.0))

            if autoPlay {
                player.play()
                isPlaying = true
                sessionStartedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
                startProgressTimer()
            } else {
                isPlaying = false
                audioLevels = .zero
            }
            updateNowPlayingInfo()
        } catch {
            let msg = "Unable to play \"\(track.title)\": \(error.localizedDescription)"
            playbackError = msg
            isPlaying = false
            audioLevels = .zero
            repository.logError(category: "AudioPlayer", message: msg, trackId: track.id)
        }
    }

    private func loadAuxiliaryTrackData(for track: Track) {
        let docsURL = repository.store.documentsURL
        let artPath = track.artworkPath
        Task {
            let palette = ArtworkPaletteExtractor.extract(from: artPath)
            let lyrics = await AudioScanner.loadLyrics(for: track, documentsURL: docsURL)
            await MainActor.run {
                if self.activeTrack?.id == track.id {
                    self.activePalette = palette
                    self.activeLyrics = lyrics
                    self.cachedNowPlayingArtworkKey = nil
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        ticksSinceSave = 0
        let interval: TimeInterval = isAppInForeground ? 0.08 : 0.50
        progressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sampleProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func sampleProgress() {
        guard let player = audioPlayer else { return }
        let pos = max(0.0, player.currentTime)
        positionSeconds = pos
        if player.duration > 0 {
            durationSeconds = player.duration
        }
        let posMs = Int64(pos * 1000.0)
        listeningTracker.tick(positionMs: posMs, isPlaying: isPlaying)

        // Real-time lightweight audio-reactive level sampling (foreground only)
        let prefs = repository.preferences
        if isPlaying && isAppInForeground && prefs.auraBackdropEnabled && prefs.audioReactiveAuraEnabled && prefs.motionMode != .reduced {
            player.updateMeters()
            let channels = max(1, player.numberOfChannels)
            let avgL = player.averagePower(forChannel: 0)
            let avgR = channels > 1 ? player.averagePower(forChannel: 1) : avgL
            let peakL = player.peakPower(forChannel: 0)
            let peakR = channels > 1 ? player.peakPower(forChannel: 1) : peakL
            audioLevels = AudioReactiveAnalyzer.computeLevels(
                averagePowerLeftDb: avgL,
                averagePowerRightDb: avgR,
                peakPowerLeftDb: peakL,
                peakPowerRightDb: peakR,
                previous: audioLevels
            )
        } else if audioLevels != .zero {
            audioLevels = AudioReactiveAnalyzer.decayToZero(from: audioLevels)
        }

        ticksSinceSave += 1
        let saveThreshold = isAppInForeground ? 60 : 10
        if ticksSinceSave >= saveThreshold {
            ticksSinceSave = 0
            persistSession()
            updateNowPlayingInfo()
        }
    }

    private func flushCurrentPlayHistoryIfQualified() {
        guard let current = activeTrack else { return }
        let listenedMs = listeningTracker.listenedMs
        if PlaybackQueueOps.shouldRecordPlay(
            durationSeconds: max(durationSeconds, current.duration),
            listenedMs: listenedMs
        ) {
            repository.recordPlay(trackId: current.id, durationListenedMs: listenedMs)
        }
        listeningTracker.reset()
    }

    private func finishActiveListeningSession() {
        guard let started = sessionStartedAtMs, let current = activeTrack else { return }
        sessionStartedAtMs = nil
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        repository.recordListeningSession(soundId: current.id, startedAt: started, endedAt: now)
    }

    private func persistSession() {
        guard let active = activeTrack, !queueTracks.isEmpty else { return }
        let session = PlaybackSession(
            activeTrackId: active.id,
            queueIds: queueTracks.map(\.id),
            queueIndex: max(0, queueIndex),
            positionSeconds: positionSeconds,
            shuffle: shuffle,
            repeatMode: repeatMode,
            playbackRate: playbackRate
        )
        _ = repository.store.update { $0.playbackSession = session }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
        } catch {
            repository.logError(category: "AudioSession", message: error.localizedDescription)
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false { self?.togglePlayback() }
            }
            return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayback()
            }
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.next()
            }
            return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previous()
            }
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: posEvent.positionTime)
            }
            return .success
        }
        center.changeShuffleModeCommand.isEnabled = true
        center.changeShuffleModeCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.toggleShuffle()
            }
            return .success
        }
        center.changeRepeatModeCommand.isEnabled = true
        center.changeRepeatModeCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.cycleRepeat()
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = activeTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            cachedNowPlayingArtworkKey = nil
            cachedNowPlayingArtwork = nil
            return
        }

        let center = MPRemoteCommandCenter.shared()
        center.changeShuffleModeCommand.currentShuffleType = shuffle ? .items : .off
        switch repeatMode {
        case .off: center.changeRepeatModeCommand.currentRepeatType = .off
        case .all: center.changeRepeatModeCommand.currentRepeatType = .all
        case .one: center.changeRepeatModeCommand.currentRepeatType = .one
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: max(durationSeconds, track.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: positionSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: max(0, queueIndex),
            MPNowPlayingInfoPropertyPlaybackQueueCount: queueTracks.count,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let albumArtist = track.albumArtist, !albumArtist.isEmpty {
            info[MPMediaItemPropertyAlbumArtist] = albumArtist
        }
        if let composer = track.composer, !composer.isEmpty {
            info[MPMediaItemPropertyComposer] = composer
        }
        if let genre = track.genre, !genre.isEmpty {
            info[MPMediaItemPropertyGenre] = genre
        }
        if let trackNum = track.trackNumber {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNum
        }
        if let discNum = track.discNumber {
            info[MPMediaItemPropertyDiscNumber] = discNum
        }

        let artKey = "\(track.id)|\(track.artworkPath ?? "")|\(track.title)|\(track.artist)"
        if cachedNowPlayingArtworkKey != artKey || cachedNowPlayingArtwork == nil {
            let highResSquare = Self.buildLockScreenFullResolutionArtwork(for: track, palette: activePalette)
            let fullBounds = CGSize(width: 1024, height: 1024)
            cachedNowPlayingArtwork = MPMediaItemArtwork(boundsSize: fullBounds) { requestedSize in
                guard requestedSize.width > 0,
                      requestedSize.height > 0,
                      abs(requestedSize.width - fullBounds.width) > 4.0
                else {
                    return highResSquare
                }
                let side = max(256.0, min(1024.0, max(requestedSize.width, requestedSize.height)))
                let targetSize = CGSize(width: side, height: side)
                let format = UIGraphicsImageRendererFormat.default()
                format.scale = 1.0
                format.opaque = true
                return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                    highResSquare.draw(in: CGRect(origin: .zero, size: targetSize))
                }
            }
            cachedNowPlayingArtworkKey = artKey
        }
        if let artwork = cachedNowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Generates an opaque 1024x1024 square high-resolution album cover so iOS Lock Screen
    /// supports tapping compact artwork to expand into full-screen Lock Screen album artwork.
    private static func buildLockScreenFullResolutionArtwork(for track: Track, palette: ArtworkPalette) -> UIImage {
        let canvasSize = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true

        if let artPath = track.artworkPath,
           let sourceImage = SnoozyArtworkCache.loadThumbnail(at: artPath, pointSize: 1024) ?? UIImage(contentsOfFile: artPath) {
            return UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
                UIColor.black.setFill()
                ctx.fill(CGRect(origin: .zero, size: canvasSize))

                let srcSize = sourceImage.size
                guard srcSize.width > 0, srcSize.height > 0 else { return }
                let scale = max(canvasSize.width / srcSize.width, canvasSize.height / srcSize.height)
                let drawWidth = srcSize.width * scale
                let drawHeight = srcSize.height * scale
                let drawRect = CGRect(
                    x: (canvasSize.width - drawWidth) * 0.5,
                    y: (canvasSize.height - drawHeight) * 0.5,
                    width: drawWidth,
                    height: drawHeight
                )
                sourceImage.draw(in: drawRect)
            }
        }

        // High-resolution fallback cover when a track has no external/embedded artwork
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            let cg = ctx.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let topColor = UIColor(palette.primary)
            let bottomColor = UIColor(red: 0.03, green: 0.06, blue: 0.09, alpha: 1.0)
            let accentColor = UIColor(palette.secondary)

            if let grad = CGGradient(
                colorsSpace: colorSpace,
                colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cg.drawLinearGradient(
                    grad,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: canvasSize.width, y: canvasSize.height),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }

            if let orb = CGGradient(
                colorsSpace: colorSpace,
                colors: [accentColor.withAlphaComponent(0.55).cgColor, accentColor.withAlphaComponent(0.0).cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cg.drawRadialGradient(
                    orb,
                    startCenter: CGPoint(x: 720, y: 280),
                    startRadius: 20,
                    endCenter: CGPoint(x: 720, y: 280),
                    endRadius: 620,
                    options: []
                )
            }

            if let brand = SnoozyBrandAssetLoader.loadBrandLogoImage() {
                let logoRect = CGRect(x: 312, y: 220, width: 400, height: 400)
                let clip = UIBezierPath(roundedRect: logoRect, cornerRadius: 92)
                cg.saveGState()
                clip.addClip()
                brand.draw(in: logoRect)
                cg.restoreGState()
            }

            let titleFont = UIFont(name: "BricolageGrotesque-SemiBold", size: 54) ?? UIFont.systemFont(ofSize: 54, weight: .bold)
            let subFont = UIFont(name: "AtkinsonHyperlegible-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .semibold)
            let style = NSMutableParagraphStyle()
            style.alignment = .center

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.78),
                .paragraphStyle: style
            ]

            (track.title as NSString).draw(in: CGRect(x: 72, y: 700, width: 880, height: 76), withAttributes: titleAttrs)
            (track.artist as NSString).draw(in: CGRect(x: 72, y: 784, width: 880, height: 54), withAttributes: subAttrs)
        }
    }

    private func observeAudioNotifications() {
        let interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            Task { @MainActor in
                switch type {
                case .began:
                    self?.interruptionState.began(wasPlaying: self?.isPlaying ?? false)
                    self?.pause()
                case .ended:
                    if let optVal = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optVal)
                        let shouldResume = self?.interruptionState.ended(
                            canResume: options.contains(.shouldResume)
                        ) ?? false
                        if shouldResume {
                            self?.togglePlayback()
                        }
                    } else {
                        _ = self?.interruptionState.ended(canResume: false)
                    }
                @unknown default:
                    break
                }
            }
        }
        notificationTokens.append(interruptionToken)

        let routeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let reasonVal = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal)
            else { return }
            if reason == .oldDeviceUnavailable {
                Task { @MainActor in
                    self?.pause()
                }
            }
        }
        notificationTokens.append(routeToken)

        let bgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isAppInForeground = false
                self.audioLevels = .zero
                if self.isPlaying {
                    self.startProgressTimer()
                }
                self.persistSession()
                self.updateNowPlayingInfo()
            }
        }
        notificationTokens.append(bgToken)

        let fgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isAppInForeground = true
                if self.isPlaying {
                    self.startProgressTimer()
                }
                self.updateNowPlayingInfo()
            }
        }
        notificationTokens.append(fgToken)
    }

    private func observeLibraryChanges() {
        repository.$tracks
            .receive(on: RunLoop.main)
            .sink { [weak self] updatedTracks in
                guard let self else { return }
                if !self.coldStartRestored && !updatedTracks.isEmpty {
                    self.restoreColdStartIfNeeded()
                    return
                }
                let byId = Dictionary(uniqueKeysWithValues: updatedTracks.map { ($0.id, $0) })
                self.originalQueueTracks = self.originalQueueTracks.compactMap { byId[$0.id] }
                self.queueTracks = self.queueTracks.compactMap { byId[$0.id] }

                guard let current = self.activeTrack else { return }
                if let refreshed = byId[current.id] {
                    let artworkChanged = (current.artworkPath != refreshed.artworkPath)
                    self.activeTrack = refreshed
                    if let newIdx = self.queueTracks.firstIndex(where: { $0.id == refreshed.id }) {
                        self.queueIndex = newIdx
                    }
                    if artworkChanged {
                        self.loadAuxiliaryTrackData(for: refreshed)
                    }
                    self.updateNowPlayingInfo()
                } else {
                    // The active track was deleted or removed from the library
                    if self.queueTracks.isEmpty {
                        self.clearQueue()
                    } else {
                        let nextIdx = min(max(0, self.queueIndex), self.queueTracks.count - 1)
                        self.jumpToQueueIndex(nextIdx, autoPlay: self.isPlaying)
                    }
                }
            }
            .store(in: &cancellables)
    }

    private enum HapticStyle {
        case light
        case soft
        case selection
    }

    private func triggerHaptic(_ style: HapticStyle) {
        guard repository.preferences.hapticsEnabled else { return }
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
