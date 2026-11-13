import SloopKit
import SwiftUI

/// Pass 1 step 4: shape the selected track's sound. The FM-1's function buttons along the top; each
/// button's pages laid out flat, every page as its four knobs in the device's knob colours. Turning
/// a knob on the FM-1 brings its button's pages up here and marks the knob (the protocol reports the
/// parameter that changed, not the page or button pressed).

extension SoundPage {
    /// The card a page is on: its own, or the card of the page it's merged into (LFO 2 on LFO's).
    @MainActor static func cardID(of id: String, _ session: DeviceSession) -> String? {
        guard let p = pages(session).first(where: { $0.id == id }) else { return nil }
        if let host = SoundTab.merged.first(where: { $0.value.contains(p.title) })?.key { return "\(p.family.rawValue).\(host)" }
        return p.id
    }

    /// SLOOP's pages the app shows outside the Sound tab (params.c PAGES): TRACKS is HOME in SLOOP's
    /// song build; NOTES and the drum screen are the sequencer's; SECTION, SONG and the SAVE layer
    /// are the Song tab's; SAVE's other pages are the library's.
    static let sequencerPages: Set<Int> = [34, 37, 38]
    static let songPages: Set<Int> = [30, 36]
    static let libraryPages: Set<Int> = [28, 29, 31]
    static let home = 37, presets = 28, section = 30

    /// The tab that shows what the FM-1's screen shows, if any.
    @MainActor static func tab(for s: UIState, _ session: DeviceSession) -> Page? {
        guard session.dialect == .skiff else { return tab(for: s) }
        // Skiff (skiff/README.md): HOME and the sequencer's pages, SONG and PATTERNS (the pool), the
        // presets; its layers: SCL held is the keys' layer, the others' screens are no tab's
        if s.menu != 0 { return nil }
        if s.layer == ScreenMap.skiff.selLayer { return .sound }
        if s.layer != 0 { return nil }
        if s.home || [41, 42, 44].contains(s.page) { return .sequencer }
        if [37, 45].contains(s.page) { return .song }
        if [35, 36].contains(s.page) { return .library }
        if (30...34).contains(s.page) { return .mixer }
        return page(session, fw: s.page) != nil ? .sound : nil
    }

    static func tab(for s: UIState) -> Page? {
        if s.menu != 0 { return nil }
        if s.layer == 5 { return .sound }                              // SEL held: its key layer
        if s.layer == 7 || songPages.contains(s.page) { return .song } // SAVE held: the song layer
        if s.home || sequencerPages.contains(s.page) { return .sequencer }
        if libraryPages.contains(s.page) { return .library }
        return page(fw: s.page) != nil ? .sound : nil
    }
}

/// A parameter's value as text, as the FM-1 shows it (EDITOR_PROTOCOL.md "fmt"; the curves for TIME,
/// LFOHZ, CUTOFF and DB are SLOOP's own, in DeviceDisplay).
func formatValue(_ d: ParamDesc?, _ v: Int, skiff: Bool = false) -> (shown: String, spoken: String) {
    guard let d else { return ("\(v)", "\(v)") }
    // as the FM-1's screen: its curves for times, rates, cutoffs and levels, and name lists on numbers
    if let (text, u) = DeviceDisplay.value(d, v) {
        let shown = u.isEmpty ? text : u == "%" ? "\(text)%" : "\(text) \(u)"
        let spoken = u == "%" ? "\(text) percent" : u == "dB" ? "\(text) decibels" : shown
        return (shown, spoken)
    }
    let unit = d.unit.isEmpty ? "" : " \(d.unit.lowercased())"
    switch d.format {
    // Skiff's BIPCT (params.c): v × 100 / 64 below zero, / 63 above, cut
    case 2 where skiff: let p = v < 0 ? v * 100 / 64 : v * 100 / 63; return (p > 0 ? "+\(p)%" : "\(p)%", "\(p) percent")
    case 2: let p = Int((Double(v) * 100 / 64).rounded()); return (p > 0 ? "+\(p)%" : "\(p)%", "\(p) percent")
    case 7: return (v > 0 ? "+\(v) st" : "\(v) st", "\(v) semitones")
    case 8:
        let k = v - d.min
        let n = k >= 0 && k < d.names.count ? d.names[k] : "\(v)"
        return (n, n.lowercased())
    case 10: return (Music.noteNames[((v % 12) + 12) % 12], Music.spokenNoteNames[((v % 12) + 12) % 12])
    case 11: return (v != 0 ? "ON" : "OFF", v != 0 ? "on" : "off")
    case 12: return (v > 0 ? "+\(v)" : "\(v)", "octave \(v)")
    // Skiff's ST16 (params.c): ±12 semitones in 3/16 steps, shown in tenths, rounded half away from zero
    case 14 where skiff:
        let t = (v - 64) * 30, x = (t + (t < 0 ? -8 : 8)) / 16
        let s = "\(x < 0 ? "-" : x > 0 ? "+" : "")\(abs(x) / 10).\(abs(x) % 10)"
        return ("\(s) st", "\(s) semitones")
    case 14: let p = 50 + v / 4; return ("\(p)%", "\(p) percent swing")
    // Skiff 2.5's F_SHAPE (FILTR's SHAPE): LP, BP, HP, between two "30 BP"
    case 15 where skiff:
        let (t, u) = SkiffDisplay.shape(v)
        let names = ["LP": "low pass", "BP": "band pass", "HP": "high pass"]
        return u.isEmpty ? (t, names[t] ?? t) : ("\(t) \(u)", "\(t) percent toward \(names[u] ?? u)")
    // Skiff 2.5's STRUM (U_MS): 0 is OFF, the chord at once
    case 0 where skiff && d.unit.lowercased() == "ms" && v == 0: return ("OFF", "off")
    case 15:
        if v == 0 { return ("OFF", "off") }
        let p = Int((Double(abs(v)) * 100 / 64).rounded())
        return (v < 0 ? "LP \(p)%" : "HP \(p)%", v < 0 ? "low pass \(p) percent" : "high pass \(p) percent")
    default: return ("\(v)\(unit)", "\(v)\(unit)")
    }
}

