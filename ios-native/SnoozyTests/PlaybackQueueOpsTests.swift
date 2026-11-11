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

    func testRootTabSwipeMathContinuousProgressAndSettle() {
        // Swiping left (-150 pt on a 300 pt width) from tab 1 moves indicator halfway toward tab 2 (1.5)
        let midProgress = RootTabSwipeMath.continuousProgress(
            currentIndex: 1,
            tabCount: 5,
            translationWidth: -150,
            containerWidth: 300
        )
        XCTAssertEqual(midProgress, 1.5, accuracy: 0.001)

        // Swiping right at index 0 applies rubber-band damping instead of exceeding bounds
        let overscrollLeft = RootTabSwipeMath.continuousProgress(
            currentIndex: 0,
            tabCount: 5,
            translationWidth: 150,
            containerWidth: 300
        )
        XCTAssertLessThan(overscrollLeft, 0.0)
        XCTAssertGreaterThan(overscrollLeft, -0.25)

        // Completed swipe left (> 28% of width) advances to next tab
        let settledNext = RootTabSwipeMath.resolveSwipeTargetIndex(
            currentIndex: 1,
            tabCount: 5,
            translationWidth: -110,
            predictedEndTranslationWidth: -140,
            containerWidth: 300
        )
        XCTAssertEqual(settledNext, 2)

        // Incomplete swipe (< 28% of width and low velocity) returns to original tab
        let incomplete = RootTabSwipeMath.resolveSwipeTargetIndex(
            currentIndex: 2,
            tabCount: 5,
            translationWidth: -40,
            predictedEndTranslationWidth: -60,
            containerWidth: 300
        )
        XCTAssertEqual(incomplete, 2)

        // Pill scrub progress maps touch X across pill width to tab index space
        let pillScrub = RootTabSwipeMath.pillScrubProgress(
            locationX: 150,
            pillWidth: 300,
            tabCount: 5
        )
        XCTAssertEqual(pillScrub, 2.0, accuracy: 0.001)
    }
}
