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
}