extension KnobSpec {
    /// Any parameter of the selected track (scope 0) or a global (scope 1), as a knob.
    @MainActor
    static func param(_ session: DeviceSession, scope: Int, id: Int, slot: Int, label: String? = nil) -> KnobSpec {
        let d = scope == 0 ? session.trackDesc(id) : session.globalDescs[id]
        // locking knob turns to a step (Skiff): the knob shows that step's lock, if it has one
        let locked = scope == 0 ? session.lockStep.flatMap { s in session.motion[session.selectedTrack]?.events.first { $0.lock && $0.step == s && $0.id == id }?.value } : nil
        // the value from its own cell (the track's, or the global's): this knob redraws when this parameter changes, not any
        let v = locked ?? (scope == 0 ? session.cell(id).value : session.globalCell(id).value)
        let lo = d?.min ?? 0, hi = max(d?.max ?? 127, lo)
        let f = formatValue(d, v, skiff: session.dialect == .skiff)
        let t = session.selectedTrack
        let skiff = session.dialect == .skiff
        return KnobSpec(id: "s\(scope).\(id)", colour: Theme.knob[slot % 4], label: label ?? d?.label ?? "–", value: v,
                        range: lo...hi, stepperStep: max(1, (hi - lo) / 16), shown: f.shown, spoken: f.spoken,
                        bipolar: d?.format == 2 || (d?.format == 15 && !skiff) || (lo < 0 && hi > 0),
                        defaultValue: d.map { min(max($0.defaultValue, lo), hi) },
                        choices: d?.format == 8 && !(d?.names.isEmpty ?? true) ? d?.names : nil) { nv in
            if scope == 0 { session.set(track: t, param: id, to: nv) } else { session.set(global: id, to: nv) }
        }
    }
}

/// Skiff: the selected track is playing a song entry's own sound (LIST op 9; set with Arrange's Set sound, or
/// SOUND on the FM-1's song page). Skiff loads that sound as the entry starts (launch.c esnd_put), over the
/// track's: an edit here changes what plays now, and goes when the entry starts again (an entry's sound is
/// changed only by setting another one). Said so, so where an edit goes is never a guess.
struct EntrySoundNote: View {
    let session: DeviceSession

    var body: some View {
        let t = session.selectedTrack
        if session.playing, let list = session.skiffSong?.song?.tracks[safe: t], let e = list.entryOn,
           let snd = list.entries[safe: e]?.sound {
            let name = Entries.soundName(snd, session: session)
            Label {
                Text("T\(t + 1) is playing entry \(Entries.letter(e))'s own sound, \(name). Changes here last until entry \(Entries.letter(e)) starts again; to keep them, save a user preset and set it on entry \(Entries.letter(e)) in Arrange.")
                    .font(.lupe(13)).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "waveform")
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
            .accessibilityElement(children: .combine)
        }
    }
}

