import UIKit

/// A transparent window above the app's own windows that smudges are drawn in. It never takes
/// touches or key status, and has no root view controller, so it doesn't affect the status bar
/// or supported orientations.
@MainActor
final class OverlayWindow: UIWindow {
    let container = CALayer()

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = .alert + 1
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        layer.addSublayer(container)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.frame = bounds
        CATransaction.commit()
    }
}
