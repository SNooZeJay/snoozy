import XCTest
@testable import Snoozy

final class SnoozyMarqueeTests: XCTestCase {
    func testShortTextDoesNotScroll() {
        XCTAssertFalse(SnoozyMarqueeMath.shouldScroll(contentWidth: 120, availableWidth: 200))
    }

    func testOverflowingTextScrolls() {
        XCTAssertTrue(SnoozyMarqueeMath.shouldScroll(contentWidth: 240, availableWidth: 200))
    }

    func testZeroAvailableWidthDoesNotScroll() {
        XCTAssertFalse(SnoozyMarqueeMath.shouldScroll(contentWidth: 240, availableWidth: 0))
    }

    func testLoopDurationUsesContentPlusGap() {
        let duration = SnoozyMarqueeMath.loopDuration(contentWidth: 200, gap: 32, speed: 29)
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration ?? 0, 8.0, accuracy: 0.001)
    }

    func testLoopDurationRejectsInvalidInput() {
        XCTAssertNil(SnoozyMarqueeMath.loopDuration(contentWidth: 200, gap: 32, speed: 0))
        XCTAssertNil(SnoozyMarqueeMath.loopDuration(contentWidth: 0, gap: 32, speed: 30))
    }

    func testLoopOffsetStartsAtZero() {
        XCTAssertEqual(
            SnoozyMarqueeMath.loopOffset(elapsed: 0, contentWidth: 200, gap: 32, speed: 29),
            0
        )
    }

    func testLoopOffsetWrapsAtLoopBoundary() {
        let duration = SnoozyMarqueeMath.loopDuration(contentWidth: 200, gap: 32, speed: 29) ?? 0
        XCTAssertEqual(
            SnoozyMarqueeMath.loopOffset(
                elapsed: duration,
                contentWidth: 200,
                gap: 32,
                speed: 29
            ),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            SnoozyMarqueeMath.loopOffset(
                elapsed: duration / 2,
                contentWidth: 200,
                gap: 32,
                speed: 29
            ),
            116,
            accuracy: 0.001
        )
    }

    func testLoopOffsetRejectsInvalidInput() {
        XCTAssertEqual(
            SnoozyMarqueeMath.loopOffset(elapsed: 1, contentWidth: 0, gap: 32, speed: 30),
            0
        )
        XCTAssertEqual(
            SnoozyMarqueeMath.loopOffset(elapsed: 1, contentWidth: 200, gap: 32, speed: 0),
            0
        )
    }
}
