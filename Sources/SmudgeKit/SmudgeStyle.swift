import UIKit

/// How a touch is drawn: its size and colour, how it appears, and how it flies off when the
/// finger lifts.
public struct SmudgeStyle: Equatable, Sendable {
    /// Diameter of the dot in points.
    public var diameter: CGFloat
    /// Fill colour. Its alpha multiplies `opacity`.
    public var color: UIColor
    /// Overall opacity of the dot while the finger is down.
    public var opacity: Float
    /// How much of the radius fades out at the edge, from 0 (a hard disc) to 1 (a soft glow).
    public var softness: CGFloat
    /// A thin rim that keeps the dot visible on backgrounds close to its own colour.
    public var rimColor: UIColor
    public var rimWidth: CGFloat
    /// An optional drop shadow, mostly for the classic look.
    public var shadowOpacity: Float
    public var shadowRadius: CGFloat

    /// Scale the dot grows from when a touch begins.
    public var appearScale: CGFloat
    public var appearDuration: TimeInterval

    /// Scale the dot grows to while it fades out after the finger lifts.
    public var liftScale: CGFloat
    public var liftDuration: TimeInterval
    /// How far a lifted dot keeps travelling, as seconds of the finger's last velocity.
    public var drift: TimeInterval
    /// Upper bound for the drift distance in points, so fast flicks don't throw dots off screen.
    public var maxDrift: CGFloat

    public init(
        diameter: CGFloat = 44,
        color: UIColor = .white,
        opacity: Float = 0.55,
        softness: CGFloat = 0.45,
        rimColor: UIColor = UIColor(white: 0, alpha: 0.18),
        rimWidth: CGFloat = 0.75,
        shadowOpacity: Float = 0,
        shadowRadius: CGFloat = 0,
        appearScale: CGFloat = 0.6,
        appearDuration: TimeInterval = 0.12,
        liftScale: CGFloat = 1.3,
        liftDuration: TimeInterval = 0.38,
        drift: TimeInterval = 0.1,
        maxDrift: CGFloat = 120
    ) {
        self.diameter = diameter
        self.color = color
        self.opacity = opacity
        self.softness = softness
        self.rimColor = rimColor
        self.rimWidth = rimWidth
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.appearScale = appearScale
        self.appearDuration = appearDuration
        self.liftScale = liftScale
        self.liftDuration = liftDuration
        self.drift = drift
        self.maxDrift = maxDrift
    }
}

extension SmudgeStyle {
    /// A soft translucent dot with a faint rim. The default.
    public static let soft = SmudgeStyle()

    /// A softer, larger glow without a rim, for dark content.
    public static let glow = SmudgeStyle(
        diameter: 56,
        opacity: 0.45,
        softness: 0.85,
        rimColor: .clear,
        rimWidth: 0,
        appearScale: 0.5,
        liftScale: 1.5,
        liftDuration: 0.45
    )

    /// The 2014 SmudgeKit look: an opaque light disc with a dark outline and drop shadow.
    public static let classic = SmudgeStyle(
        diameter: 40,
        color: UIColor(white: 0.9, alpha: 1),
        opacity: 0.9,
        softness: 0,
        rimColor: UIColor(white: 0, alpha: 0.35),
        rimWidth: 1,
        shadowOpacity: 0.15,
        shadowRadius: 3,
        appearScale: 1.5,
        appearDuration: 0.1,
        liftScale: 1.5,
        liftDuration: 0.2,
        drift: 0.067,
        maxDrift: .greatestFiniteMagnitude
    )
}
