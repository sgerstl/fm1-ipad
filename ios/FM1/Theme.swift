import SwiftUI

/// Mirrors tokens/tokens.json (v2: the flat look). Change both together.
enum Theme {
    static let page = Color(hex: 0x0D0D0F)
    static let well = Color(hex: 0x111114)
    static let stepEmpty = Color(hex: 0x2A2A30)
    static let stepOutside = Color(hex: 0x18181C)
    static let ledOff = Color(hex: 0x45454D)

    // flat (v2): one solid colour per surface; elevation is a lighter surface (2026-11-05)
    static let panel = Color(hex: 0x1A1A1E)              // elevation 1
    static let control = Color(hex: 0x26262B)            // a chiclet's top, at rest
    static let controlPressed = Color(hex: 0x141417)     // darker while pressed, never lifted
    static let chicletEdge = Color(hex: 0x0A0A0C)        // the 2 pt base edge it stands on
    static let primaryEdge = Color(hex: 0x8A8A92)        // the primary chiclet's edge (its top is `text`)
    static let disabledOutline = Color(hex: 0x4A4A52)
    /// The tone ladder lifted and held things step along: lifted to [2], held at [3].
    static let tones = [0x26262B, 0x2D2D33, 0x34343B, 0x3E3E46, 0x48484F].map { Color(hex: $0) }
    /// Arrange's blocks on Skiff: greys, told apart by the pattern number on them (canvas board A).
    static let blockTones = [0x2E2E35, 0x3A3A42, 0x46464F, 0x52525C].map { Color(hex: $0) }

    static let text = Color(hex: 0xEDEDF0)
    static let textSecondary = Color(hex: 0xA1A1AA)
    /// secondary text on a raised (held) surface, such as the sound panel: textSecondary there is only 4.1:1 (6.1:1 here)
    static let textSecondaryRaised = Color(hex: 0xC4C4CC)
    static let textTertiary = Color(hex: 0x71717A)
    static let onColour = Color(hex: 0x101012)

    // the connected firmware's track colours, from its driver (TrackColours)
    static var track: [Color] { TrackColours.base }
    static var trackTop: [Color] { TrackColours.top }
    // recording: the one red in the top bar (the REC key, the transport's well, its REC readout)
    static let rec = Color(hex: 0xFF2C34)
    static let recWell = Color(hex: 0x3A1214)
    static let recText = Color(hex: 0xFF8A8D)
    /// Running low (the motion records nearly used): amber, never the accent or REC's red.
    static let caution = Color(hex: 0xFFB54A)
    static let knob = [Color(hex: 0x287CFF), Color(hex: 0x1ECC70), Color(hex: 0xFFC618), Color(hex: 0xFF2C34)]

    static let canvas = CGSize(width: 1376, height: 1032)    // 13-inch iPad Air, landscape

    /// A pad's fill: one flat colour.
    static func pad(_ t: Int) -> Color { track[t] }
}

// MARK: - The look (2026-11-05)
//
// The flat look (vault skiff-arrange-spec.md): colour wherever it tells you something (track colours,
// knob rings, REC, status), buttons and keys as chiclets, elevation (a lighter surface, a soft shadow, a
// ring) as the sign of selection. Elevation is locked at the medium strength (Scott, 2026-11-05). The
// physical look it was tried against was removed on 2026-11-06 (Scott chose flat).

/// How high a thing stands. Level 0 (flat, at rest) has no case: it's every surface without one.
enum Elevation {
    case panel          // 1: containers that group (the inspector, side bins, sheets)
    case selected       // 2: the selected thing, always with a 2 pt ring
    case held           // 3: a dragged thing, menus and popovers at the finger
}

/// The elevation levels' surfaces and shadows.
struct Look: Equatable {
    func surface(_ level: Elevation) -> Color {
        switch level {
        case .panel: Theme.panel
        case .selected: Theme.tones[2]
        case .held: Theme.tones[3]
        }
    }

    /// (opacity, radius, y): the spec's CSS blur halved, as SwiftUI's radius is about half a CSS blur.
    func shadow(_ level: Elevation) -> (opacity: Double, radius: CGFloat, y: CGFloat) {
        let base: (Double, CGFloat, CGFloat) = switch level {
        case .panel: (0.35, 8, 6)
        case .selected: (0.45, 6, 4)
        case .held: (0.60, 14, 12)
        }
        return base
    }
}

extension EnvironmentValues {
    /// Set by PressSink on its label: a chiclet under the finger drops onto its edge.
    @Entry var keyPressed = false
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

// MARK: - Surfaces and keys
//
// Drawn with gradients and offset shapes only: no blur, no mask, almost no shadow. Each of those makes
// the GPU draw off screen, and with one per key the panels slid at a low frame rate (2026-11-02). A
// chiclet's edge is an offset shape, and only the few elevated things
// (panels, the selected thing, menus) carry a soft shadow. Steps, cells and keys never do.

/// A panel: elevation 1, one solid surface and its shadow.
struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: 14).fill(Theme.panel).elevationShadow(.panel, Look())
        }
    }
}

