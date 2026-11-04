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

    // the connected firmware's track colours, from its driver (TrackColours)
    static var track: [Color] { TrackColours.base }
    static var trackTop: [Color] { TrackColours.top }
    // recording: the one red in the top bar (the REC key, the transport's well, its REC readout)
    static let rec = Color(hex: 0xFF2C34)
    static let recWell = Color(hex: 0x3A1214)
    static let recText = Color(hex: 0xFF8A8D)
    static let knob = [Color(hex: 0x287CFF), Color(hex: 0x1ECC70), Color(hex: 0xFFC618), Color(hex: 0xFF2C34)]

    static let canvas = CGSize(width: 1376, height: 1032)    // 13-inch iPad Air, landscape

    static func pad(_ t: Int) -> LinearGradient {
        LinearGradient(colors: [trackTop[t], track[t]], startPoint: .top, endPoint: .bottom)
    }
}

/// The grids' sizes, handed down through the environment so one grid view draws at the iPad's size or
/// the phone's (2026-11-04). The iPad's are the defaults: views outside a phone layout see no change.
struct GridMetrics: Equatable {
    var stepWidth: CGFloat = 55                 // one bar (16 steps) fills the grid (2026-11-02)
    var rowHeight: CGFloat = 46
    var labelWidth: CGFloat = 80                // the note names or drum lanes left of the grid
    var gridHeight: CGFloat = 534               // the piano roll's visible height (its content is never shorter)
    var barWidth: CGFloat { 16 * stepWidth }
    var drumContentSize: CGSize { CGSize(width: 64 * stepWidth, height: 16 * rowHeight) }

    static let pad = GridMetrics()
    static let phone = GridMetrics(stepWidth: 42, rowHeight: 46, labelWidth: 44)   // a whole bar across a landscape iPhone; PhoneSequence fits the step to the screen
}

extension EnvironmentValues {
    @Entry var grid: GridMetrics = .pad
    /// The space a held knob's ring is kept inside: the iPad's canvas, or the phone's screen (2026-11-04).
    @Entry var canvasSize: CGSize = Theme.canvas
}

/// A canvas as wide as the whole pattern (64 steps): one piece when it fits a GPU texture, else one
/// piece per bar. On a 3x iPhone at 43 pt a step the pattern is 8,256 px wide, past the 8,192 px limit,
/// and the whole canvas came out blank (2026-11-04). The iPad (7,040 px) keeps its single canvas.
struct WideCanvas: View {
    let width: CGFloat
    let height: CGFloat
    let barWidth: CGFloat
    let draw: (GraphicsContext, CGSize) -> Void
    @Environment(\.displayScale) private var scale

    var body: some View {
        if width * scale <= 8000 || barWidth <= 0 {
            Canvas { ctx, size in draw(ctx, size) }
                .frame(width: width, height: height)
        } else {
            HStack(spacing: 0) {
                ForEach(0..<Int((width / barWidth).rounded(.up)), id: \.self) { b in
                    Canvas { ctx, size in
                        var c = ctx
                        c.translateBy(x: -CGFloat(b) * barWidth, y: 0)
                        draw(c, CGSize(width: width, height: size.height))
                    }
                    .frame(width: barWidth, height: height)
                }
            }
            .frame(width: width, height: height)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - The physical look: raised to press, recessed to read
//
// Drawn with gradients and offset shapes only: no blur, no mask, almost no shadow. Each of those makes
// the GPU draw off screen, and with one per key the panels slid at a low frame rate (2026-11-02).

/// A panel: a lighter surface with a faint top highlight and a soft drop shadow, no outline.
struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Theme.panelTop, Theme.panelBottom], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.05), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
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
                // the inner shadow: darkest at the top edge, gone by the middle
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.15), .clear],
                                                     startPoint: .top, endPoint: .center), lineWidth: 3)
                )
                // the lip catching light at the bottom
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(LinearGradient(colors: [.clear, .white.opacity(0.05)], startPoint: .center, endPoint: .bottom), lineWidth: 1)
                )
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
                .overlay(RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.09), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
                // its edge on the panel: a dark copy a point lower, in place of a blurred shadow
                .background(RoundedRectangle(cornerRadius: radius).fill(.black.opacity(0.6)).offset(y: 1))
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
