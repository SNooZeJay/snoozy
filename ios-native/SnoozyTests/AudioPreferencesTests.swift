import XCTest
@testable import Snoozy

final class AudioPreferencesTests: XCTestCase {
    func testLegacyPreferencesDecodeWithAudioDefaults() throws {
        let legacy = """
        {
          "themeMode": "dark",
          "paletteSeed": "emerald",
          "glassMode": "liquidGlass",
          "refractionIntensity": 0.82,
          "auraBackdropEnabled": true,
          "auraBackdropIntensity": 0.75,
          "audioReactiveAuraEnabled": true,
          "motionMode": "full",
          "hapticsEnabled": true,
          "albumLayout": "grid",
          "playlistLayout": "grid",
          "hiddenLibrarySections": [],
          "librarySectionOrder": []
        }
        """
        let prefs = try JSONDecoder().decode(SnoozyPreferences.self, from: Data(legacy.utf8))
        XCTAssertTrue(prefs.automixEnabled)
        XCTAssertEqual(prefs.automixCrossfadeSeconds, 4.0, accuracy: 0.0001)
        XCTAssertFalse(prefs.automixGaplessEnabled)
        XCTAssertFalse(prefs.equalizerEnabled)
        XCTAssertEqual(prefs.equalizerBandGains, Array(repeating: 0.0, count: EqualizerBands.count))
        XCTAssertEqual(prefs.equalizerPreampDb, 0.0, accuracy: 0.0001)
        XCTAssertTrue(prefs.equalizerCustomPresets.isEmpty)
    }

    func testAudioPreferencesRoundTripAndSanitise() throws {
        var prefs = SnoozyPreferences()
        prefs.automixEnabled = false
        prefs.automixCrossfadeSeconds = 40
        prefs.automixGaplessEnabled = false
        prefs.equalizerEnabled = true
        prefs.equalizerBandGains = [20, -20, 2]
        prefs.equalizerPreampDb = 40
        prefs.equalizerCustomPresets = [
            EqualizerPreset(name: "Test", gainsDb: [1, 2, 3])
        ]

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(SnoozyPreferences.self, from: data)

        XCTAssertFalse(decoded.automixEnabled)
        XCTAssertEqual(decoded.automixCrossfadeSeconds, 12, accuracy: 0.0001)
        XCTAssertFalse(decoded.automixGaplessEnabled)
        XCTAssertTrue(decoded.equalizerEnabled)
        XCTAssertEqual(decoded.equalizerBandGains.count, EqualizerBands.count)
        XCTAssertEqual(decoded.equalizerBandGains[0], 12)
        XCTAssertEqual(decoded.equalizerBandGains[1], -12)
        XCTAssertEqual(decoded.equalizerBandGains[2], 2)
        XCTAssertEqual(decoded.equalizerPreampDb, 12, accuracy: 0.0001)
        XCTAssertEqual(decoded.equalizerCustomPresets.count, 1)
        XCTAssertEqual(decoded.equalizerCustomPresets[0].name, "Test")
    }
}