/// A well, for things that show you something: a darker fill, nothing more.
struct Recessed: ViewModifier {
    var radius: CGFloat = 8
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius).fill(Theme.well)
        }
    }
}

/// A key: for things you can press. A chiclet, a flat top standing on a hard 2 pt edge; pressed, the
/// top drops onto the edge (PressSink moves it) and darkens. Disabled: no edge and no top, a thin
/// outline. `primary`: the one primary action in a view, the top in the text colour (put dark text on it).
struct RaisedKey: ViewModifier {
    var radius: CGFloat = 9
    var primary = false
    @Environment(\.keyPressed) private var pressed
    @Environment(\.isEnabled) private var enabled
    func body(content: Content) -> some View {
        content.background {
            Chiclet(radius: radius, primary: primary, down: pressed, edge: !pressed, enabled: enabled)
        }
    }
}

/// A flat key's shape. Square-ish: the flat look's corners stop at 8 pt.
struct Chiclet: View {
    var radius: CGFloat = 8
    var primary = false
    var down = false            // pressed, or latched on: darker when pressed, and no edge showing
    var edge = true
    var enabled = true
    var top: Color?
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(radius, 8))
        if !enabled {
            shape.strokeBorder(Theme.disabledOutline, lineWidth: 1)
        } else {
            shape.fill(down ? (primary ? Theme.text.opacity(0.8) : Theme.controlPressed) : top ?? (primary ? Theme.text : Theme.control))
                .background { if edge { shape.fill(primary ? Theme.primaryEdge : Theme.chicletEdge).offset(y: 2) } }
        }
    }
}

/// A key that stays down when on (a latching toggle): a standing chiclet when off; on, its top sits on
/// its edge (PressSink(latched:) moves it down), so down means on, as on a latching key. Pair it with a
/// lit LED or a label change, so on isn't told by position alone.
struct LatchedKey: ViewModifier {
    var on: Bool
    var radius: CGFloat = 9
    @Environment(\.keyPressed) private var pressed
    @Environment(\.isEnabled) private var enabled
    func body(content: Content) -> some View {
        if on {
            content.background { Chiclet(radius: radius, down: pressed, edge: false, enabled: enabled, top: Theme.control) }
        } else {
            content.modifier(RaisedKey(radius: radius))
        }
    }
}

/// The current one of several (the active tab): elevation 2, lifted with a soft shadow and a 2 pt ring,
/// so it reads as chosen rather than merely pressable.
struct SelectedKey: ViewModifier {
    var radius: CGFloat = 9
    func body(content: Content) -> some View {
        content.elevated(.selected, radius: radius)
    }
}

/// Elevation 1–3: the level's surface, its soft shadow, and a ring on a selected thing.
struct Elevated: ViewModifier {
    var level: Elevation
    var radius: CGFloat = 14
    var ring: Bool? = nil                       // nil: a ring on .selected only
    func body(content: Content) -> some View {
        let look = Look()
        content.background {
            RoundedRectangle(cornerRadius: radius).fill(look.surface(level))
                .overlay { if ring ?? (level == .selected) { RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.text, lineWidth: 2) } }
                .elevationShadow(level, look)
        }
    }
}

extension View {
    func panel() -> some View { modifier(PanelBackground()) }
    func recessed(_ radius: CGFloat = 8) -> some View { modifier(Recessed(radius: radius)) }
    func raisedKey(_ radius: CGFloat = 9, primary: Bool = false) -> some View { modifier(RaisedKey(radius: radius, primary: primary)) }
    func latchedKey(_ on: Bool, _ radius: CGFloat = 9) -> some View {
        modifier(LatchedKey(on: on, radius: radius))
    }
    func selectedKey(_ radius: CGFloat = 9) -> some View { modifier(SelectedKey(radius: radius)) }
    func elevated(_ level: Elevation, radius: CGFloat = 14, ring: Bool? = nil) -> some View {
        modifier(Elevated(level: level, radius: radius, ring: ring))
    }
    /// A level's soft shadow. Only for the few elevated things.
    func elevationShadow(_ level: Elevation, _ look: Look) -> some View {
        let s = look.shadow(level)
        return shadow(color: .black.opacity(s.opacity), radius: s.radius, y: s.y)
    }
}

/// A small light, like a button LED: lit means on. A flat dot, no glow.
struct LED: View {
    var on: Bool
    var colour: Color = Theme.text
    var body: some View {
        Circle().fill(on ? colour : Theme.ledOff)
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }
}
