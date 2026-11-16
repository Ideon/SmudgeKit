import ReplayKit
import SwiftUI

/// What happened to a take recorded by `recordsScreen(_:saveTo:onEvent:)`.
public enum ScreenRecordingEvent: Sendable {
    case started
    case startFailed(any Error)
    case saved(URL)
    case saveFailed(any Error)
}

extension View {
    /// Records the app with ReplayKit's in-app recording, one take each time the scene comes to
    /// the foreground. The take is saved when the scene goes to the background, so pressing Home
    /// ends it. Meant for screen recordings and App Store previews; gate it behind a debug flag in
    /// shipping apps.
    ///
    /// ReplayKit records the app at its own frame rate, without the Control Center pull-down at
    /// either end. It captures only the app's windows, so pair it with
    /// `showsTouches(_:style:placement:)` using `placement: .hostWindow`. iOS asks the person to
    /// allow recording before a take starts.
    ///
    /// - Parameters:
    ///   - destination: Where each take is saved, replacing any file there. When nil, each take
    ///     gets its own file in `Documents/SmudgeKit Recordings`, named by the time it was saved.
    ///   - onEvent: Called on the main actor when a take starts or is saved, or either fails.
    public func recordsScreen(
        _ isEnabled: Bool = true,
        saveTo destination: URL? = nil,
        onEvent: (@MainActor @Sendable (ScreenRecordingEvent) -> Void)? = nil
    ) -> some View {
        modifier(ScreenRecordingModifier(isEnabled: isEnabled, destination: destination, onEvent: onEvent))
    }

    /// Hides the status bar, and with it the clock and the screen recording indicator, for screen
    /// recordings. Separate from recording, so it works with Control Center's screen recording too.
    public func hidesStatusBarForRecording(_ isHidden: Bool = true) -> some View {
        statusBarHidden(isHidden)
    }
}

private struct ScreenRecordingModifier: ViewModifier {
    var isEnabled: Bool
    var destination: URL?
    var onEvent: (@MainActor @Sendable (ScreenRecordingEvent) -> Void)?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard isEnabled else { return }
                switch phase {
                case .active:
                    ScreenRecorder.shared.start(onEvent: onEvent)
                case .background:
                    ScreenRecorder.shared.save(to: destination, onEvent: onEvent)
                default:
                    break
                }
            }
            .onChange(of: isEnabled) { _, isEnabled in
                if isEnabled, scenePhase == .active {
                    ScreenRecorder.shared.start(onEvent: onEvent)
                } else if !isEnabled {
                    ScreenRecorder.shared.save(to: destination, onEvent: onEvent)
                }
            }
    }
}

/// The app's one ReplayKit recorder, shared by every scene that records.
@MainActor
final class ScreenRecorder {
    static let shared = ScreenRecorder()

    private var isStarting = false
    /// A save asked for while the take was still starting, done once it has.
    private var pendingSave: (destination: URL?, onEvent: (@MainActor @Sendable (ScreenRecordingEvent) -> Void)?)?

    func start(onEvent: (@MainActor @Sendable (ScreenRecordingEvent) -> Void)?) {
        let recorder = RPScreenRecorder.shared()
        pendingSave = nil
        guard !isStarting, !recorder.isRecording else { return }
        isStarting = true
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { error in
            Task { @MainActor in
                let recorder = ScreenRecorder.shared
                recorder.isStarting = false
                onEvent?(error.map { .startFailed($0) } ?? .started)
                if let pending = recorder.pendingSave {
                    recorder.pendingSave = nil
                    recorder.save(to: pending.destination, onEvent: pending.onEvent)
                }
            }
        }
    }

    func save(to destination: URL?, onEvent: (@MainActor @Sendable (ScreenRecordingEvent) -> Void)?) {
        if isStarting {
            pendingSave = (destination, onEvent)
            return
        }
        let recorder = RPScreenRecorder.shared()
        guard recorder.isRecording else { return }
        // ReplayKit writes only to a new file in the temporary directory; the take is moved after.
        let temporary = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
        let target = destination ?? Self.defaultDestination()
        let task = UIApplication.shared.beginBackgroundTask()
        recorder.stopRecording(withOutput: temporary) { error in
            Task { @MainActor in
                defer { UIApplication.shared.endBackgroundTask(task) }
                if let error {
                    onEvent?(.saveFailed(error))
                    return
                }
                do {
                    let files = FileManager.default
                    try files.createDirectory(at: target.deletingLastPathComponent(),
                                              withIntermediateDirectories: true)
                    try? files.removeItem(at: target)
                    try files.moveItem(at: temporary, to: target)
                    onEvent?(.saved(target))
                } catch {
                    onEvent?(.saveFailed(error))
                }
            }
        }
    }

    private static func defaultDestination() -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return URL.documentsDirectory
            .appending(path: "SmudgeKit Recordings", directoryHint: .isDirectory)
            .appending(path: "\(formatter.string(from: .now)).mp4")
    }
}
