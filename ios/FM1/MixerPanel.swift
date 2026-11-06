import SloopKit
import SwiftUI

// Skiff's GLO pages as the Mixer tab (Scott, 2026-11-05: "we might want a mixer tab"; it replaced the bottom panel
// and the mixer key beside the tempo). Song · Shape · Mixer · Browse. The six tracks' strips (Skiff's MIXER, GR_TRK)
// fill the top and don't scroll, so their faders take the finger at once; under them the shared Delay, Reverb,
// Chorus and Global as Shape's cards (their columns over GR_DELAY, GR_REVERB, GR_CHORUS, GR_GLOBAL), side by side
// in the phone Shape's carousel: a swipe snaps the next card into the middle with a little bounce. GLO on the
// FM-1 (or its pad here) lands here, and again steps the sections; linked, the card swiped to (or the strips
// touched) shows its page on the FM-1.

struct MixerPage: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.soundPanelRoom) private var panelRoom

    /// The cards' whole height (header, carousel, dots), once laid out.
    @State private var cardsHeight: CGFloat?

    var body: some View {
        let _ = BodyCounter.tick("MixerPage")
        let shared = SoundPage.pages(session).filter { $0.family == .glo }
        // Fixed sizes for the strips and the cards, worked out here: with flexible stacks, a value turning on a card
        // (its text a little wider) re-measured the whole tab, every strip and fader, on every frame. 98% of the
        // main thread on the iPad Air, hitches up to 233 ms (Instruments, 2026-11-06). A fixed frame stops it there.
        GeometryReader { g in
            let w = g.size.width, cards = shared.isEmpty ? 0 : (cardsHeight.map { $0 + 24 } ?? 0)
            let strips = max(200, g.size.height - 8 - cards - 24 - 10 - 32)       // header, spacing, the panel's padding
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    // the header reads the section in its own body: read here, every swipe of the cards re-ran this
                    // page and re-measured the whole tab (2026-11-06)
                    MixerSectionsHeader(session: session, ui: ui)
                    MixerStrips(session: session, ui: ui, touched: { show(.mixer) })
                        .frame(width: max(0, w - panelRoom - 32), height: strips)
                        .padding(16)
                        .panel()
                        .overlay(alignment: .top) { MixerDeviceEdge(session: session) }      // (the FM-1's screen read there)
                        .accessibilityAction(named: "Show on the FM-1") { show(.mixer) }
                }
                .padding(.trailing, panelRoom)
                if !shared.isEmpty {
                    MixerCards(session: session, ui: ui, pages: shared, trailing: panelRoom)
                        .frame(width: w, height: cardsHeight)
                        .fixedSize(horizontal: false, vertical: cardsHeight == nil)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                            if cardsHeight == nil, h > 0 { cardsHeight = h.rounded(.up) }
                        }
                }
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
        if session.screenLinked, ui.followDevice, !onDevice(t.page) { session.showOnDevice(page: t.page) }
    }
}

/// The strips' lit edge while the FM-1 shows MIXER: its own view, so a page change on the FM-1 redraws only it.
private struct MixerDeviceEdge: View {
    let session: DeviceSession

    var body: some View {
        let page = SkiffButtonMap.MixerTab.mixer.page
        DeviceEdge(on: session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == page } == true)
    }
}

/// MIXER's header with GLO's sections across it, the current one lit.
private struct MixerSectionsHeader: View {
    let session: DeviceSession
    let ui: EditorUI

    var body: some View {
        MixerHeader(title: "MIXER", lit: ui.mixerSection == .mixer) { sections }
    }