struct SoundTab: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var marks = ShapeMarks()     // the knob last turned, the page tapped, MOD's route
    @State private var followed: UIState?       // the FM-1's screen as last followed

    /// The FM-1's buttons in the order Skiff's PAGES table lists their pages (params.c): Shape's sections. GLO's
    /// shared effects keep their place after them for now; SEQ's PATTERN pages close the list.
    static let order: [SoundFamily] = [.env, .lfo, .fx, .sel, .edit, .arp, .glo, .seq]
    /// Skiff: GLO is the mixer panel and SEQ's PATTERN the Sequence page's whole-track controls (the button map).
    static let skiffOrder: [SoundFamily] = [.env, .lfo, .fx, .sel, .edit, .arp]
    /// Pages that drive one thing, shown as rows over its one graph: the first page's title → the others'.
    /// (Skiff's pairs on one graph: GR_LFO, GR_INS, and GR_ARP / GR_ARP2, both graph_arp. ENV and ENV 2 are both GR_ADSR
    /// but each draws its own envelope: two cards.)
    /// EDIT 1 and EDIT 2 on one card with one graph (Scott, 2026-11-07): ANALOG's OSC and FLT side by side, the scope
    /// on most other engines (EditGraph).
    static let merged: [String: [String]] = ["LFO": ["LFO 2"], "INSERT": ["INSERT 2"], "ARP": ["ARP 2"], "EDIT 1": ["EDIT 2"]]

    var body: some View {
        let _ = BodyCounter.tick("SoundTab")
        VStack(alignment: .leading, spacing: 16) {
            EntrySoundNote(session: session)
            ShapeScroll(session: session, ui: ui, marks: marks)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)   // the page area fills its column
        // an encoder's every push changes lastTouched: watched by a view of its own, so the page doesn't redraw
        .background { TouchFollower(session: session) { follow() } }
        .onChange(of: session.deviceScreen) { _, s in followScreen(s) }
        .onAppear {
            // opened by the FM-1: start on its button; opened here (a tab, a pad): keep the choice made
            if ui.pageFromDevice { followScreen(session.deviceScreen) } else { followed = session.deviceScreen; adoptCursor(session.deviceScreen) }
            ui.pageFromDevice = false
        }
    }

    /// The FM-1 changed page (a button pressed on it): show that button's pages here. Holding SEL
    /// (its key layer) brings up SEL.
    private func followScreen(_ s: UIState?) {
        adoptCursor(s)
        // only a real change on the FM-1 moves the page here: the same screen reported again must not
        // undo a button chosen on the iPad (on the drum track SEL, ENV, LFO, EDIT, ARP can't move the
        // FM-1, which stays on its page)
        guard let s, s.home != followed?.home || s.page != followed?.page || s.layer != followed?.layer else { return }
        followed = s
        if s.layer == ScreenMap.of(session).selLayer { if ui.soundFamily != .sel { ui.soundFamily = .sel }; return }   // the keys' layer held
        // (on the drum track the FM-1 opens the synth pages too, showing "DRUM TRACK": follow those as well)
        guard !s.home, let page = SoundPage.page(session, fw: s.page),
              SoundPage.reached(session, page.family).contains(where: { $0.fw == page.fw }) else { return }
        ui.soundFamily = page.family
    }

    /// MOD's route: the FM-1's cursor, when the link carries it (KNOB 1 turned there).
    private func adoptCursor(_ s: UIState?) { Self.adoptCursor(session, marks, s) }
    static func adoptCursor(_ session: DeviceSession, _ marks: ShapeMarks, _ s: UIState?) {
        guard let s, !s.home, let c = s.cursor, let title = SoundPage.page(session, fw: s.page)?.title else { return }
        if title == "MOD" { marks.adoptRoute(c) } else if let key = SkiffEdit.pickKey(title) { marks.adoptPick(key, c) }
    }

    /// A knob turned on the FM-1: show its button's pages and mark it for a few seconds.
    private func follow() {
        guard let t = session.lastTouched, let page = SoundPage.page(session, scope: t.scope, id: t.id) else { return }
        // with the screen link the FM-1's page decides the button; a knob turn only marks its knob
        if !session.screenLinked, ui.soundFamily != page.family, SoundPage.shown(session, page.family).contains(where: { $0.id == page.id }) {
            ui.soundFamily = page.family
        }
        marks.mark("s\(t.scope).\(t.id)")
    }
}

/// Shape's one scroll: the buttons' sections in Skiff's order. A view of its own, so what the page watches (the
/// FM-1's touches, its screen) doesn't rebuild every card.
struct ShapeScroll: View {
    let session: DeviceSession
    let ui: EditorUI
    let marks: ShapeMarks
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = BodyCounter.tick("ShapeScroll")
        let sections = (session.dialect == .skiff ? SoundTab.skiffOrder : SoundTab.order).map { ($0, SoundPage.shown(session, $0)) }.filter { !$0.1.isEmpty }
        // the button is chosen on the pads in the left column, as on the FM-1: it scrolls to its section
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if session.selectedIsDrums, SoundPage.shown(session, ui.soundFamily).isEmpty {
                        DrumNoPages(session: session, ui: ui, family: ui.soundFamily)
                    }
                    ForEach(sections, id: \.0) { family, _ in
                        ShapeSection(session: session, ui: ui, marks: marks, family: family)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: ui.soundFamily) { _, f in
                // the focused page's card when it's this button's (a press steps them), else the section
                let card = ui.focusedPage.flatMap { SoundPage.cardID(of: $0.id, session) }.flatMap { $0.hasPrefix(f.rawValue + ".") ? $0 : nil }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    if let card { proxy.scrollTo(card, anchor: .top) } else { proxy.scrollTo(f, anchor: .top) }
                }
            }
            .onChange(of: ui.focusedPage) { _, f in
                guard let f, let card = SoundPage.cardID(of: f.id, session) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(card, anchor: .top) }
            }
            .onAppear { proxy.scrollTo(ui.soundFamily, anchor: .top) }
        }
    }

}

