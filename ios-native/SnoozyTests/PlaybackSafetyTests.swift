import XCTest
@testable import Snoozy

final class PlaybackSafetyTests: XCTestCase {
    func testInterruptionDoesNotResumePlaybackThatWasAlreadyPaused() {
        var state = PlaybackInterruptionState()
        state.began(wasPlaying: false)

        XCTAssertFalse(state.ended(canResume: true))
    }

    func testInterruptionResumesOnlyWhenPlaybackWasActiveAndSystemAllows() {
        var state = PlaybackInterruptionState()
        state.began(wasPlaying: true)

        XCTAssertFalse(state.ended(canResume: false))

        state.began(wasPlaying: true)
        XCTAssertTrue(state.ended(canResume: true))
    }

    func testListeningTrackerCountsNormalProgress() {
        var tracker = PlaybackListeningTracker()
        tracker.start(atMs: 0)

        tracker.tick(positionMs: 1_000, isPlaying: true)
        tracker.tick(positionMs: 2_000, isPlaying: true)

        XCTAssertEqual(tracker.listenedMs, 2_000)
    }

    func testListeningTrackerIgnoresSeekJump() {
        var tracker = PlaybackListeningTracker()
        tracker.start(atMs: 0)
        tracker.tick(positionMs: 1_000, isPlaying: true)

        tracker.tick(positionMs: 120_000, isPlaying: true)
        tracker.tick(positionMs: 121_000, isPlaying: true)

        XCTAssertEqual(tracker.listenedMs, 2_000)
    }

    func testListeningTrackerIgnoresPausedTicks() {
        var tracker = PlaybackListeningTracker()
        tracker.start(atMs: 0)

        tracker.tick(positionMs: 1_000, isPlaying: false)
        tracker.tick(positionMs: 2_000, isPlaying: true)

        XCTAssertEqual(tracker.listenedMs, 0)
    }

    func testListeningTrackerResetsForNextTrack() {
        var tracker = PlaybackListeningTracker()
        tracker.start(atMs: 0)
        tracker.tick(positionMs: 5_000, isPlaying: true)

        tracker.start(atMs: 0)
        tracker.tick(positionMs: 1_000, isPlaying: true)

        XCTAssertEqual(tracker.listenedMs, 1_000)
    }
}
