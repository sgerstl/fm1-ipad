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
    @AppStorage(RailSide.key) private var railSide = RailSide.right
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // the rail on the side Settings › Sound buttons side says; the panel still comes in from the right
            if showRail, railSide == .left { SoundRail(session: session, ui: ui) }
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
                    .padding(.trailing, showRail && railSide == .right ? 0 : -8)
                    .padding(.bottom, -8)
                    // in 300 ms ease-out, out in 200 ms ease-in (DESIGN.md: exits quicker)
                    .animation(reduceMotion ? .easeOut(duration: 0.15)
                               : ui.soundPanel != nil ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3) : .easeIn(duration: 0.2),
                               value: ui.soundPanel != nil)
                }
            if showRail, railSide == .right { SoundRail(session: session, ui: ui) }
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

    var body: some View {
        let t = session.selectedTrack
        let pages = SoundPage.shown(session, family)
        let current = (session.screenLinked ? pages.first { SoundCard.onDevice(session, $0) } : nil)
            ?? pages.first { $0.id == ui.focusedPage?.id } ?? pages.first
        // GLO counts its MIXER, the Mix tab, as 1/5 (decision 44): its pages here are 2/5 to 5/5
        let glo = family == .glo, offset = glo ? 1 : 0
        let n = current.flatMap { c in pages.firstIndex { $0.id == c.id } }.map { $0 + 1 + offset } ?? 0
        VStack(alignment: .leading, spacing: 8) {
            // the dials' header, the only page label (decision 27): family, page n/count, page name; the close arrow
            HStack(spacing: 8) {
                Text(family.rawValue).font(.lupe(17, .semibold)).accessibilityAddTraits(.isHeader)
                if let c = current {
                    Text("\(n)/\(pages.count + offset) \(c.title(session))").font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
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
                                ForEach(0..<4, id: \.self) { k in PageDial(session: session, ui: ui, page: c, slot: k, marks: marks).frame(maxWidth: .infinity) }
                            }
                            // a setting that isn't a knob (GLO › DELAY's MODE): one row of pick tiles, 56 pt
                            ForEach(c.settings, id: \.self) { id in PanelPick(session: session, scope: c.scope, id: id) }
                            if graphics, FM1Picture.titles.contains(c.title) {
                                // GLO's pages: the FM-1's own drawing in the global greys (board 77), the rest of the height at
                                // the FM-1's 936 : 552, centred
                                FM1Picture(session: session, page: c)
                                    .aspectRatio(936.0 / 552.0, contentMode: .fit)
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if graphics, PageGraph.has(c, session) {
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
                // GLO's pages are every track's: the global grey, not the track's colour (decision 44)
                .fill(SelectionTint.fill(colour: family == .glo ? Theme.textTertiary : Theme.track[t], percent: 35))
                // a line in the track's colour (GLO: the grey) marks its leading edge
                .overlay(alignment: .leading) { Rectangle().fill(family == .glo ? Theme.textTertiary : Theme.track[t]).frame(width: 1.5).padding(.top, 12) }
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

/// Knob `slot` of a page as a round dial: the FM-1's slide (Settings › Slide to turn), the Magnifier, double tap back.
/// Touching it makes its page the FM-1's (linked), as a card's column does. White on a shared page.
struct PageDial: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    let slot: Int
    let marks: ShapeMarks

    var body: some View {
        let p = page, k = slot
        if let id = p.ids[safe: k] ?? nil {
            let sc = p.scope(of: k)
            let tint = sc == 1 ? Theme.text : Theme.track[session.selectedTrack]
            let isHot = marks.key == p.key(k)
            KnobControl(ui: ui, activate: { activate() }, column: (k + 1, tint, isHot),
                        face: { spec, dragging in AnyView(RoundDialFace(spec: spec, tint: tint, hot: isHot || dragging)) }) {
                var s = KnobSpec.param(session, scope: sc, id: id, slot: k, label: p.knobLabels[safe: k] ?? nil)
                if SoundCard.deadWhileStrumOff(session, p, k) { s.dead = true; s.spoken += ", does nothing while STRUM is off" }
                return s
            }
        } else {
            Color.clear.frame(height: RoundDialFace.height).accessibilityHidden(true)
        }
    }

    private func activate() -> Bool {
        let on = SoundCard.onDevice(session, page)
        if !on { ui.focus(page); if session.screenLinked, ui.followDevice { session.showOnDevice(page: page.fw) } }
        return !on
    }
}

/// A setting that isn't a knob, as one row of pick tiles across the panel (decision 44: GLO › DELAY's MODE), 56 pt tall,
/// its name said to VoiceOver. A tap sets it, every track's when it's global.
struct PanelPick: View {
    let session: DeviceSession
    let scope: Int
    let id: Int

    var body: some View {
        let d = scope == 0 ? session.trackDesc(id) : session.globalDescs[id]
        let v = scope == 0 ? session.cell(id).value : session.globalCell(id).value
        let names = d?.names ?? []
        if !names.isEmpty {
            SegmentedKeys(label: PageSetting.title(d?.label ?? ""), options: names, selected: v - (d?.min ?? 0)) { k in
                let nv = k + (d?.min ?? 0)
                if scope == 0 { session.set(track: session.selectedTrack, param: id, to: nv) } else { session.set(global: id, to: nv) }
            }
            .font(.lupe(13))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
    }
}
