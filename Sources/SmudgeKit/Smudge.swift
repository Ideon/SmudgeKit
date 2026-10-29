import UIKit

/// One drawn touch: a dot that follows the finger and flies off when it lifts.
@MainActor
final class Smudge {
    let layer = CALayer()
    private let style: SmudgeStyle

    private static let easeOut = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1)

    init(style: SmudgeStyle, traits: UITraitCollection) {
        self.style = style
        let scale = traits.displayScale > 0 ? traits.displayScale : 2
        let bounds = CGRect(x: 0, y: 0, width: style.diameter, height: style.diameter)
        let softness = min(max(style.softness, 0), 1)
        let color = style.color.resolvedColor(with: traits).cgColor

        layer.bounds = bounds
        layer.opacity = style.opacity

        if softness < 0.05 {
            let disc = CAShapeLayer()
            disc.frame = bounds
            disc.contentsScale = scale
            disc.path = CGPath(ellipseIn: bounds, transform: nil)
            disc.fillColor = color
            layer.addSublayer(disc)
        } else {
            let glow = CAGradientLayer()
            glow.frame = bounds
            glow.contentsScale = scale
            glow.type = .radial
            glow.colors = [color, color, color.copy(alpha: 0) ?? UIColor.clear.cgColor]
            glow.locations = [0, NSNumber(value: Double(1 - softness)), 1]
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
            layer.addSublayer(glow)
        }

        if style.rimWidth > 0 {
            // Sit the rim where the soft edge is about half faded, not around the outer glow.
            let inset = style.diameter / 2 * softness / 2 + style.rimWidth / 2
            let rim = CAShapeLayer()
            rim.frame = bounds
            rim.contentsScale = scale
            rim.path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
            rim.fillColor = nil
            rim.strokeColor = style.rimColor.resolvedColor(with: traits).cgColor
            rim.lineWidth = style.rimWidth
            layer.addSublayer(rim)
        }

        if style.shadowOpacity > 0 {
            layer.shadowPath = CGPath(ellipseIn: bounds, transform: nil)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = style.shadowOpacity
            layer.shadowRadius = style.shadowRadius
            layer.shadowOffset = CGSize(width: 0, height: 1)
        }
    }

    func appear(at point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = point
        CATransaction.commit()

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = style.opacity
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = style.appearScale
        grow.toValue = 1
        let group = CAAnimationGroup()
        group.animations = [fade, grow]
        group.duration = style.appearDuration
        group.timingFunction = Self.easeOut
        layer.add(group, forKey: "appear")
    }

    func move(to point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = point
        CATransaction.commit()
    }

    /// Fades the dot out while it keeps travelling along `velocity` (points per second), then
    /// removes it.
    func lift(at point: CGPoint, velocity: CGVector) {
        var offset = CGVector(dx: velocity.dx * style.drift, dy: velocity.dy * style.drift)
        let length = hypot(offset.dx, offset.dy)
        if length > style.maxDrift {
            offset.dx *= style.maxDrift / length
            offset.dy *= style.maxDrift / length
        }
        let target = CGPoint(x: point.x + offset.dx, y: point.y + offset.dy)

        // Start from what is on screen, in case the appear animation hasn't finished.
        let current = layer.presentation()
        let fromOpacity = current?.opacity ?? layer.opacity
        let fromScale = (current?.value(forKeyPath: "transform.scale") as? CGFloat) ?? 1

        let move = CABasicAnimation(keyPath: "position")
        move.fromValue = NSValue(cgPoint: point)
        move.toValue = NSValue(cgPoint: target)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = fromOpacity
        fade.toValue = 0
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = fromScale
        grow.toValue = style.liftScale
        let group = CAAnimationGroup()
        group.animations = [move, fade, grow]
        group.duration = style.liftDuration
        group.timingFunction = Self.easeOut

        let layer = self.layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock {
            layer.removeFromSuperlayer()
        }
        layer.removeAnimation(forKey: "appear")
        layer.position = target
        layer.opacity = 0
        layer.transform = CATransform3DMakeScale(style.liftScale, style.liftScale, 1)
        layer.add(group, forKey: "lift")
        CATransaction.commit()
    }

    /// Removes the dot at once, without animating.
    func remove() {
        layer.removeAllAnimations()
        layer.removeFromSuperlayer()
    }
}
