import UIKit

/// Shows touches in a window scene, for screen recordings and App Store previews.
///
/// ```swift
/// let smudges = TouchSmudges.show(in: windowScene)
/// // …
/// smudges.stop()
/// ```
///
/// In SwiftUI, use the `showsTouches(_:style:)` modifier instead. Several handles can show
/// touches in the same scene; they share one overlay, and the most recent style and placement win.
@MainActor
public final class TouchSmudges {
    public private(set) weak var scene: UIWindowScene?
    private var smudger: SceneSmudger?

    /// The look of touches that begin from now on.
    public var style: SmudgeStyle {
        didSet { smudger?.style = style }
    }

    /// Where touches are drawn. Changing it removes the smudges on screen.
    public var placement: SmudgePlacement {
        didSet { smudger?.placement = placement }
    }

    /// False once stopped, or once the scene has disconnected.
    public var isActive: Bool {
        guard let smudger else { return false }
        return !smudger.isTornDown
    }

    private init(scene: UIWindowScene, style: SmudgeStyle, placement: SmudgePlacement) {
        self.scene = scene
        self.style = style
        self.placement = placement
        self.smudger = SceneSmudger.acquire(for: scene, style: style, placement: placement)
    }

    /// Starts drawing touches in every window of `scene`.
    public static func show(
        in scene: UIWindowScene,
        style: SmudgeStyle = .soft,
        placement: SmudgePlacement = .overlayWindow
    ) -> TouchSmudges {
        TouchSmudges(scene: scene, style: style, placement: placement)
    }

    /// Stops drawing touches. The overlay goes away when the last handle for the scene stops.
    public func stop() {
        smudger?.release()
        smudger = nil
    }
}
