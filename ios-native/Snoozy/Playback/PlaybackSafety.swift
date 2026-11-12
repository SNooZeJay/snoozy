import Foundation

/// Decides whether an audio interruption should resume playback when it ends.
public struct PlaybackInterruptionState: Equatable, Sendable {
    private var wasPlayingBeforeInterruption = false

    public init() {}

    public mutating func began(wasPlaying: Bool) {
        wasPlayingBeforeInterruption = wasPlaying
    }

    public mutating func ended(canResume: Bool) -> Bool {
        defer { wasPlayingBeforeInterruption = false }
        return wasPlayingBeforeInterruption && canResume
    }
}

/// Counts actual playback progress while ignoring forward seeks.
public struct PlaybackListeningTracker: Equatable, Sendable {
    public private(set) var listenedMs: Int64 = 0
    private var lastPositionMs: Int64?

    public init() {}

    public mutating func start(atMs positionMs: Int64) {
        listenedMs = 0
        lastPositionMs = positionMs
    }

    public mutating func reposition(toMs positionMs: Int64) {
        lastPositionMs = positionMs
    }

    public mutating func tick(positionMs: Int64, isPlaying: Bool, maxStepMs: Int64 = 2_000) {
        guard let lastPositionMs else {
            self.lastPositionMs = positionMs
            return
        }
        defer { self.lastPositionMs = positionMs }

        guard isPlaying else { return }
        let delta = positionMs - lastPositionMs
        guard delta > 0, delta <= maxStepMs else { return }
        listenedMs += delta
    }

    public mutating func reset() {
        listenedMs = 0
        lastPositionMs = nil
    }
}
