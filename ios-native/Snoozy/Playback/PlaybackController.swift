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
    @Published public private(set) var activeLyrics: ParsedLyrics? = nil
    @Published public private(set) var activePalette: ArtworkPalette = .emeraldDefault
    @Published public var playbackError: String? = nil

    private var audioPlayer: AVAudioPlayer? = nil
    private var progressTimer: Timer? = nil
    private var ticksSinceSave: Int = 0
    private var coldStartRestored: Bool = false
    private var maxListenedMsForActiveTrack: Int64 = 0
    private var sessionStartedAtMs: Int64? = nil
    private var cancellables = Set<AnyCancellable>()

    public init(repository: LibraryRepository) {
        self.repository = repository
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        observeAudioNotifications()
        observeLibraryChanges()
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
        self.maxListenedMsForActiveTrack = 0
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
        if shuffle, let active = activeTrack, queueTracks.count > 1 {
            let others = queueTracks.filter { $0.id != active.id }.shuffled()
            queueTracks = [active] + others
            queueIndex = 0
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

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.handleTrackFinished()
        }
    }

    private func handleTrackFinished() {
        if let active = activeTrack {
            let fullMs = Int64(max(durationSeconds, active.duration) * 1000.0)
            maxListenedMsForActiveTrack = max(maxListenedMsForActiveTrack, fullMs)
        }
        flushCurrentPlayHistoryIfQualified()

        switch repeatMode {
        case .one:
            if let active = activeTrack {
                maxListenedMsForActiveTrack = 0
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
        maxListenedMsForActiveTrack = 0
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
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.enableRate = true
            player.rate = Float(playbackRate)
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

            if autoPlay {
                player.play()
                isPlaying = true
                sessionStartedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
                startProgressTimer()
            } else {
                isPlaying = false
            }
            updateNowPlayingInfo()
        } catch {
            let msg = "Unable to play \"\(track.title)\": \(error.localizedDescription)"
            playbackError = msg
            isPlaying = false
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
                }
            }
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        ticksSinceSave = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
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
        if posMs > maxListenedMsForActiveTrack {
            maxListenedMsForActiveTrack = posMs
        }
        ticksSinceSave += 1
        if ticksSinceSave >= 20 {
            ticksSinceSave = 0
            persistSession()
            updateNowPlayingInfo()
        }
    }

    private func flushCurrentPlayHistoryIfQualified() {
        guard let current = activeTrack else { return }
        if PlaybackQueueOps.shouldRecordPlay(
            durationSeconds: max(durationSeconds, current.duration),
            listenedMs: maxListenedMsForActiveTrack
        ) {
            repository.recordPlay(trackId: current.id, durationListenedMs: maxListenedMsForActiveTrack)
        }
        maxListenedMsForActiveTrack = 0
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
    }

    private func updateNowPlayingInfo() {
        guard let track = activeTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: max(durationSeconds, track.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: positionSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0
        ]
        if let artPath = track.artworkPath, let image = UIImage(contentsOfFile: artPath) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func observeAudioNotifications() {
        NotificationCenter.default.addObserver(
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
                    self?.pause()
                case .ended:
                    if let optVal = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optVal)
                        if options.contains(.shouldResume) {
                            self?.togglePlayback()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(
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
    }

    private func observeLibraryChanges() {
        repository.$tracks
            .receive(on: RunLoop.main)
            .sink { [weak self] updatedTracks in
                guard let self else { return }
                if !self.coldStartRestored && !updatedTracks.isEmpty {
                    self.restoreColdStartIfNeeded()
                } else if let current = self.activeTrack,
                          let refreshed = updatedTracks.first(where: { $0.id == current.id }) {
                    self.activeTrack = refreshed
                    self.updateNowPlayingInfo()
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
