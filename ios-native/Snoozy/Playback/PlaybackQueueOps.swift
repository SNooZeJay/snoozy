import Foundation

public struct PlayNextMutation: Equatable, Sendable {
    public let queue: [String]
    public let insertIndex: Int
    public let removeIndex: Int
}

public struct ResolvedPlaybackSession: Equatable, Sendable {
    public let activeTrack: Track
    public let queueTracks: [Track]
    public let queueIds: [String]
    public let activeIndex: Int
    public let positionSeconds: Double
    public let shuffle: Bool
    public let repeatMode: RepeatState
    public let playbackRate: Double
}

public enum PlaybackQueueOps {
    public static let minSpeed: Double = 0.5
    public static let maxSpeed: Double = 2.0
    public static let restartThresholdSeconds: Double = 3.0
    public static let speedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    public static func appendUnique(_ queue: [String], _ trackId: String) -> [String] {
        guard !trackId.isEmpty, !queue.contains(trackId) else { return queue }
        return queue + [trackId]
    }

    public static func playNextOrder(
        queue: [String],
        activeIndex: Int,
        trackId: String
    ) -> PlayNextMutation {
        guard !trackId.isEmpty else {
            return PlayNextMutation(queue: queue, insertIndex: -1, removeIndex: -1)
        }
        if queue.isEmpty {
            return PlayNextMutation(queue: [trackId], insertIndex: 0, removeIndex: -1)
        }
        let clampedActive = min(max(0, activeIndex), queue.count - 1)
        if queue[clampedActive] == trackId {
            return PlayNextMutation(queue: queue, insertIndex: -1, removeIndex: -1)
        }
        let existingIndex = queue.firstIndex(of: trackId) ?? -1
        var mutable = queue
        if existingIndex >= 0 {
            mutable.remove(at: existingIndex)
        }
        let adjustedActive = (existingIndex >= 0 && existingIndex < clampedActive)
            ? clampedActive - 1
            : clampedActive
        let targetIndex = min(adjustedActive + 1, mutable.count)
        mutable.insert(trackId, at: targetIndex)
        return PlayNextMutation(
            queue: mutable,
            insertIndex: targetIndex,
            removeIndex: existingIndex
        )
    }

    public static func clampPlaybackSpeed(_ value: Double) -> Double {
        guard value.isFinite else { return 1.0 }
        return min(maxSpeed, max(minSpeed, value))
    }

    public static func shouldRestartOnPrevious(positionSeconds: Double) -> Bool {
        positionSeconds > restartThresholdSeconds
    }

    public static func shouldRecordPlay(durationSeconds: Double, listenedMs: Int64) -> Bool {
        guard listenedMs > 0 else { return false }
        let durationMs = durationSeconds.isFinite && durationSeconds > 0
            ? durationSeconds * 1000.0
            : 0.0
        let thresholdMs = durationMs > 0
            ? min(30_000.0, durationMs * 0.5)
            : 10_000.0
        return Double(listenedMs) >= thresholdMs
    }

    public static func pushRecent(
        current: [String],
        trackId: String,
        cap: Int = 20
    ) -> [String] {
        guard !trackId.isEmpty else { return Array(current.prefix(cap)) }
        let filtered = current.filter { $0 != trackId }
        return Array(([trackId] + filtered).prefix(cap))
    }

    public static func resolvePlaybackSession(
        session: PlaybackSession?,
        tracksById: [String: Track]
    ) -> ResolvedPlaybackSession? {
        guard let session, !tracksById.isEmpty else { return nil }
        var seen = Set<String>()
        var queueTracks: [Track] = []
        for id in session.queueIds {
            if let track = tracksById[id], seen.insert(id).inserted {
                queueTracks.append(track)
            }
        }
        if let active = tracksById[session.activeTrackId], seen.insert(active.id).inserted {
            queueTracks.insert(active, at: 0)
        }
        guard !queueTracks.isEmpty else { return nil }

        let activeIndex: Int
        if let idx = queueTracks.firstIndex(where: { $0.id == session.activeTrackId }) {
            activeIndex = idx
        } else {
            activeIndex = min(max(0, session.queueIndex), queueTracks.count - 1)
        }
        let activeTrack = queueTracks[activeIndex]
        let maxDuration = activeTrack.duration > 0 ? activeTrack.duration : Double.greatestFiniteMagnitude
        let clampedPos = session.positionSeconds.isFinite
            ? min(max(0.0, session.positionSeconds), maxDuration)
            : 0.0

        return ResolvedPlaybackSession(
            activeTrack: activeTrack,
            queueTracks: queueTracks,
            queueIds: queueTracks.map(\.id),
            activeIndex: activeIndex,
            positionSeconds: clampedPos,
            shuffle: session.shuffle,
            repeatMode: session.repeatMode,
            playbackRate: clampPlaybackSpeed(session.playbackRate)
        )
    }
}
