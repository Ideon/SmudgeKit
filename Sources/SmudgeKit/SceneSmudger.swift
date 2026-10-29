import UIKit

/// Draws the touches of one window scene. Watches every window in the scene and draws into a
/// shared overlay window, so touches show up whichever window they land in. One instance per
/// scene, shared by however many `TouchSmudges` handles asked for it.
@MainActor
final class SceneSmudger {
    private static var active: [ObjectIdentifier: SceneSmudger] = [:]

    private let id: ObjectIdentifier
    private(set) weak var scene: UIWindowScene?
    var style: SmudgeStyle

    private var overlay: OverlayWindow?
    private var tracker = TouchTracker<ObjectIdentifier>()
    private var smudges: [ObjectIdentifier: Smudge] = [:]
    private var observers: [ObjectIdentifier: (window: WeakWindow, observer: TouchObserver)] = [:]
    private var lifecycle: [Task<Void, Never>] = []
    private var users = 0

    static func acquire(for scene: UIWindowScene, style: SmudgeStyle) -> SceneSmudger {
        let id = ObjectIdentifier(scene)
        let smudger: SceneSmudger
        if let existing = active[id], existing.scene === scene {
            smudger = existing
            smudger.style = style
        } else {
            smudger = SceneSmudger(scene: scene, style: style)
            active[id] = smudger
        }
        smudger.users += 1
        return smudger
    }

    private init(scene: UIWindowScene, style: SmudgeStyle) {
        self.id = ObjectIdentifier(scene)
        self.scene = scene
        self.style = style

        let overlay = OverlayWindow(windowScene: scene)
        overlay.isHidden = false
        self.overlay = overlay

        attachToWindows()
        watch(UIWindow.didBecomeVisibleNotification, object: nil) { $0.attachToWindows() }
        watch(UIScene.didEnterBackgroundNotification, object: scene) { $0.clear() }
        watch(UIScene.didDisconnectNotification, object: scene) { $0.tearDown() }
    }

    func release() {
        users -= 1
        if users <= 0 {
            tearDown()
        }
    }

    var isTornDown: Bool { overlay == nil }

    // MARK: Windows

    private func attachToWindows() {
        guard let scene else { return }
        observers = observers.filter { $0.value.window.window != nil }
        for window in scene.windows where !(window is OverlayWindow) {
            let key = ObjectIdentifier(window)
            guard observers[key] == nil else { continue }
            let observer = TouchObserver()
            observer.onTouches = { [weak self] touches, event in
                self?.handle(touches, event: event)
            }
            observer.onOrphans = { [weak self] keys in
                self?.drop(keys)
            }
            window.addGestureRecognizer(observer)
            observers[key] = (WeakWindow(window), observer)
        }
    }

    private func watch(
        _ name: Notification.Name,
        object: UIScene?,
        perform action: @escaping @MainActor (SceneSmudger) -> Void
    ) {
        let notifications = NotificationCenter.default.notifications(named: name, object: object)
        lifecycle.append(Task { [weak self] in
            for await _ in notifications.map({ _ in () }) {
                guard let self else { return }
                action(self)
            }
        })
    }

    // MARK: Touches

    private func handle(_ touches: Set<UITouch>, event: UIEvent) {
        guard let overlay else { return }
        for touch in touches {
            let key = ObjectIdentifier(touch)
            switch touch.phase {
            case .began:
                let location = touch.location(in: overlay)
                if tracker.begin(key, at: location, time: touch.timestamp) {
                    let smudge = Smudge(style: style, traits: overlay.traitCollection)
                    overlay.container.addSublayer(smudge.layer)
                    smudge.appear(at: location)
                    smudges[key] = smudge
                } else {
                    smudges[key]?.move(to: location)
                }
            case .moved, .stationary:
                for sample in event.coalescedTouches(for: touch) ?? [touch] {
                    tracker.move(key, to: sample.location(in: overlay), time: sample.timestamp)
                }
                if let tracked = tracker[key] {
                    smudges[key]?.move(to: tracked.location)
                }
            case .ended:
                let location = touch.location(in: overlay)
                if let tracked = tracker.end(key, at: location, time: touch.timestamp) {
                    smudges.removeValue(forKey: key)?.lift(at: tracked.location, velocity: tracked.velocity)
                }
            case .cancelled:
                if let tracked = tracker.cancel(key) {
                    smudges.removeValue(forKey: key)?.lift(at: tracked.location, velocity: .zero)
                }
            default:
                break
            }
        }
    }

    /// Fades out touches whose end we never saw.
    private func drop(_ keys: Set<ObjectIdentifier>) {
        for key in keys {
            if let tracked = tracker.cancel(key) {
                smudges.removeValue(forKey: key)?.lift(at: tracked.location, velocity: .zero)
            }
        }
    }

    /// Removes every smudge at once, for when the scene goes away from the screen.
    private func clear() {
        _ = tracker.removeAll()
        for smudge in smudges.values {
            smudge.remove()
        }
        smudges.removeAll()
    }

    private func tearDown() {
        guard let overlay else { return }
        clear()
        for task in lifecycle {
            task.cancel()
        }
        lifecycle.removeAll()
        for entry in observers.values {
            entry.window.window?.removeGestureRecognizer(entry.observer)
        }
        observers.removeAll()
        overlay.isHidden = true
        self.overlay = nil
        if Self.active[id] === self {
            Self.active[id] = nil
        }
    }
}

private struct WeakWindow {
    weak var window: UIWindow?
    init(_ window: UIWindow) { self.window = window }
}
