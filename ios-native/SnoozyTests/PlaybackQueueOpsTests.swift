import XCTest
@testable import Snoozy

final class PlaybackQueueOpsTests: XCTestCase {
    func testPlayNextDeduplicatesAndRelocatesBeforeActive() {
        let result = PlaybackQueueOps.playNextOrder(
            queue: ["a", "b", "c", "d"],
            activeIndex: 2,
            trackId: "a"
        )
        XCTAssertEqual(result.queue, ["b", "c", "a", "d"])
        XCTAssertEqual(result.insertIndex, 2)
        XCTAssertEqual(result.removeIndex, 0)
    }

    func testPlayNextInsertsAfterActiveWhenNew() {
        let result = PlaybackQueueOps.playNextOrder(
            queue: ["a", "b", "c"],
            activeIndex: 0,
            trackId: "x"
        )
        XCTAssertEqual(result.queue, ["a", "x", "b", "c"])
        XCTAssertEqual(result.insertIndex, 1)
        XCTAssertEqual(result.removeIndex, -1)
    }

    func testAppendUniqueSkipsExistingTrack() {
        XCTAssertEqual(PlaybackQueueOps.appendUnique(["a", "b"], "b"), ["a", "b"])
        XCTAssertEqual(PlaybackQueueOps.appendUnique(["a", "b"], "c"), ["a", "b", "c"])
    }

    func testShouldRecordPlayThreshold() {
        XCTAssertFalse(PlaybackQueueOps.shouldRecordPlay(durationSeconds: 120, listenedMs: 25_000))
        XCTAssertTrue(PlaybackQueueOps.shouldRecordPlay(durationSeconds: 120, listenedMs: 30_000))
        XCTAssertTrue(PlaybackQueueOps.shouldRecordPlay(durationSeconds: 20, listenedMs: 10_000))
    }

    func testTrackFolderNameAndAudioFormatBadge() {
        let nestedFlac = Track(
            id: "1",
            title: "Xtal",
            artist: "Aphex Twin",
            album: "Selected Ambient Works 85-92",
            duration: 294,
            relativePath: "Ambient/Aphex Twin/01 - Xtal.flac",
            addedAt: 100
        )
        XCTAssertEqual(nestedFlac.folderName, "Ambient/Aphex Twin")
        XCTAssertEqual(nestedFlac.audioFormatBadge, "FLAC")
        XCTAssertTrue(nestedFlac.isLosslessFormat)

        let rootMp3 = Track(
            id: "2",
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            duration: 243,
            relativePath: "Midnight City.mp3",
            addedAt: 200
        )
        XCTAssertEqual(rootMp3.folderName, "Snoozy Root")
        XCTAssertEqual(rootMp3.audioFormatBadge, "MP3")
        XCTAssertFalse(rootMp3.isLosslessFormat)
    }

    func testFormatRemainingClock() {
        XCTAssertEqual(SnoozyFormat.formatRemainingClock(elapsed: 84, duration: 245), "-2:41")
        XCTAssertEqual(SnoozyFormat.formatRemainingClock(elapsed: 250, duration: 245), "-0:00")
    }
}
