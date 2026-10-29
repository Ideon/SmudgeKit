import UIKit

/// Draws the touches of one window scene. Watches every window in the scene and draws either into
/// a shared overlay window or on top of the window each touch lands in. One instance per scene,
/// shared by however many `TouchSmudges` handles asked for it.
@MainActor
final class SceneSmudger {
    private static var active: [ObjectIdentifier: SceneSmudger] = [:]

    private let id: ObjectIdentifier
    private(set) weak var scene: UIWindowScene?
    var style: SmudgeStyle
    var placement: SmudgePlacement {
        didSet {
            if placement != oldValue, !isTornDown {
                clear()
                updateOverlay()
            }
        }
    }

    private(set) var isTornDown = false
    private var overlay: OverlayWindow?
    /// Layers drawn on top of the app's own windows, for `.hostWindow`.
    private var hostLayers: [ObjectIdentifier: CALayer] = [:]
    /// The view each touch's coordinates are in.
    private var canvases: [ObjectIdentifier: UIView] = [:]
    private var tracker = TouchTracker<ObjectIdentifier>()
    private var smudges: [ObjectIdentifier: Smudge] = [:]
    private var observers: [ObjectIdentifier: (window: WeakWindow, observer: TouchObserver)] = [:]
    private var lifecycle: [Task<Void, Never>] = []
    private var users = 0

    static func acquire(
        for scene: UIWindowScene,
        style: SmudgeStyle,
        placement: SmudgePlacement
    ) -> SceneSmudger {
        let id = ObjectIdentifier(scene)
        let smudger: SceneSmudger
        if let existing = active[id], existing.scene === scene {
            smudger = existing
            smudger.style = style
            smudger.placement = placement
        } else {
            smudger = SceneSmudger(scene: scene, style: style, placement: placement)
            active[id] = smudger
        }
        smudger.users += 1
        return smudger
    }

    private init(scene: UIWindowScene, style: SmudgeStyle, placement: SmudgePlacement) {
        self.id = ObjectIdentifier(scene)
        self.scene = scene
        self.style = style
        self.placement = placement

        updateOverlay()
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

    // MARK: Windows

    private func updateOverlay() {
        switch placement {
        case .overlayWindow:
            guard overlay == nil, let scene else { return }
            let overlay = OverlayWindow(windowScene: scene)
            overlay.isHidden = false
            self.overlay = overlay
        case .hostWindow:
            overlay?.isHidden = true
            overlay = nil
        }
    }

    /// Where a touch is drawn: the layer to add its smudge to, and the view its coordinates are in.
    private func canvas(for touch: UITouch) -> (layer: CALayer, space: UIView)? {
        switch placement {
        case .overlayWindow:
            guard let overlay else { return nil }
            return (overlay.container, overlay)
        case .hostWindow:
            guard let window = touch.window, !(window is OverlayWindow) else { return nil }
            return (hostLayer(in: window), window)
        }
    }

    private func hostLayer(in window: UIWindow) -> CALayer {
        let key = ObjectIdentifier(window)
        let container = hostLayers[key] ?? {
            let container = CALayer()
            container.name = "SmudgeKit"
            hostLayers[key] = container
            return container
        }()
        raise(container, in: window)
        return container
    }

    /// Keeps the layer above everything else in the window, which adds views and layers over it
    /// as the app presents things.
    private func raise(_ container: CALayer, in window: UIWindow) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if window.layer.sublayers?.last !== container {
            window.layer.addSublayer(container)
        }
        if container.frame != window.layer.bounds {
            container.frame = window.layer.bounds
        }
        CATransaction.commit()
    }

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
        guard !isTornDown else { return }
        for touch in touches {
            let key = ObjectIdentifier(touch)
            switch touch.phase {
            case .began:
                guard let canvas = canvas(for: touch) else { continue }
                let location = touch.location(in: canvas.space)
                if tracker.begin(key, at: location, time: touch.timestamp) {
                    let smudge = Smudge(style: style, traits: canvas.space.traitCollection)
                    canvas.layer.addSublayer(smudge.layer)
                    smudge.appear(at: location)
                    smudges[key] = smudge
                    canvases[key] = canvas.space
                } else {
                    smudges[key]?.move(to: location)
                }
            case .moved, .stationary:
                guard let space = canvases[key] else { continue }
                if placement == .hostWindow, let window = space as? UIWindow {
                    _ = hostLayer(in: window)
                }
                for sample in event.coalescedTouches(for: touch) ?? [touch] {
                    tracker.move(key, to: sample.location(in: space), time: sample.timestamp)
                }
                if let tracked = tracker[key] {
                    smudges[key]?.move(to: tracked.location)
                }
            case .ended:
                guard let space = canvases.removeValue(forKey: key) else { continue }
                let location = touch.location(in: space)
                if let tracked = tracker.end(key, at: location, time: touch.timestamp) {
                    smudges.removeValue(forKey: key)?.lift(at: tracked.location, velocity: tracked.velocity)
                }
            case .cancelled:
                canvases[key] = nil
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
            canvases[key] = nil
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
        canvases.removeAll()
        for container in hostLayers.values {
            container.removeFromSuperlayer()
        }
        hostLayers.removeAll()
    }

    private func tearDown() {
        guard !isTornDown else { return }
        clear()
        for task in lifecycle {
            task.cancel()
        }
        lifecycle.removeAll()
        for entry in observers.values {
            entry.window.window?.removeGestureRecognizer(entry.observer)
        }
        observers.removeAll()
        overlay?.isHidden = true
        overlay = nil
        isTornDown = true
        if Self.active[id] === self {
            Self.active[id] = nil
        }
    }
}

private struct WeakWindow {
    weak var window: UIWindow?
    init(_ window: UIWindow) { self.window = window }
}
