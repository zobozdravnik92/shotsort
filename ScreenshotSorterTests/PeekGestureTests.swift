import CoreGraphics
import Testing
@testable import ScreenshotSorter

/// Press-and-hold preview on category cards: which releases delete.
struct PeekGestureTests {
    private let toward = Peek.deleteDirection

    @Test func aLongDragDeletes() {
        #expect(Peek.isDelete(translation: 130 * toward, velocity: 0))
    }

    @Test func aQuickFlickDeletes() {
        // Measured in the Simulator: 75 points at about 630 points per second.
        #expect(Peek.isDelete(translation: 75 * toward, velocity: 630 * toward))
    }

    @Test func aSmallSlowMoveDoesNotDelete() {
        #expect(!Peek.isDelete(translation: 60 * toward, velocity: 100 * toward))
    }

    @Test func aTwitchWhileHoldingDoesNotDelete() {
        #expect(!Peek.isDelete(translation: 20 * toward, velocity: 2_000 * toward))
    }

    @Test func movingTheOtherWayNeverDeletes() {
        #expect(!Peek.isDelete(translation: -200 * toward, velocity: -1_500 * toward))
    }
}
