import XCTest
@testable import Snoozy

final class EqualizerLogicTests: XCTestCase {
    func testBuiltInPresetCatalogIsCompleteAndValid() {
        XCTAssertEqual(EqualizerPreset.builtInPresets.count, 14)
        XCTAssertEqual(Set(EqualizerPreset.builtInPresets.map(\.id)).count, 14)
        XCTAssertEqual(Set(EqualizerPreset.builtInPresets.map(\.name)).count, 14)

        for preset in EqualizerPreset.builtInPresets {
            XCTAssertTrue(preset.isBuiltIn)
            XCTAssertEqual(preset.gainsDb.count, EqualizerBands.count)
            XCTAssertTrue(preset.gainsDb.allSatisfy { $0 >= EqualizerBands.minGainDb && $0 <= EqualizerBands.maxGainDb })
        }
    }

    func testSanitizedGainsPadsTruncatesAndClamps() {
        let result = EqualizerLogic.sanitizedGains([20, -20, 3, .nan, 1])
        XCTAssertEqual(result.count, EqualizerBands.count)
        XCTAssertEqual(result[0], 12)
        XCTAssertEqual(result[1], -12)
        XCTAssertEqual(result[2], 3)
        XCTAssertEqual(result[3], 0)
        XCTAssertEqual(result[4], 1)
        XCTAssertEqual(result[5], 0)
    }

    func testPreampOffsetsLoudestBandBoost() {
        let gains: [Double] = [6, 5, 4, 3, 2, 1, 0, 0, 0, 0]
        XCTAssertEqual(
            EqualizerLogic.effectivePreampDb(userPreampDb: 0, gainsDb: gains),
            -6,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EqualizerLogic.effectivePreampDb(userPreampDb: 3, gainsDb: gains),
            -3,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EqualizerLogic.effectivePreampDb(userPreampDb: -8, gainsDb: gains),
            -14,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EqualizerLogic.effectivePreampDb(userPreampDb: 9, gainsDb: gains),
            3,
            accuracy: 0.0001
        )
    }

    func testPreampPassesThroughWhenNoBandBoosts() {
        XCTAssertEqual(
            EqualizerLogic.effectivePreampDb(userPreampDb: 4, gainsDb: Array(repeating: -2, count: 10)),
            4,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            EqualizerLogic.effectivePreampDb(userPreampDb: .nan, gainsDb: Array(repeating: 0, count: 10)),
            0,
            accuracy: 0.0001
        )
    }

    func testPresetMatchingUsesTolerance() {
        let match = EqualizerLogic.preset(
            matching: [6, 5.5, 4.5, 3, 1.5, 0, 0, 0, 0, 0],
            in: EqualizerPreset.builtInPresets
        )
        XCTAssertEqual(match?.id, "bass_booster")

        var nudged = [6, 5.5, 4.5, 3, 1.5, 0, 0, 0, 0, 0]
        nudged[0] += 0.005
        XCTAssertEqual(
            EqualizerLogic.preset(matching: nudged, in: EqualizerPreset.builtInPresets)?.id,
            "bass_booster"
        )

        nudged[0] += 1
        XCTAssertNil(EqualizerLogic.preset(matching: nudged, in: EqualizerPreset.builtInPresets))
    }

    func testCustomPresetUpsertRenamesAndDeletes() {
        let saved = EqualizerLogic.upsertingPreset([], name: "  Night Drive  ", gainsDb: [1, 2, 3])
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].name, "Night Drive")
        XCTAssertEqual(saved[0].gainsDb.count, EqualizerBands.count)
        XCTAssertFalse(saved[0].isBuiltIn)

        let replaced = EqualizerLogic.upsertingPreset(saved, name: "night drive", gainsDb: [4, 5, 6])
        XCTAssertEqual(replaced.count, 1)
        XCTAssertEqual(replaced[0].gainsDb[0], 4)

        let renamed = EqualizerLogic.renaming(replaced, id: replaced[0].id, to: "Late Night")
        XCTAssertEqual(renamed[0].name, "Late Night")

        let ignoredBuiltIn = EqualizerLogic.renaming(
            EqualizerPreset.builtInPresets,
            id: "flat",
            to: "Not Flat"
        )
        XCTAssertEqual(ignoredBuiltIn.first(where: { $0.id == "flat" })?.name, "Flat")

        let deleted = EqualizerLogic.deleting(renamed, id: renamed[0].id)
        XCTAssertTrue(deleted.isEmpty)
    }

    func testEmptyPresetNamesAreRejected() {
        XCTAssertEqual(
            EqualizerLogic.upsertingPreset([], name: "   ", gainsDb: []).count,
            0
        )
        XCTAssertEqual(
            EqualizerLogic.normalizedPresetName("  Vocal  "),
            "Vocal"
        )
    }
}
