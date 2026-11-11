import XCTest
@testable import Snoozy

final class LyricsEngineTests: XCTestCase {
    func testParseSyncedLrcAndResolveActiveLine() {
        let lrc = """
        [ti:Nikes]
        [ar:Frank Ocean]
        [00:12.50]These bitches want Nikes
        [00:16.00]They looking for a check
        [00:20.25]Tell em it ain't likely
        """
        let parsed = LyricsEngine.parseLrc(lrc)
        XCTAssertTrue(parsed.isSynced)
        XCTAssertEqual(parsed.lines.count, 3)
        XCTAssertEqual(parsed.lines[0].timeSeconds, 12.50)
        XCTAssertEqual(LyricsEngine.activeLineIndex(lyrics: parsed, positionSeconds: 10.0), nil)
        XCTAssertEqual(LyricsEngine.activeLineIndex(lyrics: parsed, positionSeconds: 13.0), 0)
        XCTAssertEqual(LyricsEngine.activeLineIndex(lyrics: parsed, positionSeconds: 17.5), 1)
        XCTAssertEqual(LyricsEngine.activeLineIndex(lyrics: parsed, positionSeconds: 17.5, offsetSeconds: 2.0), 0)
    }
}
