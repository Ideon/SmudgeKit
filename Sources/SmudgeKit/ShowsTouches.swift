import SwiftUI

extension View {
    /// Draws every touch in this view's window scene, including touches in its other windows,
    /// sheets and alerts. Meant for screen recordings and App Store previews; gate it behind a
    /// debug flag in shipping apps.
    ///
    /// Apply it once near the root of each scene, for example on the `WindowGroup` content.
    public func showsTouches(_ isEnabled: Bool = true, style: SmudgeStyle = .soft) -> some View {
        background(SmudgeAnchor(isEnabled: isEnabled, style: style))
    }
}

/// An invisible view whose only job is to find out which scene it is in.
private struct SmudgeAnchor: UIViewRepresentable {
    var isEnabled: Bool
    var style: SmudgeStyle

    func makeUIView(context: Context) -> AnchorView {
        AnchorView()
    }

    func updateUIView(_ view: AnchorView, context: Context) {
        view.style = style
        view.isShowingTouches = isEnabled
    }

    static func dismantleUIView(_ view: AnchorView, coordinator: ()) {
        view.isShowingTouches = false
    }
}

private final class AnchorView: UIView {
    private var smudges: TouchSmudges?

    var isShowingTouches = false {
        didSet { refresh() }
    }

    var style = SmudgeStyle.soft {
        didSet {
            if style != oldValue {
                smudges?.style = style
            }
        }
    }

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
        let scene = isShowingTouches ? window?.windowScene : nil
        if let smudges, smudges.isActive, smudges.scene === scene {
            return
        }
        smudges?.stop()
        smudges = scene.map { TouchSmudges.show(in: $0, style: style) }
    }
}
