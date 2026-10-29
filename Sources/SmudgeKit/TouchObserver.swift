import UIKit

/// A gesture recognizer that only watches. It never recognizes, never cancels or delays touches
/// in the view, and can't be prevented by other recognizers, so it keeps seeing touches even
/// after something like a pan or a globe drag has claimed them.
@MainActor
final class TouchObserver: UIGestureRecognizer {
    /// Called with every batch of touches, in whatever phase they are in.
    var onTouches: (Set<UITouch>, UIEvent) -> Void = { _, _ in }
    /// Called when the recognizer resets with touches it never saw end, so they can be cleaned up.
    var onOrphans: (Set<ObjectIdentifier>) -> Void = { _ in }

    private var active: Set<ObjectIdentifier> = []

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
        allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue),
            NSNumber(value: UITouch.TouchType.pencil.rawValue),
        ]
        name = "SmudgeKit.TouchObserver"
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        active.formUnion(touches.map(ObjectIdentifier.init))
        onTouches(touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouches(touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, event)
    }

    override func reset() {
        super.reset()
        if !active.isEmpty {
            let orphans = active
            active.removeAll()
            onOrphans(orphans)
        }
    }

    private func finish(_ touches: Set<UITouch>, _ event: UIEvent) {
        active.subtract(touches.map(ObjectIdentifier.init))
        onTouches(touches, event)
        // Staying in .possible keeps us out of everyone's way; failing once the last finger is up
        // lets UIKit reset us for the next sequence.
        if active.isEmpty {
            state = .failed
        }
    }
}
