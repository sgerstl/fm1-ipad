import SloopKit
import SwiftUI

// The phone's sound panel (vault decisions 25, 27, 30, 32, 35; board 75 B): the iPad's rule on the phone. A sound key
// (the FM-1's, or the rail with Settings › Sound buttons on) slides the panel in from the right, about a third of the
// width, tinted with the track's colour muted (35 % over the page, as Android's: white text 6.7:1 or better on every
// track colour). It shows the page the FM-1 is on: its four dials, with the page's picture under them when Settings ›
// Show graphics is on. It stays until HOME, its close arrow or another tab; the same key again steps its pages. The page
// beside it stays live; on Edit it lies over the grid, which keeps its width and scrolls under it. iPhone only.

struct PhoneSoundHost<Content: View>: View {
    let session: DeviceSession
    let ui: EditorUI
    @ViewBuilder let content: () -> Content
    @AppStorage(SoundButtons.key) private var showRail = SoundButtons.standard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            content()
                // Edit: the grid scrolls on past its width by the panel's, so no step is out of reach under it
                .environment(\.soundPanelRoom, ui.soundPanel != nil && ui.phoneTab == .edit ? PhoneSoundPanel.width : 0)
                .overlay(alignment: .topTrailing) {
                    ZStack(alignment: .topTrailing) {
                        if let s = ui.soundPanel {
                            PhoneSoundPanel(session: session, ui: ui, family: s.family)
                                .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                        }
                    }
                    // flush with the screen's edge when no rail sits beside it (over the page's 8 pt margin)
                    .padding(.trailing, showRail ? 0 : -8)
                    .padding(.bottom, -8)
                    // in 300 ms ease-out, out in 200 ms ease-in (DESIGN.md: exits quicker)
                    .animation(reduceMotion ? .easeOut(duration: 0.15)
                               : ui.soundPanel != nil ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3) : .easeIn(duration: 0.2),
                               value: ui.soundPanel != nil)
                }
            if showRail { SoundRail(session: session, ui: ui) }
        }
        // another track whose engine has none of the open key's pages: closed, never an empty panel
        .onChange(of: session.selectedTrack) { _, _ in
            if let f = ui.soundPanel?.family, SoundPage.shown(session, f).isEmpty { ui.soundPanel = nil }
        }
    }
}

