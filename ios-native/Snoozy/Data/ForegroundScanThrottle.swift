import Foundation

/// Limits automatic rescans when the app becomes active again.
public struct ForegroundScanThrottle {
    public let minimumInterval: TimeInterval
    public private(set) var lastScanAt: Date?

    public init(minimumInterval: TimeInterval = 60) {
        self.minimumInterval = minimumInterval
    }

    public func shouldScan(at now: Date) -> Bool {
        guard let lastScanAt else { return true }
        return now.timeIntervalSince(lastScanAt) >= minimumInterval
    }

    public mutating func recordScan(at now: Date) {
        lastScanAt = now
    }
}
