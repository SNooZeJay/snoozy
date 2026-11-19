import Foundation

public enum EqualizerBands {
    public static let frequencies: [Double] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    public static let labels: [String] = ["31", "62", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    public static let count = frequencies.count
    public static let minGainDb: Double = -12.0
    public static let maxGainDb: Double = 12.0
    public static let minPreampDb: Double = -12.0
    public static let maxPreampDb: Double = 12.0
    public static let minEffectiveGainDb: Double = -24.0
}

public struct EqualizerPreset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var gainsDb: [Double]
    public let isBuiltIn: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        gainsDb: [Double],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.gainsDb = EqualizerLogic.sanitizedGains(gainsDb)
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case gainsDb
        case isBuiltIn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Custom"
        self.gainsDb = EqualizerLogic.sanitizedGains(
            try container.decodeIfPresent([Double].self, forKey: .gainsDb) ?? []
        )
        self.isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    public static let flat = EqualizerPreset(
        id: "flat",
        name: "Flat",
        gainsDb: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        isBuiltIn: true
    )

    public static let builtInPresets: [EqualizerPreset] = [
        flat,
        EqualizerPreset(id: "acoustic", name: "Acoustic", gainsDb: [4, 3, 2, 1.5, 1, 0, 1, 2, 2.5, 2], isBuiltIn: true),
        EqualizerPreset(id: "bass_booster", name: "Bass Booster", gainsDb: [6, 5.5, 4.5, 3, 1.5, 0, 0, 0, 0, 0], isBuiltIn: true),
        EqualizerPreset(id: "classical", name: "Classical", gainsDb: [3.5, 3, 2, 1.5, 0, 0, 0, 1.5, 2.5, 3], isBuiltIn: true),
        EqualizerPreset(id: "dance", name: "Dance", gainsDb: [5, 4, 1, 0, 0, -1, -2, -1, 2, 4], isBuiltIn: true),
        EqualizerPreset(id: "deep", name: "Deep", gainsDb: [6, 5, 3, 1, 0, -1, -1, 0, 1, 2], isBuiltIn: true),
        EqualizerPreset(id: "electronic", name: "Electronic", gainsDb: [5, 4.5, 2, 0, -1, 0, 1, 2, 3.5, 4.5], isBuiltIn: true),
        EqualizerPreset(id: "hip_hop", name: "Hip-Hop", gainsDb: [6, 5, 2, 1, -1, -1, 1, 2, 3, 3], isBuiltIn: true),
        EqualizerPreset(id: "jazz", name: "Jazz", gainsDb: [3, 2, 1, 2, -1, -1, 0, 1, 2, 3], isBuiltIn: true),
        EqualizerPreset(id: "latin", name: "Latin", gainsDb: [4, 3, 1, 0, -1, -1, 0, 2, 3, 4], isBuiltIn: true),
        EqualizerPreset(id: "loudness", name: "Loudness", gainsDb: [5, 4, 3, 1, 0, -1, 0, 2, 4, 5], isBuiltIn: true),
        EqualizerPreset(id: "piano", name: "Piano", gainsDb: [3, 2.5, 1.5, 1, 0, 0, 1, 2, 3, 3.5], isBuiltIn: true),
        EqualizerPreset(id: "pop", name: "Pop", gainsDb: [4, 3, 1, 0, -1, 0, 1, 2, 3, 4], isBuiltIn: true),
        EqualizerPreset(id: "rock", name: "Rock", gainsDb: [5, 4, 3, 1.5, 0, -1, 0, 2, 3.5, 4.5], isBuiltIn: true)
    ]
}

/// Pure equalizer rules: gain sanitising, clip-safe preamp compensation, preset
/// matching and custom preset management.
public enum EqualizerLogic {
    public static func sanitizedGains(_ gains: [Double]) -> [Double] {
        var result = [Double](repeating: 0.0, count: EqualizerBands.count)
        for index in 0..<min(EqualizerBands.count, gains.count) {
            let value = gains[index]
            guard value.isFinite else { continue }
            result[index] = min(EqualizerBands.maxGainDb, max(EqualizerBands.minGainDb, value))
        }
        return result
    }

    public static func sanitizedPreamp(_ db: Double) -> Double {
        guard db.isFinite else { return 0.0 }
        return min(EqualizerBands.maxPreampDb, max(EqualizerBands.minPreampDb, db))
    }

    /// Static clip guard: a band boost is offset by the preamp so the summed
    /// response never exceeds unity. With no boosts the preamp passes through
    /// and the limiter downstream catches transient peaks.
    public static func effectivePreampDb(userPreampDb: Double, gainsDb: [Double]) -> Double {
        let preamp = sanitizedPreamp(userPreampDb)
        let maxBoost = max(0.0, sanitizedGains(gainsDb).max() ?? 0.0)
        guard maxBoost > 0 else { return preamp }
        return max(EqualizerBands.minEffectiveGainDb, min(preamp, -maxBoost))
    }

    public static func preset(
        matching gainsDb: [Double],
        in presets: [EqualizerPreset],
        tolerance: Double = 0.01
    ) -> EqualizerPreset? {
        let target = sanitizedGains(gainsDb)
        return presets.first { preset in
            let candidate = sanitizedGains(preset.gainsDb)
            return zip(candidate, target).allSatisfy { abs($0.0 - $0.1) <= tolerance }
        }
    }

    public static func normalizedPresetName(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    }

    public static func upsertingPreset(
        _ presets: [EqualizerPreset],
        name: String,
        gainsDb: [Double]
    ) -> [EqualizerPreset] {
        let trimmed = normalizedPresetName(name)
        guard !trimmed.isEmpty else { return presets }
        let gains = sanitizedGains(gainsDb)

        if let index = presets.firstIndex(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && !$0.isBuiltIn
        }) {
            var updated = presets
            updated[index].name = trimmed
            updated[index].gainsDb = gains
            return updated
        }
        return presets + [EqualizerPreset(name: trimmed, gainsDb: gains)]
    }

    public static func renaming(
        _ presets: [EqualizerPreset],
        id: String,
        to name: String
    ) -> [EqualizerPreset] {
        let trimmed = normalizedPresetName(name)
        guard !trimmed.isEmpty else { return presets }
        var updated = presets
        if let index = updated.firstIndex(where: { $0.id == id && !$0.isBuiltIn }) {
            updated[index].name = trimmed
        }
        return updated
    }

    public static func deleting(_ presets: [EqualizerPreset], id: String) -> [EqualizerPreset] {
        presets.filter { $0.isBuiltIn || $0.id != id }
    }
}
