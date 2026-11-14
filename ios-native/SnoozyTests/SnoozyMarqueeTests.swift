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
}
