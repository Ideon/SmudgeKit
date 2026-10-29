import CoreGraphics
import Testing
@testable import SmudgeKit

@Suite struct TouchTrackerTests {
    @Test func beginTracksTouchAtRest() {
        var tracker = TouchTracker<Int>()
        let isNew = tracker.begin(1, at: CGPoint(x: 10, y: 20), time: 0)
        #expect(isNew)
        #expect(tracker.count == 1)
        #expect(tracker[1]?.location == CGPoint(x: 10, y: 20))
        #expect(tracker[1]?.velocity == .zero)
    }

    @Test func beginTwiceActsAsMove() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        let isNew = tracker.begin(1, at: CGPoint(x: 5, y: 0), time: 0.01)
        #expect(!isNew)
        #expect(tracker.count == 1)
        #expect(tracker[1]?.location == CGPoint(x: 5, y: 0))
    }

    @Test func movesOfUnknownTouchesAreIgnored() {
        var tracker = TouchTracker<Int>()
        tracker.move(7, to: CGPoint(x: 1, y: 1), time: 1)
        #expect(tracker.count == 0)
        let ended = tracker.end(7, at: .zero, time: 2)
        let cancelled = tracker.cancel(7)
        #expect(ended == nil)
        #expect(cancelled == nil)
    }

    @Test func velocityConvergesOnSteadyDrag() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        // 1000 pt/s to the right, 500 pt/s up, sampled at 120 Hz.
        for step in 1...30 {
            let t = Double(step) / 120
            tracker.move(1, to: CGPoint(x: 1000 * t, y: -500 * t), time: t)
        }
        let velocity = tracker[1]!.velocity
        #expect(abs(velocity.dx - 1000) < 10)
        #expect(abs(velocity.dy + 500) < 5)
    }

    @Test func velocitySmoothsOutAJitterySample() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        for step in 1...20 {
            let t = Double(step) / 120
            tracker.move(1, to: CGPoint(x: 600 * t, y: 0), time: t)
        }
        // One sample jumps sideways.
        tracker.move(1, to: CGPoint(x: 600 * 21 / 120, y: 8), time: 21 / 120)
        let velocity = tracker[1]!.velocity
        #expect(velocity.dx > 500)
        #expect(velocity.dy < 960, "less than the raw 960 pt/s jump")
    }

    @Test func samplesWithoutTimeDeltaDoNotDivideByZero() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 1)
        tracker.move(1, to: CGPoint(x: 10, y: 0), time: 1)
        let touch = tracker[1]!
        #expect(touch.location == CGPoint(x: 10, y: 0))
        #expect(touch.velocity.dx.isFinite)
        #expect(touch.velocity == .zero)
    }

    @Test func flickKeepsItsVelocityOnLift() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        for step in 1...12 {
            let t = Double(step) / 120
            tracker.move(1, to: CGPoint(x: 0, y: 800 * t), time: t)
        }
        // UIKit reports the lift a frame later, at the last position.
        let lifted = tracker.end(1, at: CGPoint(x: 0, y: 80), time: 13.0 / 120)
        #expect(tracker.count == 0)
        #expect(lifted!.velocity.dy > 600)
    }

    @Test func liftAtNewPositionCountsTheFinalSegment() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        tracker.move(1, to: CGPoint(x: 10, y: 0), time: 0.01)
        let lifted = tracker.end(1, at: CGPoint(x: 20, y: 0), time: 0.02)!
        #expect(lifted.location == CGPoint(x: 20, y: 0))
        #expect(lifted.velocity.dx > 300, "two 1000 pt/s samples, smoothed")
    }

    @Test func restingBeforeLiftDropsVelocity() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        for step in 1...12 {
            let t = Double(step) / 120
            tracker.move(1, to: CGPoint(x: 800 * t, y: 0), time: t)
        }
        let lifted = tracker.end(1, at: CGPoint(x: 80, y: 0), time: 0.1 + 0.3)!
        #expect(abs(lifted.velocity.dx) < 10)
    }

    @Test func cancelledTouchesDoNotFling() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        tracker.move(1, to: CGPoint(x: 50, y: 0), time: 0.02)
        let cancelled = tracker.cancel(1)!
        #expect(cancelled.velocity == .zero)
        #expect(cancelled.location == CGPoint(x: 50, y: 0))
        #expect(tracker.count == 0)
    }

    @Test func touchesAreTrackedIndependently() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        tracker.begin(2, at: CGPoint(x: 100, y: 100), time: 0)
        tracker.move(1, to: CGPoint(x: 10, y: 0), time: 0.01)
        tracker.move(2, to: CGPoint(x: 100, y: 90), time: 0.01)
        #expect(tracker[1]!.velocity.dx > 0 && tracker[1]!.velocity.dy == 0)
        #expect(tracker[2]!.velocity.dy < 0 && tracker[2]!.velocity.dx == 0)
        _ = tracker.end(1, at: CGPoint(x: 10, y: 0), time: 0.02)
        #expect(tracker.count == 1)
        #expect(tracker[2] != nil)
    }

    @Test func removeAllReturnsOrphans() {
        var tracker = TouchTracker<Int>()
        tracker.begin(1, at: .zero, time: 0)
        tracker.begin(2, at: .zero, time: 0)
        let orphans = tracker.removeAll()
        #expect(Set(orphans) == [1, 2])
        #expect(tracker.count == 0)
    }
}
