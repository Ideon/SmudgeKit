import SwiftUI

/// Sliders for every part of a `SmudgeStyle`, over a few backgrounds to try it on, with the
/// resulting style as code to paste back. A tool for finding a look, not for shipping.
public struct SmudgeTuner: View {
    @Binding private var style: SmudgeStyle
    @State private var backdrop = Backdrop.space

    public init(style: Binding<SmudgeStyle>) {
        _style = style
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                backdrop.view
                Text("Drag, tap and flick here")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(backdrop.isDark ? .white.opacity(0.6) : .black.opacity(0.5))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())

            Form {
                Section {
                    Picker("Backdrop", selection: $backdrop) {
                        ForEach(Backdrop.allCases, id: \.self) { Text($0.title) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Preset")
                        Spacer()
                        Button("Soft") { style = .soft }
                        Button("Glow") { style = .glow }
                        Button("Classic") { style = .classic }
                    }
                    .buttonStyle(.bordered)
                }
                Section("Dot") {
                    slider("Diameter", $style.diameter, 16...96)
                    slider("Opacity", floatBinding(\.opacity), 0.05...1)
                    slider("Softness", $style.softness, 0...1)
                    ColorPicker("Colour", selection: colorBinding(\.color))
                    slider("Rim width", $style.rimWidth, 0...4)
                    ColorPicker("Rim colour", selection: colorBinding(\.rimColor))
                    slider("Shadow", floatBinding(\.shadowOpacity), 0...0.6)
                }
                Section("Motion") {
                    slider("Appear scale", $style.appearScale, 0.2...2)
                    slider("Appear time", timeBinding(\.appearDuration), 0...0.5)
                    slider("Lift scale", $style.liftScale, 0.5...2.5)
                    slider("Lift time", timeBinding(\.liftDuration), 0.05...1.2)
                    slider("Drift", timeBinding(\.drift), 0...0.4)
                    slider("Max drift", $style.maxDrift, 0...400)
                }
                Section("Code") {
                    Text(style.swiftLiteral)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button("Copy") { UIPasteboard.general.string = style.swiftLiteral }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func slider(_ title: String, _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func floatBinding(_ keyPath: WritableKeyPath<SmudgeStyle, Float>) -> Binding<CGFloat> {
        Binding(get: { CGFloat(style[keyPath: keyPath]) }, set: { style[keyPath: keyPath] = Float($0) })
    }

    private func timeBinding(_ keyPath: WritableKeyPath<SmudgeStyle, TimeInterval>) -> Binding<CGFloat> {
        Binding(get: { CGFloat(style[keyPath: keyPath]) }, set: { style[keyPath: keyPath] = TimeInterval($0) })
    }

    private func colorBinding(_ keyPath: WritableKeyPath<SmudgeStyle, UIColor>) -> Binding<Color> {
        Binding(get: { Color(uiColor: style[keyPath: keyPath]) }, set: { style[keyPath: keyPath] = UIColor($0) })
    }

    private enum Backdrop: CaseIterable {
        case space, light, busy

        var title: String {
            switch self {
            case .space: "Dark"
            case .light: "Light"
            case .busy: "Busy"
            }
        }

        var isDark: Bool { self != .light }

        @ViewBuilder var view: some View {
            switch self {
            case .space:
                RadialGradient(
                    colors: [Color(red: 0.08, green: 0.12, blue: 0.25), .black],
                    center: .center, startRadius: 0, endRadius: 400
                )
            case .light:
                Color(white: 0.96)
            case .busy:
                LinearGradient(
                    colors: [.blue, .teal, .green, .yellow, .orange],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
    }
}

extension SmudgeStyle {
    /// The style as a Swift initializer, to paste into code once it looks right.
    var swiftLiteral: String {
        func number(_ value: some BinaryFloatingPoint) -> String {
            let rounded = (Double(value) * 1000).rounded() / 1000
            return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        }
        func color(_ color: UIColor) -> String {
            var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            if r == g && g == b {
                return "UIColor(white: \(number(r)), alpha: \(number(a)))"
            }
            return "UIColor(red: \(number(r)), green: \(number(g)), blue: \(number(b)), alpha: \(number(a)))"
        }
        let maxDrift = self.maxDrift == .greatestFiniteMagnitude ? ".greatestFiniteMagnitude" : number(self.maxDrift)
        return """
        SmudgeStyle(
            diameter: \(number(diameter)),
            color: \(color(self.color)),
            opacity: \(number(opacity)),
            softness: \(number(softness)),
            rimColor: \(color(rimColor)),
            rimWidth: \(number(rimWidth)),
            shadowOpacity: \(number(shadowOpacity)),
            shadowRadius: \(number(shadowRadius)),
            appearScale: \(number(appearScale)),
            appearDuration: \(number(appearDuration)),
            liftScale: \(number(liftScale)),
            liftDuration: \(number(liftDuration)),
            drift: \(number(drift)),
            maxDrift: \(maxDrift)
        )
        """
    }
}

#Preview("Tune the look") {
    @Previewable @State var style = SmudgeStyle.soft
    SmudgeTuner(style: $style)
        .showsTouches(style: style)
}