/// One button's section of Shape: its pages in Skiff's order, merged pages as one card, `columns` to a row (two on
/// the Shape tab, one in the Song tab's sound panel). A view of its own so it can move between them unchanged.
struct ShapeSection: View {
    let session: DeviceSession
    let ui: EditorUI
    let marks: ShapeMarks
    let family: SoundFamily
    var columns = 2
    var showsHeader = true

    var body: some View {
        let pages = SoundPage.shown(session, family)
        // the cards: a page alone, or a page with the ones merged into it
        var cards: [[SoundPage]] = []
        for p in pages {
            if SoundTab.merged.values.contains(where: { $0.contains(p.title) }),
               let k = cards.firstIndex(where: { SoundTab.merged[$0[0].title]?.contains(p.title) == true }) {
                cards[k].append(p)
            } else {
                cards.append([p])
            }
        }
        let lit = ui.soundFamily == family
        return VStack(alignment: .leading, spacing: 10) {
            if showsHeader {
                HStack(spacing: 8) {
                    Text(family.rawValue).font(.lupe(13, .semibold)).tracking(0.6)
                        .foregroundStyle(lit ? Theme.text : Theme.textSecondary)
                    Rectangle().fill(Theme.stepEmpty).frame(height: 1)
                }
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("\(family.rawValue) button")
            }
            if family == .sel, !session.selectedIsDrums { KeyMapStrip(session: session) }
            // a plain grid: a lazy one kept stale positions when the strip above it changed height
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach(Array(stride(from: 0, to: cards.count, by: columns)), id: \.self) { i in
                    GridRow(alignment: .top) {
                        ForEach(0..<columns, id: \.self) { k in
                            if i + k < cards.count {
                                SoundCard(session: session, ui: ui, rows: cards[i + k], pages: pages, marks: marks).equatable()
                            } else { Color.clear.gridCellUnsizedAxes([.vertical]) }
                        }
                    }
                }
            }
        }
        .id(family)
    }
}

/// One card of Shape: a page's columns (or merged pages' rows) over its graph. A view of its own, so a change that
/// concerns one card (a parameter, the knob just turned) redraws that card, not the page.
struct SoundCard: View, Equatable {
    let session: DeviceSession
    let ui: EditorUI
    let rows: [SoundPage]
    let pages: [SoundPage]
    let marks: ShapeMarks
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The highlight moving between cards: Skiff's quick ease-out (about 135–200 ms), beside a carousel's snap.
    static let focusMove: Animation = .easeOut(duration: 0.18)

    /// The same pages with the same state objects: nothing to redraw from the parent (what the card shows it
    /// observes itself), so a rebuilt scroll doesn't rebuild every card.
    nonisolated static func == (a: SoundCard, b: SoundCard) -> Bool {
        a.session === b.session && a.ui === b.ui && a.marks === b.marks
            && a.rows.map(\.id) == b.rows.map(\.id) && a.rows.map(\.ids) == b.rows.map(\.ids) && a.pages.map(\.fw) == b.pages.map(\.fw)
    }

    var body: some View {
        let _ = BodyCounter.tick("card")
        let first = rows[0]
        // (what follows the FM-1's screen and the focused page, the LED, the badge, the row keys, the lit edge and
        // the lift, are views of their own: a page change redraws them, not the card's columns and graph, 2026-11-06)
        return VStack(alignment: .leading, spacing: 10) {
            CardHeader(session: session, ui: ui, rows: rows, pages: pages, marks: marks)
            if first.title == "MOD", !first.routes.isEmpty {
                ModColumns(session: session, ui: ui, page: first, route: modRoute(first), marked: marks.key,
                           activate: { touch(first) })
            } else if ["LANES", "LANE MIX"].contains(first.title), !first.picks.isEmpty {
                LaneColumns(session: session, ui: ui, page: first, lane: pick(first), marked: marks.key, activate: { touch(first) })
            } else if session.dialect == .skiff, first.title == "SOUND" {
                DXSoundPage(session: session, ui: ui, page: first, lane: pick(first), activate: { touch(first) })
            } else if session.dialect == .skiff, first.title == "SAMPLES" {
                SampleMixPage(session: session, ui: ui, page: first, sample: pick(first), activate: { touch(first) })
            } else if session.dialect == .skiff, first.title == "OPERATOR" {
                FM6OperatorPage(session: session, ui: ui, page: first, op0: pick(first), activate: { touch(first) })
            } else if session.dialect == .skiff, first.title == "ALL OPS" {
                FM6AllOpsPage(session: session, ui: ui, page: first, op0: marks.pick("op"), activate: { touch(first) })
            } else {
                ForEach(rows.indices, id: \.self) { r in
                    let p = rows[r]
                    HStack(spacing: 4) {
                        if rows.count > 1 {
                            RowKey(session: session, marks: marks, rows: rows, row: r) { activate(p) }
                        }
                        columns(p)
                    }
                    .fixedSize(horizontal: false, vertical: true)   // the columns' own height: an empty one matches them
                    .environment(\.knobsRecording, session.recordingKnobs && p.scope == 0)
                }
            }
            ForEach(first.settings, id: \.self) { id in PageSetting(session: session, scope: first.scope, id: id) }
            if session.dialect == .skiff, first.title == "SLICES" { SlicesNote(session: session, page: first) }
            graph(for: first, rows: rows)
        }
        .padding(16)
        .panel()
        .modifier(CardForward(session: session, ui: ui, rows: rows))
        // a tap anywhere on an inactive card makes it the active one (on the FM-1 too); touching a column does as well
        // (read when tapped, not while drawing: the card's body doesn't follow the FM-1's page)
        .contentShape(Rectangle())
        .onTapGesture { if !rows.contains(where: { isActive($0) }) { activate(first) } }
        .accessibilityAction(named: "Show on the FM-1") { activate(first) }
        .id(first.id)
    }