struct PhoneSoundPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    let family: SoundFamily
    @State private var marks = ShapeMarks()
    @AppStorage(ShowGraphics.key) private var graphics = ShowGraphics.standard

    /// About a third of the iPhone's landscape width.
    static let width: CGFloat = 320

    /// Pages SoundCard draws with controls of their own rather than four columns.
    static func dialPage(_ p: SoundPage, _ session: DeviceSession) -> Bool {
        if p.title == "MOD", !p.routes.isEmpty { return false }
        if ["LANES", "LANE MIX"].contains(p.title), !p.picks.isEmpty { return false }
        if session.dialect == .skiff, ["SOUND", "SAMPLES", "OPERATOR", "ALL OPS"].contains(p.title) { return false }
        return true
    }

    /// The knob being turned (here or on the FM-1): its point lights in the picture.
    private func hot(_ p: SoundPage) -> Int? {
        ui.knobGrab.flatMap { g in p.ids.indices.first { p.key($0) == g.id } }
            ?? marks.key.flatMap { m in p.ids.indices.first { p.key($0) == m } }
    }

    /// Knob k of the page as a round dial: the FM-1's slide (Settings › Slide to turn), the Magnifier, double tap back.
    @ViewBuilder private func dial(_ p: SoundPage, _ k: Int) -> some View {
        if let id = p.ids[safe: k] ?? nil {
            let sc = p.scope(of: k)
            let tint = sc == 1 ? Theme.text : Theme.track[session.selectedTrack]
            let isHot = marks.key == p.key(k)
            KnobControl(ui: ui, activate: { activate(p) }, column: (k + 1, tint, isHot),
                        face: { spec, dragging in AnyView(RoundDialFace(spec: spec, tint: tint, hot: isHot || dragging)) }) {
                var s = KnobSpec.param(session, scope: sc, id: id, slot: k, label: p.knobLabels[safe: k] ?? nil)
                if SoundCard.deadWhileStrumOff(session, p, k) { s.dead = true; s.spoken += ", does nothing while STRUM is off" }
                return s
            }
        } else {
            Color.clear.frame(height: RoundDialFace.height).accessibilityHidden(true)
        }
    }

    /// Touching a dial makes its page the FM-1's (linked), as a card's column does.
    private func activate(_ p: SoundPage) -> Bool {
        let on = SoundCard.onDevice(session, p)
        if !on { ui.focus(p); if session.screenLinked, ui.followDevice { session.showOnDevice(page: p.fw) } }
        return !on
    }

    var body: some View {
        let t = session.selectedTrack
        let pages = SoundPage.shown(session, family)
        let current = (session.screenLinked ? pages.first { SoundCard.onDevice(session, $0) } : nil)
            ?? pages.first { $0.id == ui.focusedPage?.id } ?? pages.first
        let n = current.flatMap { c in pages.firstIndex { $0.id == c.id } }.map { $0 + 1 } ?? 0
        VStack(alignment: .leading, spacing: 8) {
            // the dials' header, the only page label (decision 27): family, page n/count, page name; the close arrow
            HStack(spacing: 8) {
                Text(family.rawValue).font(.lupe(17, .semibold)).accessibilityAddTraits(.isHeader)
                if let c = current {
                    Text("\(n)/\(pages.count) \(c.title(session))").font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
                        .lineLimit(1).contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                Button { SoundPanelControl.dismiss(ui, session: session) } label: {
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel("Close the \(family.rawValue) pages")
            }
            .padding(.trailing, -8)
            Group {
                if let c = current {
                    if Self.dialPage(c, session) {
                        // Android's panel (board 75, decisions 25 and 30): four round dials, then the page's picture
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                ForEach(0..<4, id: \.self) { k in dial(c, k).frame(maxWidth: .infinity) }
                            }
                            if graphics, PageGraph.has(c, session) {
                                PageGraph(session: session, page: c, rows: [c], hot: hot(c), modRoute: .constant(0))
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
                            }
                        }
                    } else {
                        // a page whose four pick from lists (MOD's routes, LANES, SOUND, OPERATOR): its own controls
                        ScrollView {
                            SoundCard(session: session, ui: ui, rows: [c], pages: pages, marks: marks)
                                .environment(\.compactColumns, true)
                                .environment(\.pageGraphHidden, !graphics)
                                .environment(\.soundCardBare, true)
                                .environment(\.soundCardHeaderHidden, true)
                        }
                        .scrollIndicators(.hidden)
                    }
                } else {
                    Text("T\(t + 1)'s engine has no \(family.rawValue) pages.").font(.lupe(13))
                        .foregroundStyle(Theme.textSecondaryRaised).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .id(current?.id)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.15), value: current?.id)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 8)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(SelectionTint.fill(t, percent: 35))
                // a line in the track's colour marks its leading edge
                .overlay(alignment: .leading) { Rectangle().fill(Theme.track[t]).frame(width: 1.5).padding(.top, 12) }
                .shadow(color: .black.opacity(0.5), radius: 12, x: -4)
        }
        .background { TouchFollower(session: session) { if let k = session.lastTouched { marks.mark("s\(k.scope).\(k.id)") } } }
        .onChange(of: session.deviceScreen) { _, s in SoundTab.adoptCursor(session, marks, s) }
        .onAppear {
            SoundTab.adoptCursor(session, marks, session.deviceScreen)
            if !pages.contains(where: { $0.id == ui.focusedPage?.id }), let first = pages.first { ui.focus(first) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sound panel, \(family.rawValue)")
        .accessibilityAction(.escape) { SoundPanelControl.dismiss(ui, session: session) }
    }
}

/// One round dial (Android's RoundDial, board 75): the value inside a 52 pt ring, the label under it. The ring is the
/// track's colour (white on a shared page) from the start, or the centre on a bipolar value; it goes white while a finger
/// slides it and while the FM-1 turns it. A dead value dims.
struct RoundDialFace: View {
    let spec: KnobSpec
    let tint: Color
    let hot: Bool
    static let ring: CGFloat = 52, height: CGFloat = 74

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Canvas { ctx, sz in
                    let w: CGFloat = 5, r = sz.width / 2 - w / 2 - 2
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    func arc(_ a: Double, _ b: Double) -> Path {
                        Path { p in p.addArc(center: c, radius: r, startAngle: .degrees(a), endAngle: .degrees(b), clockwise: false) }
                    }
                    let style = StrokeStyle(lineWidth: w, lineCap: .round)
                    ctx.stroke(arc(135, 405), with: .color(Theme.stepEmpty), style: style)
                    let f = min(max(spec.fraction, 0), 1), a = 135 + 270 * f
                    let from = spec.bipolar ? 270.0 : 135.0
                    if abs(a - from) > 0.5 { ctx.stroke(arc(min(from, a), max(from, a)), with: .color(hot ? Theme.text : tint), style: style) }
                }
                Text(spec.shown).font(.lupeNumber(17, .semibold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: Self.ring - 14)
                    .foregroundStyle(Theme.text)
            }
            .frame(width: Self.ring, height: Self.ring)
            .animation(.easeOut(duration: 0.15), value: hot)
            Text(spec.label).font(.lupe(11, .medium)).foregroundStyle(Theme.textSecondaryRaised)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .opacity(spec.dead ? 0.5 : 1)
        .frame(maxWidth: .infinity).frame(height: Self.height)
    }
}
