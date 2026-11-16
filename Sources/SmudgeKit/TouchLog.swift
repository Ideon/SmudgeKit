#if SMUDGEKIT_ENABLED
import SwiftUI

/// What happened to a touch log written by `logsTouches(_:saveTo:onEvent:)`.
public enum TouchLogEvent: Sendable {
    case saved(URL)
    case saveFailed(any Error)
}

extension View {
    /// Logs every touch in the scene, with its full path and timing, for replaying a take later.
    /// One log per foreground stretch, like `recordsScreen(_:saveTo:onEvent:)`: logging starts
    /// when the scene becomes active and the log is saved when it goes to the background. Times
    /// are seconds from that start, and positions are points in the screen's coordinate space.
    ///
    /// - Parameters:
    ///   - destination: Where each log is saved, replacing any file there. When nil, each log gets
    ///     its own file in `Documents/SmudgeKit Recordings`, named by the time it was saved, so it
    ///     sits beside the take `recordsScreen` saves.
    ///   - onEvent: Called on the main actor when a log is saved, or fails to save.
    public func logsTouches(
        _ isEnabled: Bool = true,
        saveTo destination: URL? = nil,
        onEvent: (@MainActor @Sendable (TouchLogEvent) -> Void)? = nil
    ) -> some View {
        background(TouchLogAnchor(isEnabled: isEnabled, destination: destination, onEvent: onEvent))
    }
}

/// The saved form of a touch log.
public struct TouchLogFile: Codable, Sendable {
    public struct Screen: Codable, Sendable {
        public var width: Double
        public var height: Double
        public var scale: Double
    }

    public struct Sample: Codable, Sendable {
        /// Seconds from the start of the log.
        public var t: Double
        public var x: Double
        public var y: Double
        /// `began`, `moved`, `ended` or `cancelled`.
        public var phase: String
    }

    public struct Touch: Codable, Sendable {
        public var id: Int
        public var samples: [Sample]
    }

    public var version = 1
    public var screen: Screen
    /// Seconds the log covers.
    public var duration: Double
    public var touches: [Touch]
}

private struct TouchLogAnchor: UIViewRepresentable {
    var isEnabled: Bool
    var destination: URL?
    var onEvent: (@MainActor @Sendable (TouchLogEvent) -> Void)?

    func makeUIView(context: Context) -> TouchLogView { TouchLogView() }

    func updateUIView(_ view: TouchLogView, context: Context) {
        view.destination = destination
        view.onEvent = onEvent
        view.isLogging = isEnabled
    }

    static func dismantleUIView(_ view: TouchLogView, coordinator: ()) {
        view.isLogging = false
    }
}

private final class TouchLogView: UIView {
    var destination: URL?
    var onEvent: (@MainActor @Sendable (TouchLogEvent) -> Void)?
    var isLogging = false {
        didSet { refresh() }
    }

    private var logger: SceneTouchLogger?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
    }

    private func refresh() {
        let scene = isLogging ? window?.windowScene : nil
        if let logger, logger.scene === scene {
            logger.destination = destination
            logger.onEvent = onEvent
            return
        }
        logger?.stop()
        logger = scene.map { SceneTouchLogger(scene: $0, destination: destination, onEvent: onEvent) }
    }
}

/// Logs the touches of one window scene, one log per foreground stretch.
@MainActor
final class SceneTouchLogger {
    private(set) weak var scene: UIWindowScene?
    var destination: URL?
    var onEvent: (@MainActor @Sendable (TouchLogEvent) -> Void)?

    private var observers: [ObjectIdentifier: (window: WeakLogWindow, observer: TouchObserver)] = [:]
    private var lifecycle: [Task<Void, Never>] = []
    /// System uptime the current log started at, or nil between foreground stretches.
    private var start: TimeInterval?
    private var ids: [ObjectIdentifier: Int] = [:]
    private var nextID = 1
    private var touches: [Int: [TouchLogFile.Sample]] = [:]

