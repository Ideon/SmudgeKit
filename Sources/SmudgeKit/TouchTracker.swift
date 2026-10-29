import CoreGraphics
import Foundation

/// Bookkeeping for the touches currently on screen: where each one is and how fast it is moving.
///
/// Kept free of UIKit so it can be tested with synthetic samples. Velocity is in points per
/// second, smoothed over the last few samples so a single jittery event doesn't decide the
/// direction a smudge flies off in.
struct TouchTracker<Key: Hashable> {
    struct Touch: Equatable {
        var location: CGPoint
        var velocity: CGVector
        var timestamp: TimeInterval
    }

    /// Time constant for velocity smoothing. Samples older than a few of these barely count.
    var smoothing: TimeInterval = 0.04
    /// How quickly velocity is forgotten once the finger stops moving before it lifts.
    var restDecay: TimeInterval = 0.05

    private(set) var touches: [Key: Touch] = [:]

    var count: Int { touches.count }
    var keys: Dictionary<Key, Touch>.Keys { touches.keys }

    subscript(key: Key) -> Touch? { touches[key] }

    /// Starts tracking a touch. Returns false when the key was already tracked, in which case the
    /// sample is treated as a move.
    @discardableResult
    mutating func begin(_ key: Key, at location: CGPoint, time: TimeInterval) -> Bool {
        guard touches[key] == nil else {
            move(key, to: location, time: time)
            return false
        }
        touches[key] = Touch(location: location, velocity: .zero, timestamp: time)
        return true
    }

    /// Records a new position. Unknown keys are ignored.
    mutating func move(_ key: Key, to location: CGPoint, time: TimeInterval) {
        guard var touch = touches[key] else { return }
        let dt = time - touch.timestamp
        if dt > 0 {
            let instant = CGVector(
                dx: (location.x - touch.location.x) / dt,
                dy: (location.y - touch.location.y) / dt
            )
            let weight = 1 - exp(-dt / smoothing)
            touch.velocity = CGVector(
                dx: touch.velocity.dx + (instant.dx - touch.velocity.dx) * weight,
                dy: touch.velocity.dy + (instant.dy - touch.velocity.dy) * weight
            )
            touch.timestamp = time
        }
        touch.location = location
        touches[key] = touch
    }

    /// Stops tracking a lifted touch and returns its final state, with the velocity it should
    /// carry on with. A finger that rested before lifting carries little or none.
    mutating func end(_ key: Key, at location: CGPoint, time: TimeInterval) -> Touch? {
        guard let previous = touches[key] else { return nil }
        let rested = location == previous.location
        if !rested {
            move(key, to: location, time: time)
        }
        guard var touch = touches.removeValue(forKey: key) else { return nil }
        if rested {
            let factor = exp(-max(0, time - previous.timestamp) / restDecay)
            touch.velocity = CGVector(dx: touch.velocity.dx * factor, dy: touch.velocity.dy * factor)
        }
        touch.timestamp = time
        return touch
    }

    /// Stops tracking a cancelled touch. Cancelled touches don't fling, so velocity is dropped.
    mutating func cancel(_ key: Key) -> Touch? {
        guard var touch = touches.removeValue(forKey: key) else { return nil }
        touch.velocity = .zero
        return touch
    }

    /// Forgets every touch, returning the keys that were still tracked.
    mutating func removeAll() -> [Key] {
        let keys = Array(touches.keys)
        touches.removeAll()
        return keys
    }
}