    /// GLO's pages in the FM-1's order, numbered as GLO steps them, the current one lit: a tap goes there (the
    /// strips, or that card into the middle), and it's how VoiceOver moves between them.
    private var sections: some View {
        HStack(spacing: 2) {
            ForEach(SkiffButtonMap.MixerTab.allCases) { t in
                let on = ui.mixerSection == t
                Button { show(t) } label: {
                    HStack(spacing: 6) {
                        LED(on: on)
                        Text(t.title).font(.system(size: 13, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.text : Theme.textSecondary)
                            .lineLimit(1).fixedSize()           // narrowed by the sound panel: never a letter a line
                    }
                    .padding(.horizontal, 10).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t.title), GLO page \(t.rawValue + 1) of \(SkiffButtonMap.MixerTab.allCases.count)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(height: 24)
    }

    private func onDevice(_ page: Int) -> Bool {
        session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == page } == true
    }

    private func show(_ t: SkiffButtonMap.MixerTab) {
        if ui.mixerSection != t { ui.mixerSection = t }
        if session.screenLinked, ui.followDevice, !onDevice(t.page) { session.showOnDevice(page: t.page) }
    }
}

/// The sound panel's room (ENV LFO FX SEL EDIT ARP bring it in from the right, for the selected track; built for
/// the Song tab, not yet here): whoever shows the panel over the Mixer tab sets its width, and the strips and the
/// cards make way. 0 while it's out. Nothing on the tab sits on the right edge or takes a swipe from it.
extension EnvironmentValues {
    @Entry var soundPanelRoom: CGFloat = 0
}

private struct MixerHeader<Trailing: View>: View {
    let title: String
    let lit: Bool
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold)).tracking(0.6)
                .foregroundStyle(lit ? Theme.text : Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Theme.stepEmpty).frame(height: 1)
            trailing
        }
        .frame(minHeight: 24)
    }
}

extension MixerHeader where Trailing == EmptyView {
    init(title: String, lit: Bool) { self.init(title: title, lit: lit, trailing: { EmptyView() }) }
}