    /// A page's four columns, as Skiff's cards; the column of the knob just turned is white; red rings while Skiff
    /// records the track's knob moves.
    private func columns(_ p: SoundPage) -> some View {
        ForEach(0..<4, id: \.self) { slot in
            if let id = p.ids[slot] {
                let sc = p.scope(of: slot)
                KnobControl(ui: ui, activate: { touch(p) },
                            column: (slot + 1, sc == 1 ? Theme.text : Theme.track[session.selectedTrack], marks.key == p.key(slot))) {   // (shared: white)
                    var k = KnobSpec.param(session, scope: sc, id: id, slot: slot, label: p.knobLabels[safe: slot] ?? nil)
                    if Self.deadWhileStrumOff(session, p, slot) {
                        k.dead = true
                        k.spoken += ", does nothing while STRUM is off"
                    }
                    return k
                }
            } else {
                EmptyColumn()
            }
        }
    }

    /// (Skiff 2.5, ui_draw.c card_dead) SCL › CHORD's DIR (knob 4) does nothing while STRUM (knob 3) is OFF.
    static func deadWhileStrumOff(_ session: DeviceSession, _ p: SoundPage, _ slot: Int) -> Bool {
        guard slot == 3, p.title == "CHORD", session.skiffFirmware?.hasDelayMode == true, let strum = p.ids[2] ?? nil else { return false }
        return session.cell(strum).value == 0
    }

    private func onDevice(_ p: SoundPage) -> Bool { Self.onDevice(session, p) }
    static func onDevice(_ session: DeviceSession, _ p: SoundPage) -> Bool {
        session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == p.fw } == true
    }
    /// The page the knobs work on: the FM-1's, or (not linked) the one last tapped here.
    private func isActive(_ p: SoundPage) -> Bool { Self.isActive(session, marks, p) }
    static func isActive(_ session: DeviceSession, _ marks: ShapeMarks, _ p: SoundPage) -> Bool {
        session.screenLinked ? onDevice(session, p) : marks.activePage == p.id
    }
    /// A column touched: its page becomes the active one; true when it already was.
    private func touch(_ p: SoundPage) -> Bool {
        let was = isActive(p)
        if !was { activate(p) }
        return was
    }

    private func activate(_ p: SoundPage) {
        marks.activePage = p.id
        if session.screenLinked { session.showOnDevice(page: p.fw) }
    }

    /// The page's graph, as Skiff draws it under the cards (PageGraph): ENV's curve, the LFO running, DRIVE…
    @ViewBuilder private func graph(for p: SoundPage, rows: [SoundPage]) -> some View {
        // the knob being turned, here or on the FM-1 (marked), lights its point
        let turning = ui.knobGrab.flatMap { g in p.ids.indices.first { p.key($0) == g.id } }
            ?? marks.key.flatMap { m in p.ids.indices.first { p.key($0) == m } }
        if PageGraph.has(p, session) { PageGraph(session: session, page: p, rows: rows, hot: turning, modRoute: modRoute(p)) }
    }

    /// KNOB 1's pick on an engine page (the lane, …): picked here, the FM-1's cursor goes there too, as MOD's route.
    private func pick(_ p: SoundPage) -> Binding<Int> {
        let key = SkiffEdit.pickKey(p.title) ?? p.title
        return Binding(get: { marks.pick(key) }, set: { v in
            guard v != marks.pick(key) else { return }
            marks.pick(key, v)
            if session.screenCursor { session.showOnDevice(page: p.fw, cursor: v) }
        })
    }

    /// MOD's route: picked here, the FM-1's cursor goes there too (and MOD opens on it), where the link carries
    /// the cursor; the FM-1's own turns come in through SoundTab.followScreen.
    private func modRoute(_ p: SoundPage) -> Binding<Int> {
        Binding(get: { marks.modRoute }, set: { v in
            guard v != marks.modRoute else { return }
            marks.pickRoute(v)
            if session.screenCursor { session.showOnDevice(page: p.fw, cursor: v) }
        })
    }

}

