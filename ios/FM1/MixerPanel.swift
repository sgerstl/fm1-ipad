import SloopKit
import SwiftUI

// Skiff's GLO MIXER as the Mix tab (Scott, 2026-11-05: "we might want a mixer tab"; it replaced the bottom panel and
// the mixer key beside the tempo). The six tracks' strips (Skiff's MIXER, GR_TRK) are the whole page and don't scroll, so
// their faders take the finger at once (decision 48, 2026-11-15: the shared Delay, Reverb, Chorus and Global are
// sound-panel pages since decision 44, so their cards under the strips went; MixerCards stays for now, unused here).
// With the sound panel open the strips stand in two rows of three beside it. Linked, a strip touched shows MIXER on
// the FM-1.

struct MixerPage: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.soundPanelRoom) private var panelRoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = BodyCounter.tick("MixerPage")
        // the strips are the page (decision 48, 2026-11-15): GLO's DELAY, REVERB, CHORUS and GLOBAL are sound-panel pages
        // (decision 44), so the effect cards under the strips went. With the sound panel open the strips stand in two rows
        // of three beside it, the panel at full size and every control in reach; one row again when it closes. Fixed
        // sizes worked out here: flexible stacks re-measured the whole tab on every value change (Instruments, 2026-11-06).
        GeometryReader { g in
            let w = g.size.width, twoRows = panelRoom > 0
            VStack(alignment: .leading, spacing: 0) {
                MixerStrips(session: session, ui: ui, rows: twoRows ? 2 : 1, touched: { show(.mixer) })
                    .frame(width: max(0, w - panelRoom - 32), height: max(200, g.size.height - 8 - 32))
                    .padding(16)
                    .panel()
                    .overlay(alignment: .top) { MixerDeviceEdge(session: session) }      // (the FM-1's screen read there)
                    .accessibilityAction(named: "Show on the FM-1") { show(.mixer) }
                    .padding(.trailing, panelRoom)
                    // the strips move between one row and two with the panel (moving and blending, nothing pops)
                    .animation(reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3), value: twoRows)
            }
            .padding(.bottom, 8)
            .frame(width: w, height: g.size.height, alignment: .topLeading)
        }
    }

    private func onDevice(_ page: Int) -> Bool {
        session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == page } == true
    }

    private func show(_ t: SkiffButtonMap.MixerTab) {
        if ui.mixerSection != t { ui.mixerSection = t }
        guard session.dialect == .skiff else { return }
        // a sound panel docked beside the strips (decision 48): turning a strip leaves the FM-1 on the panel's page.
        // Sending it to MIXER brought MIXER back, which closes a GLO panel (decision 44), and the strips' two rows went
        // with it (Scott, 2026-11-15). A touch on the page is the page's own; only HOME, the close key or another tab
        // close the panel.
        guard ui.soundPanel == nil else { return }
        if session.screenLinked, ui.followDevice, !onDevice(t.page) { session.showOnDevice(page: t.page) }
    }
}

/// The strips' lit edge while the FM-1 shows MIXER: its own view, so a page change on the FM-1 redraws only it.
private struct MixerDeviceEdge: View {
    let session: DeviceSession

    var body: some View {
        let page = SkiffButtonMap.MixerTab.mixer.page
        DeviceEdge(on: session.dialect == .skiff && session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == page } == true)
    }
}

/// The sound panel's room (ENV LFO FX SEL EDIT ARP bring it in from the right, for the selected track; built for
/// the Song tab, not yet here): whoever shows the panel over the Mixer tab sets its width, and the strips and the
/// cards make way. 0 while it's out. Nothing on the tab sits on the right edge or takes a swipe from it.
extension EnvironmentValues {
    @Entry var soundPanelRoom: CGFloat = 0
}

/// The page on the FM-1's screen: a lit edge along a panel's top, as Shape's cards have it.
struct DeviceEdge: View {
    let on: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5).fill(Theme.text)
            .frame(height: 3)
            .padding(.horizontal, 14)
            .offset(y: 1)
            .opacity(on ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: on)
            .accessibilityHidden(true)
    }
}

// MARK: Shared: the cards, one in the middle (PhoneShape's carousel)