/// The page on the FM-1's screen: a lit edge along a panel's top, as Shape's cards have it.
struct DeviceEdge: View {
    let on: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5).fill(Theme.text)
            .frame(height: 3)
            .padding(.horizontal, 14)
            .offset(y: 1)
            .glow(Theme.text.opacity(0.7), radius: 6)
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
    @State private var marks = ShapeMarks()
    @State private var centred: String?
    @State private var width: CGFloat = 0
    /// The tallest card, once laid out: the carousel's height from then on (see the frame below)
    @State private var height: CGFloat?
    @State private var placed = false          // the first card placed on opening: not a swipe, so the section stays
    @State private var scrolling = false       // a swipe or its snap under way: the page change waits for it to settle
    @State private var grabbed: Int?           // the card in the middle when the finger came down: a swipe moves one from it
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88) }   // ~0.25 s, a hint of bounce

    var body: some View {
        let _ = BodyCounter.tick("MixerCards")
        let cardWidth = min(640, max(440, ((width - trailing) * 0.6).rounded()))
        VStack(alignment: .leading, spacing: 10) {
            MixerHeader(title: "SHARED", lit: ui.mixerSection != .mixer)
                .padding(.trailing, trailing)
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
            .contentMargins(.horizontal, max(0, (width - trailing - cardWidth) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.trailing, trailing)
            // a fixed height once the cards are measured, not .fixedSize: sized by its content, every change in a
            // card (a swipe's page change, a value) asked the whole tab to measure again (2026-11-06)
            .frame(height: height)
            .fixedSize(horizontal: false, vertical: height == nil)
            dots
                .padding(.trailing, trailing)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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

    /// How many cards and which is in the middle: a dot each, the current one white (track-neutral), the others grey;
    /// a tap brings that card in. They follow the swipe (`centred`).
    private var dots: some View {
        HStack(spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { k, p in
                let on = centred == p.id
                Button { withAnimation(spring) { centred = p.id } } label: {
                    Circle().fill(on ? Theme.text : Theme.textTertiary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .frame(width: 28, height: 28)              // the dot small, its target not
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.title.capitalized), card \(k + 1) of \(pages.count)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: centred)
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
        guard let id = centred, let p = pages.first(where: { $0.id == id }), let t = tab(for: p) else { return }
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
    var touched: () -> Void = {}

    private var revID: Int? { SoundPage.pages(session).first { $0.title == "FX" }?.ids[safe: 3] ?? nil }

    var body: some View {
        let _ = BodyCounter.tick("mixer.strips")
        let id = revID
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(session.trackIndices), id: \.self) { t in
                MixerStrip(session: session, row: row(t, id), touched: touched).equatable()
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

    private func row(_ t: Int, _ id: Int?) -> MixRow {
        let tr = session.tracks[t]
        var r = MixRow(track: t, name: Entries.trackName(t, session: session), level: tr.level,
                       levelDefault: session.trackDesc(Param.level)?.defaultValue, pan: tr.pan, mute: tr.mute,
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

/// One track's strip: its chip and name (tap to select the track, as the Song tab's lane headers), LEVEL on a
/// sticky fader in the track's colour, PAN and the REVERB send across, MUTE a toggle chiclet (down is muted).
private struct MixerStrip: View, Equatable {
    let session: DeviceSession
    let row: MixRow
    let touched: () -> Void

    nonisolated static func == (a: MixerStrip, b: MixerStrip) -> Bool { a.session === b.session && a.row == b.row }

    var body: some View {
        let _ = BodyCounter.tick("mixer.strip")
        let t = row.track, colour = Theme.track[t]
        VStack(spacing: 12) {
            Button { session.select(track: t) } label: {
                HStack(spacing: 8) {
                    TrackChip(track: t, selected: row.selected).frame(width: 28, height: 28)
                    Text(row.name).font(.system(size: 13, weight: row.selected ? .semibold : .regular))
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
            Fader(axis: .vertical, spec: levelSpec, tint: row.mute ? Theme.textTertiary : colour, nudge: 2,
                  detent: MixerStrips.unity, touched: touched,
                  meter: AnyView(LevelLine(meters: session.meters, track: t, muted: row.mute, tint: colour)))
                .frame(maxHeight: .infinity)
            Fader(axis: .horizontal, spec: panSpec, tint: colour, touched: touched)
            if row.rev != nil { Fader(axis: .horizontal, spec: revSpec, tint: colour, touched: touched) }
            Button { session.set(track: t, param: Param.mute, to: row.mute ? 0 : 1) } label: {
                HStack(spacing: 6) {
                    LED(on: row.mute)
                    Text("MUTE").font(.system(size: 13, weight: .semibold))
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
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(row.selected ? colour.opacity(0.12) : Theme.well))
        .accessibilityElement(children: .contain)
    }

    private var levelSpec: KnobSpec {
        let t = row.track, v = row.level
        return KnobSpec(id: "mix.level\(t)", colour: Theme.track[t], label: "LEVEL", value: v, range: 0...127, stepperStep: 2,
                        shown: MixerStrips.dB(v), spoken: v == 0 ? "off" : MixerStrips.dB(v).replacingOccurrences(of: "dB", with: "decibels"),
                        bipolar: false, defaultValue: row.levelDefault ?? MixerStrips.unity) { session.set(track: t, param: Param.level, to: $0) }
    }
    private var panSpec: KnobSpec {
        let t = row.track, p = row.pan
        return KnobSpec(id: "mix.pan\(t)", colour: Theme.track[t], label: "PAN", value: p, range: -64...63, stepperStep: 4,
                        shown: MixerStrips.pan(p), spoken: p == 0 ? "centre" : p < 0 ? "\(-p) left" : "\(p) right",
                        bipolar: true, defaultValue: 0) { session.set(track: t, param: Param.pan, to: $0) }
    }
    private var revSpec: KnobSpec {
        let t = row.track, id = row.revID ?? 0
        return KnobSpec(id: "mix.rev\(t)", colour: Theme.track[t], label: "REVERB", value: row.rev ?? 0, range: row.revRange,
                        stepperStep: 4, shown: row.revShown, spoken: row.revSpoken, bipolar: false, defaultValue: row.revDefault) { session.set(track: t, param: id, to: $0) }
    }
}

// MARK: Where the FM-1's buttons land (SkiffButtonMap)

enum SkiffNavigator {
    /// The FM-1 changed screen: go where its button lands in Jib (linked only; on stock Skiff nothing moves).
    @MainActor static func follow(_ s: UIState, session: DeviceSession, ui: EditorUI) {
        guard ui.followDevice, session.screenLinked, let place = SkiffButtonMap.place(for: s) else { return }
        if case .mixer(let t) = place { if ui.mixerSection != t { ui.mixerSection = t }; go(.mixer, ui); return }
        switch place {
        case .home: go(.sequencer, ui)
        case .shape(let p):
            if s.layer == SkiffButtonMap.keysLayer { ui.soundFamily = .sel }
            else if let page = SoundPage.page(session, fw: p) { ui.soundFamily = page.family }
            ui.pageFromDevice = true
            go(.sound, ui)
        case .sequence(let f):
            go(.sequencer, ui)
            flash(f == .pattern ? .trackPanel : f == .automation ? .grid : .stepPanel, ui)
        case .arrange(let patterns):
            go(.song, ui)
            // SAVE > PATTERNS: the Song tab's Patterns drawer, open
            if patterns { if ui.songTab { ui.poolOpen = true }; flash(.patternBin, ui) }
        case .browse: browse(user: s.page == 36, session: session, ui: ui)
        case .projects:
            // the Projects sheet: SLOOP's backups, or Skiff's 4 slots on the FM-1 beside the iPad's projects
            if session.capabilities.contains(.projects) || session.dialect == .skiff { ui.projectsOpen = true }
        case .mixer: break
        }
    }

    /// SAVE's PRESETS (35) and USER (36) pages: the Sounds tab, on the factory sounds or the user slots.
    @MainActor private static func browse(user: Bool, session: DeviceSession, ui: EditorUI) {
        go(.library, ui)
        if user { ui.librarySection = .user }
        else if ui.librarySection == .user, !session.selectedIsDrums { ui.librarySection = .engine(session.tracks[session.selectedTrack].engine) }
    }

    /// The SAVE pad on Skiff: PRESETS, USER, PATTERNS, PROJECT in turn, as the FM-1's SAVE steps its pages. From the
    /// FM-1's screen when linked; otherwise from where Jib is.
    @MainActor static func save(session: DeviceSession, ui: EditorUI) {
        let now: Int? = if session.screenLinked, let s = session.deviceScreen, !s.home, (35...38).contains(s.page) { s.page }
            else if ui.page == .song && ui.poolOpen { 37 }
            else if ui.page == .library { ui.librarySection == .user ? 36 : 35 }
            else { nil }
        let next = now.map { $0 == 38 ? 35 : $0 + 1 } ?? 35
        if session.screenLinked, ui.followDevice { session.showOnDevice(page: next) }
        if next != 37 { ui.poolOpen = false }
        switch next {
        case 35, 36: browse(user: next == 36, session: session, ui: ui)
        case 37: go(.song, ui); ui.poolOpen = true
        default: ui.projectsOpen = true
        }
    }

    @MainActor private static func go(_ p: Page, _ ui: EditorUI) { if ui.page != p { ui.pageFromDevice = true; ui.page = p } }

    @MainActor static func flash(_ t: FlashTarget, _ ui: EditorUI) {
        // the Song tab keeps the whole-track controls in a popover: PATTERN opens it
        if t == .trackPanel, ui.songTab { ui.trackControlsOpen = true; return }
        ui.flash = Flash(target: t, id: (ui.flash?.id ?? 0) + 1)
    }
}

/// A ring around the place the FM-1 just sent Jib to, fading after a moment.
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