    init(scene: UIWindowScene, destination: URL?, onEvent: (@MainActor @Sendable (TouchLogEvent) -> Void)?) {
        self.scene = scene
        self.destination = destination
        self.onEvent = onEvent
        attachToWindows()
        if scene.activationState == .foregroundActive {
            begin()
        }
        watch(UIWindow.didBecomeVisibleNotification, object: nil) { $0.attachToWindows() }
        watch(UIScene.didActivateNotification, object: scene) { $0.begin() }
        watch(UIScene.didEnterBackgroundNotification, object: scene) { $0.save() }
        watch(UIScene.didDisconnectNotification, object: scene) { $0.stop() }
    }

    func stop() {
        save()
        for task in lifecycle {
            task.cancel()
        }
        lifecycle.removeAll()
        for entry in observers.values {
            entry.window.window?.removeGestureRecognizer(entry.observer)
        }
        observers.removeAll()
    }

    private func begin() {
        guard start == nil else { return }
        start = ProcessInfo.processInfo.systemUptime
        ids.removeAll()
        touches.removeAll()
        nextID = 1
    }

    private func attachToWindows() {
        guard let scene else { return }
        observers = observers.filter { $0.value.window.window != nil }
        for window in scene.windows where !(window is OverlayWindow) {
            let key = ObjectIdentifier(window)
            guard observers[key] == nil else { continue }
            let observer = TouchObserver()
            observer.name = "SmudgeKit.TouchLog"
            observer.onTouches = { [weak self] touches, event in
                self?.handle(touches, event: event)
            }
            window.addGestureRecognizer(observer)
            observers[key] = (WeakLogWindow(window), observer)
        }
    }

    private func handle(_ batch: Set<UITouch>, event: UIEvent) {
        guard let start else { return }
        for touch in batch {
            guard let window = touch.window else { continue }
            let key = ObjectIdentifier(touch)
            let phase: String
            switch touch.phase {
            case .began: phase = "began"
            case .moved, .stationary: phase = "moved"
            case .ended: phase = "ended"
            case .cancelled: phase = "cancelled"
            default: continue
            }
            let id: Int
            if touch.phase == .began || ids[key] == nil {
                id = nextID
                nextID += 1
                ids[key] = id
            } else {
                id = ids[key]!
            }
            let screen = window.screen.coordinateSpace
            let samples = phase == "moved" ? (event.coalescedTouches(for: touch) ?? [touch]) : [touch]
            for sample in samples {
                let point = window.convert(sample.location(in: window), to: screen)
                touches[id, default: []].append(TouchLogFile.Sample(
                    t: max(0, sample.timestamp - start), x: point.x, y: point.y, phase: phase
                ))
            }
            if phase == "ended" || phase == "cancelled" {
                ids[key] = nil
            }
        }
    }

    private func save() {
        guard let start, let scene else { return }
        self.start = nil
        let bounds = scene.screen.bounds
        let file = TouchLogFile(
            screen: .init(width: bounds.width, height: bounds.height, scale: scene.screen.scale),
            duration: ProcessInfo.processInfo.systemUptime - start,
            touches: touches.keys.sorted().map { TouchLogFile.Touch(id: $0, samples: touches[$0]!) }
        )
        touches.removeAll()
        let target = destination ?? Self.defaultDestination()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(file)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            onEvent?(.saved(target))
        } catch {
            onEvent?(.saveFailed(error))
        }
    }

    private func watch(
        _ name: Notification.Name,
        object: UIScene?,
        perform action: @escaping @MainActor (SceneTouchLogger) -> Void
    ) {
        let notifications = NotificationCenter.default.notifications(named: name, object: object)
        lifecycle.append(Task { [weak self] in
            for await _ in notifications.map({ _ in () }) {
                guard let self else { return }
                action(self)
            }
        })
    }

    private static func defaultDestination() -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return URL.documentsDirectory
            .appending(path: "SmudgeKit Recordings", directoryHint: .isDirectory)
            .appending(path: "\(formatter.string(from: .now)).touches.json")
    }
}

private struct WeakLogWindow {
    weak var window: UIWindow?
    init(_ window: UIWindow) { self.window = window }
}
#endif
