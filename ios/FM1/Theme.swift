import SwiftUI

/// Mirrors tokens/tokens.json (v1). Change both together.
enum Theme {
    static let page = Color(hex: 0x0D0D0F)
    static let panelTop = Color(hex: 0x212126)
    static let panelBottom = Color(hex: 0x1A1A1E)
    static let well = Color(hex: 0x111114)
    static let raisedTop = Color(hex: 0x3A3A42)
    static let raisedBottom = Color(hex: 0x2D2D33)
    static let stepEmpty = Color(hex: 0x2A2A30)
    static let stepOutside = Color(hex: 0x18181C)
    static let pressed = Color(hex: 0x1E1E23)
    static let ledOff = Color(hex: 0x45454D)

    static let text = Color(hex: 0xEDEDF0)
    static let textSecondary = Color(hex: 0xA1A1AA)
    static let textTertiary = Color(hex: 0x71717A)
    static let onColour = Color(hex: 0x101012)

    static let track = [Color(hex: 0x287CFF), Color(hex: 0x1ECC70), Color(hex: 0xFFC618), Color(hex: 0xFF621A)]
    static let trackTop = [Color(hex: 0x4A93FF), Color(hex: 0x4ADB8C), Color(hex: 0xFFD54D), Color(hex: 0xFF8247)]
    static let knob = [Color(hex: 0x287CFF), Color(hex: 0x1ECC70), Color(hex: 0xFFC618), Color(hex: 0xFF2C34)]

    static let stepWidth: CGFloat = 38
    static let rowHeight: CGFloat = 46
    static let canvas = CGSize(width: 1376, height: 1032)    // 13-inch iPad Air, landscape

    static func pad(_ t: Int) -> LinearGradient {
        LinearGradient(colors: [trackTop[t], track[t]], startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - The physical look: raised to press, recessed to read

/// A panel: a lighter surface with a faint top highlight and a soft drop shadow, no outline.
struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Theme.panelTop, Theme.panelBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 1).mask(
                            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                    }
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
            )
    }
}

/// A well: set into the panel, with an inner shadow. For things that show you something.
struct Recessed: ViewModifier {
    var radius: CGFloat = 8
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius)
                .fill(Theme.well)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(.black.opacity(0.7), lineWidth: 3).blur(radius: 3).offset(y: 2)
                        .mask(RoundedRectangle(cornerRadius: radius))
                )
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.05), lineWidth: 1)
                        .mask(LinearGradient(colors: [.clear, .white], startPoint: .center, endPoint: .bottom))
                }
        )
    }
}

/// A raised key: for things you can press.
struct RaisedKey: ViewModifier {
    var radius: CGFloat = 9
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [Theme.raisedTop, Theme.raisedBottom], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: radius).inset(by: 0.5).stroke(.white.opacity(0.09), lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
        )
    }
}

extension View {
    func panel() -> some View { modifier(PanelBackground()) }
    func recessed(_ radius: CGFloat = 8) -> some View { modifier(Recessed(radius: radius)) }
    func raisedKey(_ radius: CGFloat = 9) -> some View { modifier(RaisedKey(radius: radius)) }
}

/// A small light, like a button LED: lit means on.
struct LED: View {
    var on: Bool
    var colour: Color = Theme.text
    var body: some View {
        Circle().fill(on ? colour : Theme.ledOff)
            .frame(width: 6, height: 6)
            .shadow(color: on ? colour.opacity(0.8) : .clear, radius: 3)
            .accessibilityHidden(true)
    }
}