/// A card's header: the LED (the FM-1's page, or the knob just turned), the title, "On the FM-1 · 2/3", "all tracks".
private struct CardHeader: View {
    let session: DeviceSession
    let ui: EditorUI
    let rows: [SoundPage]
    let pages: [SoundPage]
    let marks: ShapeMarks

    var body: some View {
        let first = rows[0]
        let onDeviceRow = rows.firstIndex { SoundCard.onDevice(session, $0) }
        let marked = marks.key
        let lit = rows.contains { p in marked != nil && (p.ids.indices.contains { p.key($0) == marked }
            || p.routes.joined().contains { id in id.map { "s\(p.scope).\($0)" } == marked }) }
        HStack(spacing: 8) {
            LED(on: session.screenLinked ? onDeviceRow != nil : lit)
            Text(rows.count > 1 ? rows.map { $0.title(session) }.joined(separator: " · ") : first.title(session))
                .font(.lupe(15, .semibold))
            if let r = onDeviceRow, case let counted = SoundPage.counted(pages, session),
               let k = counted.firstIndex(where: { $0.fw == rows[r].fw }) {
                // the page the FM-1 shows, counted as its screen counts them ("FX 1/7")
                Text("On the FM-1 · \(k + 1)/\(counted.count)")
                    .font(.lupe(12, .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.10)))
            }
            if first.scope == 1 {
                Text("all tracks").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
            } else if first.mixed {
                // FX › DELAY, REVERB: the send is this track's, the bus every track's (white columns, as GLO's)
                Text("send: this track · bus: all tracks").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(onDeviceRow != nil ? "on the FM-1" : "")
    }
}

/// A merged card's row key (LFO, LFO 2): tap it to focus the row; the FM-1's knobs follow the focused row.
private struct RowKey: View {
    let session: DeviceSession
    let marks: ShapeMarks
    let rows: [SoundPage]
    let row: Int
    let activate: () -> Void

    var body: some View {
        let p = rows[row]
        let focused = (rows.firstIndex { SoundCard.isActive(session, marks, $0) } ?? 0) == row
        Button { activate() } label: {
            Text(p.title).font(.lupe(11, .semibold)).tracking(0.4)
                .foregroundStyle(focused ? Theme.onColour : Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: 52).frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 6).fill(focused ? Theme.text : Theme.control))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.title) row")
        .accessibilityAddTraits(focused ? .isSelected : [])
        .accessibilityHint("Puts the FM-1's knobs on this row")
    }
}

/// The card brought forward: the FM-1's page when linked, else the one focused here: lifted a little and lit along the
/// top, the two together in one crossfade from the card before (they jumped, 2026-11-06, on two triggers of their own).
private struct CardForward: ViewModifier {
    let session: DeviceSession
    let ui: EditorUI
    let rows: [SoundPage]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let focused = ui.focusedPage.map { f in rows.contains { $0.id == f.id } } ?? false
        let forward = session.screenLinked ? rows.contains { SoundCard.onDevice(session, $0) } : focused
        content
            // the lift as a shape's shadow behind the card, not the card's own: a shadow on the content was drawn
            // offscreen again every time the content changed (a graph redrawing as a knob turns: Reverb, 2026-11-06)
            .background {
                RoundedRectangle(cornerRadius: 14).fill(Theme.panel)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                    .opacity(forward ? 1 : 0)
                    .animation(reduceMotion ? nil : SoundCard.focusMove, value: forward)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1.5).fill(Theme.text)
                    .frame(height: 3)
                    .padding(.horizontal, 14)
                    .offset(y: 1)                    // on the panel's top edge
                    .opacity(forward ? 1 : 0)
                    .animation(reduceMotion ? nil : SoundCard.focusMove, value: forward)
                    .accessibilityHidden(true)
            }
    }
}

/// The knob last turned on the FM-1, lit as long as Skiff lights it (ui.hot_t = 40 frames, about 600 ms). Set only
/// when it changes, so an encoder's stream of pushes doesn't redraw every card.
@Observable @MainActor final class ShapeMarks {
    private(set) var key: String?
    /// Not linked: the page last tapped here (linked, the FM-1's page is the active one).
    var activePage: String?
    /// MOD's KNOB 1: the route shown, 0…10 (Skiff's mod_ui_route; the FM-1's own with the screen link's cursor).
    private(set) var modRoute = 0
    /// When a route was last picked here: the FM-1's answers to the picks before it (one SCREEN_GOTO each, a
    /// drag sends several) don't pull the knob back while it's still moving.
    @ObservationIgnored private var routePicked = Date.distantPast

    func pickRoute(_ r: Int) { modRoute = r; routePicked = .now }

