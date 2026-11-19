import XCTest
@testable import Snoozy

final class AutomixLogicTests: XCTestCase {
    func testEqualPowerGainsHoldConstantEnergy() {
        let start = AutomixLogic.equalPowerGains(progress: 0.0)
        XCTAssertEqual(start.outgoing, 1.0, accuracy: 0.0001)
        XCTAssertEqual(start.incoming, 0.0, accuracy: 0.0001)

        let middle = AutomixLogic.equalPowerGains(progress: 0.5)
        XCTAssertEqual(middle.outgoing, 0.7071, accuracy: 0.001)
        XCTAssertEqual(middle.incoming, 0.7071, accuracy: 0.001)
        XCTAssertEqual(
            middle.outgoing * middle.outgoing + middle.incoming * middle.incoming,
            1.0,
            accuracy: 0.001
        )

        let end = AutomixLogic.equalPowerGains(progress: 1.0)
        XCTAssertEqual(end.outgoing, 0.0, accuracy: 0.0001)
        XCTAssertEqual(end.incoming, 1.0, accuracy: 0.0001)
    }

    func testEqualPowerGainsClampOutOfRangeProgress() {
        let below = AutomixLogic.equalPowerGains(progress: -1.0)
        XCTAssertEqual(below.outgoing, 1.0, accuracy: 0.0001)
        XCTAssertEqual(below.incoming, 0.0, accuracy: 0.0001)

        let above = AutomixLogic.equalPowerGains(progress: 2.0)
        XCTAssertEqual(above.outgoing, 0.0, accuracy: 0.0001)
        XCTAssertEqual(above.incoming, 1.0, accuracy: 0.0001)

        let invalid = AutomixLogic.equalPowerGains(progress: .nan)
        XCTAssertEqual(invalid.outgoing, 1.0, accuracy: 0.0001)
        XCTAssertEqual(invalid.incoming, 0.0, accuracy: 0.0001)
    }

    func testCrossfadeClamp() {
        XCTAssertEqual(AutomixLogic.clampedCrossfade(-2), 0, accuracy: 0.0001)
        XCTAssertEqual(AutomixLogic.clampedCrossfade(4), 4, accuracy: 0.0001)
        XCTAssertEqual(AutomixLogic.clampedCrossfade(20), 12, accuracy: 0.0001)
        XCTAssertEqual(AutomixLogic.clampedCrossfade(.nan), 0, accuracy: 0.0001)
    }

    func testNextIndexHonoursRepeatMode() {
        XCTAssertEqual(
            AutomixLogic.nextIndex(currentIndex: 0, queueCount: 3, repeatMode: .off),
            1
        )
        XCTAssertEqual(
            AutomixLogic.nextIndex(currentIndex: 2, queueCount: 3, repeatMode: .all),
            0
        )
        XCTAssertNil(AutomixLogic.nextIndex(currentIndex: 2, queueCount: 3, repeatMode: .off))
        XCTAssertNil(AutomixLogic.nextIndex(currentIndex: 1, queueCount: 3, repeatMode: .one))
        XCTAssertNil(AutomixLogic.nextIndex(currentIndex: 0, queueCount: 1, repeatMode: .all))
    }

    func testPlanUsesCrossfadeAndSequentialNextTrack() {
        let plan = AutomixLogic.plan(
            repeatMode: .off,
            queueCount: 4,
            currentIndex: 1,
            currentDuration: 180,
            nextDuration: 200,
            crossfadeSeconds: 4,
            gaplessEnabled: false
        )
        XCTAssertEqual(plan, AutomixPlan(nextIndex: 2, overlapSeconds: 4))
    }

    func testPlanWrapsForRepeatAll() {
        let plan = AutomixLogic.plan(
            repeatMode: .all,
            queueCount: 3,
            currentIndex: 2,
            currentDuration: 180,
            nextDuration: 200,
            crossfadeSeconds: 6,
            gaplessEnabled: false
        )
        XCTAssertEqual(plan?.nextIndex, 0)
        XCTAssertEqual(plan?.overlapSeconds, 6)
    }

    func testPlanRejectsRepeatOneAndEndOfQueue() {
        XCTAssertNil(AutomixLogic.plan(
            repeatMode: .one,
            queueCount: 4,
            currentIndex: 1,
            currentDuration: 180,
            nextDuration: 200,
            crossfadeSeconds: 4,
            gaplessEnabled: false
        ))
        XCTAssertNil(AutomixLogic.plan(
            repeatMode: .off,
            queueCount: 4,
            currentIndex: 3,
            currentDuration: 180,
            nextDuration: 200,
            crossfadeSeconds: 4,
            gaplessEnabled: false
        ))
    }

    func testGaplessOverridesCrossfadeSlider() {
        let plan = AutomixLogic.plan(
            repeatMode: .off,
            queueCount: 2,
            currentIndex: 0,
            currentDuration: 180,
            nextDuration: 180,
            crossfadeSeconds: 9,
            gaplessEnabled: true
        )
        XCTAssertEqual(plan?.overlapSeconds ?? 0, AutomixLogic.gaplessOverlapSeconds, accuracy: 0.0001)
    }

    func testShortTrackCapsOverlap() {
        let overlap = AutomixLogic.effectiveOverlap(
            requestedCrossfade: 12,
            gaplessEnabled: false,
            currentDuration: 4,
            nextDuration: 180
        )
        XCTAssertEqual(overlap, 1.6, accuracy: 0.0001)
    }

    func testUnknownDurationKeepsRequestedOverlap() {
        let overlap = AutomixLogic.effectiveOverlap(
            requestedCrossfade: 5,
            gaplessEnabled: false,
            currentDuration: 0,
            nextDuration: 0
        )
        XCTAssertEqual(overlap, 5, accuracy: 0.0001)
    }

    func testZeroOverlapWithoutGaplessProducesNoPlan() {
        XCTAssertNil(AutomixLogic.plan(
            repeatMode: .off,
            queueCount: 3,
            currentIndex: 0,
            currentDuration: 180,
            nextDuration: 180,
            crossfadeSeconds: 0,
            gaplessEnabled: false
        ))
    }
}
