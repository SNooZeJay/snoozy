import Foundation

public struct AutomixPlan: Equatable, Sendable {
    public let nextIndex: Int
    public let overlapSeconds: Double

    public init(nextIndex: Int, overlapSeconds: Double) {
        self.nextIndex = nextIndex
        self.overlapSeconds = overlapSeconds
    }
}

/// Pure transition rules for overlapping playback. The audio engine owns the
/// nodes and ramps; this type only decides when and how long a handoff lasts.
public enum AutomixLogic {
    public static let maxCrossfadeSeconds: Double = 12.0
    public static let gaplessOverlapSeconds: Double = 0.08
    public static let maxOverlapFraction: Double = 0.4
    public static let minimumOverlapSeconds: Double = 0.02

    public static func clampedCrossfade(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return 0.0 }
        return min(maxCrossfadeSeconds, max(0.0, seconds))
    }

    /// Gapless wins over the crossfade slider. The overlap is capped against the
    /// shorter known track so a very short cue cannot be swallowed whole.
    public static func effectiveOverlap(
        requestedCrossfade: Double,
        gaplessEnabled: Bool,
        currentDuration: Double,
        nextDuration: Double
    ) -> Double {
        let requested = gaplessEnabled
            ? gaplessOverlapSeconds
            : clampedCrossfade(requestedCrossfade)
        guard requested > 0 else { return 0.0 }

        let knownDurations = [currentDuration, nextDuration].filter { $0.isFinite && $0 > 0 }
        guard let shortest = knownDurations.min() else { return requested }
        let capped = min(requested, shortest * maxOverlapFraction)
        return capped >= minimumOverlapSeconds ? capped : 0.0
    }

    public static func nextIndex(
        currentIndex: Int,
        queueCount: Int,
        repeatMode: RepeatState
    ) -> Int? {
        guard queueCount > 1,
              currentIndex >= 0,
              currentIndex < queueCount,
              repeatMode != .one
        else { return nil }

        if currentIndex + 1 < queueCount {
            return currentIndex + 1
        }
        return repeatMode == .all ? 0 : nil
    }

    public static func plan(
        repeatMode: RepeatState,
        queueCount: Int,
        currentIndex: Int,
        currentDuration: Double,
        nextDuration: Double,
        crossfadeSeconds: Double,
        gaplessEnabled: Bool
    ) -> AutomixPlan? {
        guard let next = nextIndex(
            currentIndex: currentIndex,
            queueCount: queueCount,
            repeatMode: repeatMode
        ) else { return nil }

        let overlap = effectiveOverlap(
            requestedCrossfade: crossfadeSeconds,
            gaplessEnabled: gaplessEnabled,
            currentDuration: currentDuration,
            nextDuration: nextDuration
        )
        guard overlap > 0 else { return nil }
        return AutomixPlan(nextIndex: next, overlapSeconds: overlap)
    }

    /// Equal-power fade so summed loudness stays stable through the overlap.
    public static func equalPowerGains(progress: Double) -> (outgoing: Double, incoming: Double) {
        let clamped = progress.isFinite ? min(1.0, max(0.0, progress)) : 0.0
        let angle = clamped * .pi / 2.0
        return (cos(angle), sin(angle))
    }
}