    /// KNOB 1's pick on the engine pages (SkiffEdit.pickKey: the lane, the sample, the operator), as modRoute is MOD's.
    private(set) var picks: [String: Int] = [:]
    @ObservationIgnored private var picked: [String: Date] = [:]
    func pick(_ key: String) -> Int { picks[key] ?? 0 }
    func pick(_ key: String, _ v: Int) { if picks[key] != v { picks[key] = v }; picked[key] = .now }
    /// The FM-1's cursor for this pick: taken unless it was picked here in the last half second.
    func adoptPick(_ key: String, _ v: Int) {
        guard Date.now.timeIntervalSince(picked[key] ?? .distantPast) > 0.5, picks[key] != v else { return }
        picks[key] = v
    }
    /// The FM-1's cursor on MOD: taken unless a route was picked here in the last half second.
    func adoptRoute(_ r: Int) {
        guard Date.now.timeIntervalSince(routePicked) > 0.5, r != modRoute, (0...10).contains(r) else { return }
        modRoute = r
    }
    @ObservationIgnored private var gen = 0

    func mark(_ k: String) {
        if key != k { key = k }
        gen += 1
        let g = gen
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if self.gen == g { self.key = nil }
        }
    }
}

/// Watches the FM-1's knob touches (every push while an encoder turns) in a view that draws nothing.
struct TouchFollower: View {
    let session: DeviceSession
    let touched: () -> Void
    var body: some View {
        Color.clear.onChange(of: session.lastTouched?.at) { _, _ in touched() }
    }
}

/// SEL: what each of the FM-1's 27 keys plays now (root, scale, SNAP / WHITE, transpose, OCT), the
/// thing the device's SEL pages change but its screen can't show all at once. In chord mode each white
/// key plays a chord of the scale: tap one to light its notes across the keys; the black keys are
/// labelled with how they change it (SLOOP's CHORD+), as the FM-1's SEL layer lights them.
struct KeyMapStrip: View {
    let session: DeviceSession
    @State private var picked: Int?            // chord mode: the white key whose chord is shown

    var body: some View {
        let t = session.tracks[session.selectedTrack]
        let chordMode = t.chord != 0 && !session.selectedIsDrums
        let key = picked ?? KeyboardDrawer.whiteOffsets.first { session.pitch(ofKey: $0) != nil } ?? 0
        // (Skiff's QNT SOLO: a black key plays its note alone, never a chord; seq.c kb_solo)
        let solo = skiff && t.quant == 5 && !KeyboardDrawer.whiteOffsets.contains(key)
        let chord = chordMode ? session.pitch(ofKey: key).map { solo ? [$0] : chordNotes(on: $0, t) } ?? [] : []
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("What the FM-1's keys play").font(.lupe(15, .semibold))
                Text(chordMode ? chordLine(t)
                     : t.quant == 2 ? "white keys walk the scale" : t.quant == 1 ? "snapped to the scale" : "every key, chromatic")
                    .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            GeometryReader { geo in
                let w = geo.size.width / 16
                ZStack(alignment: .topLeading) {
                    ForEach(KeyboardDrawer.blackAfter, id: \.self) { k in
                        keyCell(KeyboardDrawer.whiteOffsets[k] + 1, t: t, chordMode: chordMode, chord: chord, picked: key)
                            .frame(width: w - 6, height: 34)
                            .offset(x: CGFloat(k + 1) * w - (w - 6) / 2)
                    }
                    ForEach(0..<16, id: \.self) { k in
                        keyCell(KeyboardDrawer.whiteOffsets[k], t: t, chordMode: chordMode, chord: chord, picked: key)
                            .frame(width: w - 6, height: 34)
                            .offset(x: CGFloat(k) * w + 3, y: 40)
                    }
                }
            }
            .frame(height: 74)
            // the picked key's chord, spelled out; the line is always there (empty without chords), so
            // turning CHORD on or off never moves the pages below
            if chordMode {
                HStack(spacing: 8) {
                    Text(session.pitch(ofKey: key).map(Music.noteName) ?? "–").font(.lupe(13, .semibold))
                    Text("plays").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                    Text(chord.map(Music.noteName).joined(separator: " · ")).font(.lupe(13, .semibold))
                    if let n = skiffChord(t, key: key) { Text(n).font(.lupe(13, .semibold)).foregroundStyle(Theme.textSecondary) }
                    Text(skiff ? "Tap a key to see its chord." : "Tap a white key to see its chord.").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .frame(height: 18)
                .accessibilityElement(children: .combine)
            } else {
                Color.clear.frame(height: 18).accessibilityHidden(true)
            }
        }
        .padding(16)
        .panel()
        .padding(.bottom, 16)
        .accessibilityElement(children: .contain)
        .onChange(of: session.selectedTrack) { _, _ in picked = nil }
    }

