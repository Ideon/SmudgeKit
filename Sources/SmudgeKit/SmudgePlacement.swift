/// Where smudges are drawn.
public enum SmudgePlacement: Equatable, Sendable {
    /// In a pass-through window above the app's windows, so touches show over sheets, alerts and
    /// any other window in the scene. The default.
    case overlayWindow

    /// In a layer on top of the window each touch lands in. Use this when a recorder only
    /// captures the app's own windows, as ReplayKit's in-app recording does on some devices.
    /// The layer is raised back to the top whenever something else is added above it.
    case hostWindow
}