/// DELAY REVERB CHORUS GLOBAL in the FM-1's GLO order, the current one in the middle and its neighbours peeking in,
/// a little smaller. A swipe snaps the next card in with a little bounce (PhoneShape's values: view-aligned paging,
/// 0.92 at the sides, a 0.4 s spring at 0.82 damping); a tap on a neighbour brings it to the middle. The card in the
/// middle is the Mixer's section: linked, the FM-1 shows its page, and GLO on the FM-1 brings the next one in.
private struct MixerCards: View {
    let session: DeviceSession
    let ui: EditorUI
    let pages: [SoundPage]
    let trailing: CGFloat
    /// The tab's width, given (measured here, beside the selector, it went round in a circle and came out 0)
    let width: CGFloat
    @State private var marks = ShapeMarks()
    @State private var centred: String?
    /// The tallest card, once laid out: the carousel's height from then on (see the frame below)
    @State private var height: CGFloat?
    @State private var placed = false          // the first card placed on opening: not a swipe, so the section stays
    @State private var scrolling = false       // a swipe or its snap under way: the page change waits for it to settle
    @State private var grabbed: Int?           // the card in the middle when the finger came down: a swipe moves one from it
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88) }   // ~0.25 s, a hint of bounce

    var body: some View {
        let _ = BodyCounter.tick("MixerCards")
        // the carousel beside the selector: the card in the middle roomy, its neighbours partly in view on both sides
        // (Scott, 2026-11-06: "a little narrower once we put the buttons in on the left")
        let room = max(0, width - trailing - Self.selectorWidth - 16)
        let cardWidth = min(560, max(380, (room * 0.56).rounded()))
        HStack(alignment: .center, spacing: 16) {
            selector
            ScrollView(.horizontal) {
                // all four built once, not lazily: a lazy stack made the card coming in (columns, graph) on every
                // swipe, 70–85 ms of view creation and layout on the iPad Air (Instruments, 2026-11-06)
                HStack(alignment: .top, spacing: 16) {
                    ForEach(pages) { p in
                        card(p)
                            .frame(width: cardWidth)
                            .scrollTransition(.interactive, axis: .horizontal) { c, phase in
                                c.scaleEffect(phase.isIdentity ? 1 : 0.92)
                            }
                            .id(p.id)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                                if h > (height ?? 0) + 0.5 { height = h }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centred, anchor: .center)
            .contentMargins(.horizontal, max(0, (room - cardWidth) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            // a fixed size once the cards are measured, not .fixedSize: sized by its content, every change in a
            // card (a swipe's page change, a value) asked the whole tab to measure again (2026-11-06)
            .frame(width: room, height: height)
            .fixedSize(horizontal: false, vertical: height == nil)
        }
        .padding(.trailing, trailing)
        .onAppear {
            placed = true
            centred = id(for: ui.mixerSection) ?? pages.first?.id
            marks.activePage = centred
        }
        .onChange(of: ui.mixerSection) { _, t in
            // GLO (here or on the FM-1) stepped to a card: bring it in
            guard let to = id(for: t), to != centred else { return }
            withAnimation(spring) { centred = to }
        }
        .onChange(of: centred) { _, id in
            // the card in the middle while scrolling: its page the knobs' (cheap); the rest when the snap settles
            guard let id else { return }
            marks.activePage = id
            if placed { placed = false; return }
            if !scrolling { commit() }
        }
        // the card swiped into the middle becomes the Mixer's section, and the one the FM-1 shows, once the scroll has
        // settled: done mid-swipe, the page change rebuilt cards under the snap and it hitched (2026-11-06)
        .onScrollPhaseChange { old, phase, context in
            scrolling = phase.isScrolling
            // the finger lifts: snap to the card now with a stiff spring instead of the scroll view's own slow settle,
            // and make it the section at once, so its columns take the finger while it lands (Scott, 2026-11-06)
            if phase == .interacting, old != .interacting { grabbed = centred.flatMap { c in pages.firstIndex { $0.id == c } } }
            // any release, a flick or a slow one: a slow one went to the scroll view's own long settle (2026-11-06)
            if old == .interacting, phase != .interacting { snap(velocity: context.velocity?.dx ?? 0) }
            if !phase.isScrolling { commit() }
        }
    }

    static let selectorWidth: CGFloat = 132

    /// DELAY REVERB CHORUS GLOBAL down the left (Scott, 2026-11-06, in place of the dots and the section names): the
    /// card in the middle lit, a tap brings that card in (and, linked, its page to the FM-1). They follow the swipe.
    private var selector: some View {
        VStack(spacing: 8) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { k, p in
                let on = centred == p.id
                Button { withAnimation(spring) { centred = p.id } } label: {
                    HStack(spacing: 8) {
                        LED(on: on)
                        Text(p.title.capitalized).font(.lupe(15, on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.text : Theme.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(width: Self.selectorWidth, height: 44)
                    .background { if on { Color.clear.selectedKey(10) } else { Color.clear.raisedKey(10) } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel("\(p.title.capitalized), shared effect \(k + 1) of \(pages.count)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: centred)
    }

    /// The card nearest the middle when the finger lifts, one further when it was flicked that way; landed with `spring`.
    /// Magnets (Scott, 2026-11-06: "it too easily flings past the next pane"): a swipe lands on the card it started
    /// from or one either side, never further. A flick goes one on from the card grabbed (not from the one that had
    /// already reached the middle under the finger, which flung two); a slow release goes to the nearest of those.
    private func snap(velocity: CGFloat) {
        guard let cur = centred, let k = pages.firstIndex(where: { $0.id == cur }) else { return }
        let from = grabbed ?? k
        var to = abs(velocity) > 0.4 ? (velocity > 0 ? from + 1 : from - 1) : k     // (points per millisecond: a flick)
        to = min(max(to, from - 1, 0), from + 1, pages.count - 1)
        grabbed = nil
        withAnimation(spring) { centred = pages[to].id }
        scrolling = false
        commit()
    }

    private func commit() {
        guard let id = centred, let p = pages.first(where: { $0.id == id }) else { return }
        guard let t = tab(for: p) else { return }
        if ui.mixerSection != t { ui.mixerSection = t }
        guard session.screenLinked, ui.followDevice,
              session.deviceScreen.map({ !$0.home && $0.page == t.page }) != true else { return }
        session.showOnDevice(page: t.page)
    }

    private func card(_ p: SoundPage) -> some View {
        let middle = centred == p.id
        return SoundCard(session: session, ui: ui, rows: [p], pages: glo, marks: marks).equatable()
            .environment(\.columnsOverScroll, true)       // a slide on a column turns it; the carousel moves from elsewhere
            // a card at the side takes a tap anywhere and comes to the middle; its columns work once it's there
            .overlay {
                if !middle {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { withAnimation(spring) { centred = p.id } }
                        .accessibilityHidden(true)
                }
            }
    }

    /// GLO's five pages as the FM-1 counts them (MIXER first), so a card's "On the FM-1" reads as its screen does:
    /// DELAY 2/5 … GLOBAL 5/5.
    private var glo: [SoundPage] {
        [SoundPage(fw: SkiffButtonMap.MixerTab.mixer.page, title: "MIXER", family: .glo, scope: 1, ids: [nil, nil, nil, nil])] + pages
    }

    private func tab(for p: SoundPage) -> SkiffButtonMap.MixerTab? { SkiffButtonMap.MixerTab.allCases.first { $0.pageTitle == p.title } }
    private func id(for t: SkiffButtonMap.MixerTab) -> String? { pages.first { $0.title == t.pageTitle }?.id }
}

// MARK: Mixer: six strips (ui_graph.c mix_strip)

/// What one strip shows, read once for all six so each strip redraws only when its own values change (a CHANGED
/// push for one track, or a fader held at 120 Hz, leaves the other five alone).
struct MixRow: Equatable {
    var track: Int
    var name: String
    var level: Int
    var levelDefault: Int?
    var pan: Int
    var mute: Bool
    var selected: Bool
    var revID: Int?
    var rev: Int?
    var revRange: ClosedRange<Int> = 0...127
    var revDefault: Int?
    var revShown = ""
    var revSpoken = ""
}

/// Skiff's MIXER as six strips side by side. Every track's REVERB is read when the tab opens and every few seconds
/// while it's up (the protocol doesn't push another track's parameters).
struct MixerStrips: View {
    let session: DeviceSession
    let ui: EditorUI
    /// 1: six across; 2: three and three (the sound panel open beside them, decision 48).
    var rows = 1
    var touched: () -> Void = {}

    var revID: Int? { SoundPage.pages(session).first { $0.title == "FX" }?.ids[safe: 3] ?? nil }

    var body: some View {
        let _ = BodyCounter.tick("mixer.strips")
        let id = revID
        StripsLayout(rows: rows, spacing: 8) {
            ForEach(Array(session.trackIndices), id: \.self) { t in
                MixerStrip(session: session, ui: ui, row: row(t, id), touched: touched).equatable()
            }
        }
        .task(id: id) {
            guard let id else { return }
            while !Task.isCancelled {
                await session.readEveryTrack(id: id)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func row(_ t: Int, _ id: Int?) -> MixRow {
        let tr = session.tracks[t]
        var r = MixRow(track: t, name: Entries.trackName(t, session: session), level: tr.level,
                       levelDefault: session.trackDesc(session.ids.level)?.defaultValue, pan: tr.pan, mute: tr.mute,
                       selected: t == session.selectedTrack)
        if let id {
            let v = t == session.selectedTrack && id < session.params.count ? session.params[id] : session.everyTrack[id]?[t] ?? 0
            let d = session.trackDesc(id), f = formatValue(d, v)
            r.revID = id; r.rev = v; r.revRange = (d?.min ?? 0)...(d?.max ?? 127); r.revDefault = d?.defaultValue
            r.revShown = f.shown; r.revSpoken = f.spoken
        }
        return r
    }

    /// LEVEL as Skiff writes it under the fader: its dB ((v − 112) / 2), OFF at 0.
    static func dB(_ v: Int) -> String {
        guard v > 0 else { return "OFF" }
        let d = (v - 112) * 5
        return "\((d + (d < 0 ? -5 : 5)) / 10) dB"
    }
    /// PAN as Skiff writes it (pan_txt): C, L100…, R100 at the top.
    static func pan(_ p: Int) -> String { p == 0 ? "C" : p < 0 ? "L\(-p * 100 / 64)" : "R\(p * 100 / 63)" }
    /// 0 dB on the LEVEL fader.
    static let unity = 112
}

/// The strips in `rows` rows, left to right, top to bottom, each the same size and filling the space: one row of six,
/// or two of three beside the sound panel (decision 48). A change of `rows` animates each strip to its new place.
struct StripsLayout: Layout {
    var rows: Int
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let r = max(1, rows), perRow = Int((Double(subviews.count) / Double(r)).rounded(.up))
        let w = (bounds.width - CGFloat(perRow - 1) * spacing) / CGFloat(perRow)
        let h = (bounds.height - CGFloat(r - 1) * spacing) / CGFloat(r)
        for (k, v) in subviews.enumerated() {
            let x = bounds.minX + CGFloat(k % perRow) * (w + spacing), y = bounds.minY + CGFloat(k / perRow) * (h + spacing)
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: w, height: h))
        }
    }
}

/// One track's strip: its chip and name (tap to select the track, as the Song tab's lane headers), LEVEL on a
/// sticky fader in the track's colour, PAN and the REVERB send across, MUTE a toggle chiclet (down is muted).
private struct MixerStrip: View, Equatable {
    let session: DeviceSession
    let ui: EditorUI
    let row: MixRow
    let touched: () -> Void

    nonisolated static func == (a: MixerStrip, b: MixerStrip) -> Bool { a.session === b.session && a.row == b.row }

    var body: some View {
        let _ = BodyCounter.tick("mixer.strip")
        let t = row.track, colour = Theme.track[t]
        VStack(spacing: 12) {
            // the Half pads' track head (Scott, 2026-11-10: "the same track headers… just for consistency"): chip, name,
            // what it plays, the pass bar, Mute and Solo. Its Mute is PERFORM's (at the launch point while playing), so
            // the strip's own MUTE goes. Without Skiff's song (older firmware): the strip's own name and MUTE.
            if let store = session.skiffSong {
                TrackStripRow(session: session, store: store, ui: ui, track: t, preview: nil).frame(height: 44)
            } else {
            Button { session.select(track: t) } label: {
                HStack(spacing: 8) {
                    TrackChip(track: t, selected: row.selected).frame(width: 28, height: 28)
                    Text(row.name).font(.lupe(13, row.selected ? .semibold : .regular))
                        .foregroundStyle(row.selected ? Theme.text : Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track \(t + 1), \(row.name)")
            .accessibilityHint("Selects the track")
            .accessibilityAddTraits(row.selected ? .isSelected : [])
            }
            Fader(axis: .vertical, spec: row.levelSpec(session), tint: row.mute ? Theme.textTertiary : colour, nudge: 2,
                  detent: MixerStrips.unity, touched: touched,
                  meter: AnyView(LevelLine(meters: session.meters, track: t, muted: row.mute, tint: colour)))
                .frame(maxHeight: .infinity)
            Fader(axis: .horizontal, spec: row.panSpec(session), tint: colour, touched: touched)
            if row.rev != nil { Fader(axis: .horizontal, spec: row.revSpec(session), tint: colour, touched: touched) }
            if session.skiffSong == nil {
            Button { session.set(track: t, param: session.ids.mute, to: row.mute ? 0 : 1) } label: {
                HStack(spacing: 6) {
                    LED(on: row.mute)
                    Text("MUTE").font(.lupe(13, .semibold))
                        .foregroundStyle(row.mute ? Theme.text : Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .latchedKey(row.mute, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressSink(latched: row.mute))
            .accessibilityLabel("Mute track \(t + 1)")
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(row.mute ? "muted" : "playing")
            }
        }
        .padding(.horizontal, session.skiffSong == nil ? 10 : 6).padding(.vertical, 8)   // (6: room for the head's name)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(row.selected ? colour.opacity(0.12) : Theme.well))
        .accessibilityElement(children: .contain)
    }
}

/// A strip's controls as knob specs, shared by the iPad's strips and the phone's rows (PhoneMix).
@MainActor extension MixRow {
    func levelSpec(_ session: DeviceSession) -> KnobSpec {
        let t = track, v = level
        return KnobSpec(id: "mix.level\(t)", colour: Theme.track[t], label: "LEVEL", value: v, range: 0...127, stepperStep: 2,
                        shown: MixerStrips.dB(v), spoken: v == 0 ? "off" : MixerStrips.dB(v).replacingOccurrences(of: "dB", with: "decibels"),
                        bipolar: false, defaultValue: levelDefault ?? MixerStrips.unity) { session.set(track: t, param: session.ids.level, to: $0) }
    }
    func panSpec(_ session: DeviceSession) -> KnobSpec {
        let t = track, p = pan
        return KnobSpec(id: "mix.pan\(t)", colour: Theme.track[t], label: "PAN", value: p, range: -64...63, stepperStep: 4,
                        shown: MixerStrips.pan(p), spoken: p == 0 ? "centre" : p < 0 ? "\(-p) left" : "\(p) right",
                        bipolar: true, defaultValue: 0) { session.set(track: t, param: session.ids.pan, to: $0) }
    }
    func revSpec(_ session: DeviceSession) -> KnobSpec {
        let t = track, id = revID ?? 0
        return KnobSpec(id: "mix.rev\(t)", colour: Theme.track[t], label: "REVERB", value: rev ?? 0, range: revRange,
                        stepperStep: 4, shown: revShown, spoken: revSpoken, bipolar: false, defaultValue: revDefault) { session.set(track: t, param: id, to: $0) }
    }
}

// MARK: Where the FM-1's buttons land (SkiffButtonMap)

/// A ring around the place the FM-1 just sent Lupe to, fading after a moment.
struct FlashRing: ViewModifier {
    let ui: EditorUI
    let target: FlashTarget
    @State private var lit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.text, lineWidth: 2).opacity(lit ? 1 : 0).allowsHitTesting(false) }
            .onChange(of: ui.flash) { _, f in
                guard f?.target == target else { return }
                lit = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1200))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { lit = false }
                }
            }
    }
}

extension View {
    func flashRing(_ ui: EditorUI, _ t: FlashTarget) -> some View { modifier(FlashRing(ui: ui, target: t)) }
}