    /// A key: the note it plays, lit when it's the root (or, in chord mode, a note of the picked chord);
    /// silent keys are blank; in chord mode the black keys say what they do.
    @ViewBuilder private func keyCell(_ key: Int, t: TrackState, chordMode: Bool, chord: [Int], picked: Int) -> some View {
        let p = session.pitch(ofKey: key)
        let black = !KeyboardDrawer.whiteOffsets.contains(key)
        let lit = chordMode ? p.map { chord.contains($0) } ?? false : p.map { (($0 - t.root) % 12 + 12) % 12 == 0 } ?? false
        // SLOOP's black keys change the chord (CHORD+); Skiff's play one too, as every key does
        let modifier = chordMode && black && !skiff
        let label = modifier ? (Music.chordModifier(ofKey: key) ?? "") : (p.map(Music.noteName) ?? "")
        let cell = Text(label)
            .font(.lupe(modifier ? 11 : 12, lit ? .semibold : .regular))
            .foregroundStyle(lit ? Theme.onColour : modifier ? Theme.textSecondary : Theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(lit ? Theme.track[session.selectedTrack] : Color(hex: 0x232427)))
            .overlay { if chordMode && key == picked { RoundedRectangle(cornerRadius: 9).stroke(Theme.text, lineWidth: 2).padding(-2) } }
            .opacity(p == nil && !modifier ? 0.35 : 1)
        if chordMode && !modifier && p != nil {
            Button { self.picked = key } label: { cell.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.map(Music.spokenNoteName) ?? "") chord")
                .accessibilityAddTraits(key == picked ? .isSelected : [])
        } else {
            cell.accessibilityLabel(modifier ? "Black key: \(label)" : (p.map(Music.spokenNoteName) ?? "silent"))
        }
    }

    // MARK: Chords as the firmware builds them: Skiff's chord.c (SkiffChord) or SLOOP's

    private var skiff: Bool { session.dialect == .skiff }
    private func value(_ title: String, _ k: Int) -> Int {
        (SoundPage.pages(session).first { $0.title == title }?.ids[safe: k] ?? nil).map { session.cell($0).value } ?? 0
    }
    /// Skiff: one voice (MONO, LEG, UNI with the ARP off) plays the chord's root alone, as chord_make does.
    private var oneVoice: Bool { value("VOICE", 0) != 0 && value("ARP", 0) == 0 }

    private func chordNotes(on p: Int, _ t: TrackState) -> [Int] {
        guard skiff else { return Music.chordNotes(on: p, root: t.root, scale: t.scale, type: t.chord) }
        return SkiffChord.make(note: p, mode: t.chord, voicing: value("CHORD", 1), root: t.root, scale: t.scale, oneVoice: oneVoice)?.notes ?? []
    }
    /// The picked key's chord by name, as the FM-1 writes it ("Dm7"); nil on SLOOP.
    private func skiffChord(_ t: TrackState, key: Int) -> String? {
        guard skiff, let p = session.pitch(ofKey: key),
              let c = SkiffChord.make(note: p, mode: t.chord, voicing: value("CHORD", 1), root: t.root, scale: t.scale) else { return nil }
        return SkiffChord.name(root: c.root, mask: c.mask)
    }
    private func chordLine(_ t: TrackState) -> String {
        guard skiff else { return "chord mode: each white key plays a \(Music.chordNames[safe: t.chord] ?? "chord"); the black keys change it" }
        let what = "chord keys: every key plays its \(SkiffChord.modeNames[safe: t.chord] ?? "chord") chord, \(SkiffChord.voicingNames[safe: value("CHORD", 1)] ?? "CLOSE")"
        return oneVoice ? what + " (one voice: the root only)" : what
    }
}

/// A page's setting that isn't a knob (Skiff 2.5's GLO › DELAY: DLY MODE, MONO STEREO PING), as the FM-1 has it on
/// the page's PRESETS card: its name, then its choices as segmented keys, under the page's columns. Its own view, so a
/// change redraws this row alone.
struct PageSetting: View {
    let session: DeviceSession
    let scope: Int
    let id: Int

    var body: some View {
        let d = scope == 0 ? session.trackDesc(id) : session.globalDescs[id]
        let v = scope == 0 ? session.cell(id).value : session.globalCell(id).value
        let names = d?.names ?? []
        if !names.isEmpty {
            HStack(spacing: 12) {
                Text(Self.title(d?.label ?? "")).font(.lupe(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
                SegmentedKeys(label: Self.title(d?.label ?? ""), options: names, selected: v - (d?.min ?? 0), minWidth: 72) { k in
                    let nv = k + (d?.min ?? 0)
                    if scope == 0 { session.set(track: session.selectedTrack, param: id, to: nv) } else { session.set(global: id, to: nv) }
                }
                .font(.lupe(13))
                Spacer(minLength: 0)
            }
        }
    }

    /// "DLY MODE" on a DELAY card says MODE: the card already names the delay.
    static func title(_ label: String) -> String { label.hasPrefix("DLY ") ? String(label.dropFirst(4)) : label }
}
