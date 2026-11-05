import SloopKit
import SwiftUI

/// Pass 1 step 4: shape the selected track's sound. The FM-1's function buttons along the top; each
/// button's pages laid out flat, every page as its four knobs in the device's knob colours. Turning
/// a knob on the FM-1 brings its button's pages up here and marks the knob (the protocol reports the
/// parameter that changed, not the page or button pressed).

enum SoundFamily: String, CaseIterable, Identifiable {
    case fx = "FX", sel = "SEL", env = "ENV", lfo = "LFO", edit = "EDIT", glo = "GLO", arp = "ARP", seq = "SEQ"
    var id: String { rawValue }
}

/// Where the screen link points, per firmware: the pages Jib's tabs open on the FM-1, and the layer that
/// is the keys' (SLOOP: SEL held, LY_SCALE; Skiff: SCL held). SLOOP's PAGES, or Skiff's (127: HOME).
struct ScreenMap {
    let home, presets, song, notes, pattern, selLayer: Int
    static let sloop = ScreenMap(home: 37, presets: 28, song: 30, notes: 34, pattern: 35, selLayer: 5)
    static let skiff = ScreenMap(home: 127, presets: 35, song: 45, notes: 41, pattern: 43, selLayer: 3)
    @MainActor static func of(_ s: DeviceSession) -> ScreenMap { s.dialect == .skiff ? .skiff : .sloop }
}

/// One page of the FM-1 (firmware params.c PAGES): its title, button, and the parameter under each
/// knob (nil: an empty knob). scope 0 = the track's P_*, 1 = global G_*.
struct SoundPage: Identifiable {
    /// Its index in SLOOP's PAGES table (params.c): what the fm1-ipad firmware reports and opens.
    let fw: Int
    let title: String
    let family: SoundFamily
    let scope: Int
    let ids: [Int?]
    var drums = false            // the drum track has this page too (params.c page_for_drum)
    var analogOnly = false       // EDIT > FILTER: ANALOG only (page_shown)
    var engineEdit = 0           // 1 / 2: EDIT 1 / EDIT 2, titled by the engine (NAMES)
    var routes: [[Int?]] = []    // Skiff's MOD: its eleven routes' parameters (PageSpec.routes)
    var id: String { "\(family.rawValue).\(title)" }

    static let all: [SoundPage] = [
        SoundPage(fw: 5, title: "FX", family: .fx, scope: 0, ids: [33, 34, 35, 36]),
        SoundPage(fw: 6, title: "FILTER", family: .fx, scope: 0, ids: [50, nil, nil, nil], drums: true),
        SoundPage(fw: 7, title: "SLICER", family: .fx, scope: 0, ids: [45, 46, 47, 48], drums: true),
        SoundPage(fw: 8, title: "INSERT", family: .fx, scope: 0, ids: [53, 54, 55, 56], drums: true),
        SoundPage(fw: 9, title: "INSERT 2", family: .fx, scope: 0, ids: [57, nil, nil, nil], drums: true),
        SoundPage(fw: 10, title: "DLY", family: .fx, scope: 1, ids: [4, 5, 6, 7], drums: true),
        SoundPage(fw: 11, title: "REV/CHO", family: .fx, scope: 1, ids: [8, 9, 10, 11], drums: true),
        SoundPage(fw: 12, title: "SEL", family: .sel, scope: 0, ids: [25, 26, 27, 49]),
        SoundPage(fw: 13, title: "SEL 2", family: .sel, scope: 0, ids: [28, 51, 52, nil]),
        SoundPage(fw: 0, title: "ENV", family: .env, scope: 0, ids: [1, 2, 3, 4]),
        SoundPage(fw: 1, title: "ENV DEST", family: .env, scope: 0, ids: [5, 6, 7, 59]),
        SoundPage(fw: 2, title: "LFO", family: .lfo, scope: 0, ids: [9, 10, 11, 12]),
        SoundPage(fw: 3, title: "LFO 2", family: .lfo, scope: 0, ids: [60, 61, 62, nil]),
        SoundPage(fw: 4, title: "LFO DEST", family: .lfo, scope: 0, ids: [13, 14, 15, 16]),
        SoundPage(fw: 14, title: "EDIT 1", family: .edit, scope: 0, ids: [63, 64, 65, 66], engineEdit: 1),
        SoundPage(fw: 15, title: "EDIT 2", family: .edit, scope: 0, ids: [67, 68, 69, 70], engineEdit: 2),
        SoundPage(fw: 16, title: "FILTER", family: .edit, scope: 0, ids: [58, 67, 68, 70], analogOnly: true),
        SoundPage(fw: 17, title: "VOICE", family: .edit, scope: 0, ids: [37, 38, 41, 42]),
        SoundPage(fw: 18, title: "VOICE 2", family: .edit, scope: 0, ids: [43, 44, 39, 40]),
        SoundPage(fw: 19, title: "GLOBAL", family: .glo, scope: 1, ids: [0, 1, 2, 3], drums: true),
        SoundPage(fw: 20, title: "MASTER", family: .glo, scope: 1, ids: [27, 28, 29, 30], drums: true),
        SoundPage(fw: 22, title: "DRUMS", family: .glo, scope: 1, ids: [24, 25, 26, 32], drums: true),
        SoundPage(fw: 26, title: "TEXTURE", family: .glo, scope: 1, ids: [37, 38, 39, 40], drums: true),
        SoundPage(fw: 27, title: "TEXTURE 2", family: .glo, scope: 1, ids: [41, 42, 43, nil], drums: true),
        SoundPage(fw: 21, title: "SYSTEM", family: .glo, scope: 1, ids: [12, 13, 14, 15], drums: true),
        SoundPage(fw: 23, title: "MIDI", family: .glo, scope: 1, ids: [33, 34, 35, 24], drums: true),
        SoundPage(fw: 24, title: "MIDI 2", family: .glo, scope: 1, ids: [14, 36, 12, 44], drums: true),
        SoundPage(fw: 25, title: "MIDI 3", family: .glo, scope: 1, ids: [45, 46, 47, 48], drums: true),
        SoundPage(fw: 32, title: "ARP", family: .arp, scope: 0, ids: [17, 18, 19, 20]),
        SoundPage(fw: 33, title: "ARP 2", family: .arp, scope: 0, ids: [21, 22, 23, 24]),
        SoundPage(fw: 35, title: "PATTERN", family: .seq, scope: 0, ids: [29, 30, 31, 32], drums: true),
    ]

    /// The connected firmware's pages: its own layout where it gives one (Skiff, from DESC), else SLOOP's.
    @MainActor
    static func pages(_ session: DeviceSession) -> [SoundPage] {
        guard let layout = session.pageLayout else { return all }
        var used = Set<Int>()
        return layout.enumerated().map { k, p in
            // Skiff's own PAGES index where one of its pages is this one (the screen link reports and opens
            // those); the rest past every table, never the screen link's
            var fw = 100 + k
            if session.dialect == .skiff, let d = skiffPages[p.title], !used.contains(d) { fw = d; used.insert(d) }
            return SoundPage(fw: fw, title: p.title, family: SoundFamily(rawValue: p.family) ?? .edit, scope: p.scope,
                             ids: p.ids, engineEdit: p.engineEdit, routes: p.routes)
        }
    }

    /// Skiff 2.2's PAGES (fm1-ipad skiff/README.md) for the pages Jib lays out: title → index. MOD's four
    /// PATTERN 2's knob is on PATTERN. The table belongs with the firmware version.
    static let skiffPages: [String: Int] = [
        "ENV": 0, "ENV 2": 1, "LFO": 2, "LFO 2": 3, "MOD": 4, "FX": 5, "DRIVE": 6, "INSERT": 7, "INSERT 2": 8,
        "SLICER": 9, "DUCK": 10, "SCALE": 11, "CHORD": 12, "FOLLOW": 13, "EDIT 1": 14, "EDIT 2": 15,
        "VOICE": 28, "VOICE 2": 29, "DELAY": 31, "REVERB": 32, "CHORUS": 33, "GLOBAL": 34, "ARP": 39, "ARP 2": 40,
        "PATTERN": 43,
    ]

    @MainActor
    static func shown(_ session: DeviceSession, _ family: SoundFamily) -> [SoundPage] {
        let t = session.tracks[session.selectedTrack]
        return pages(session).filter { p in
            p.family == family && (!t.isDrums || p.drums) && (!p.analogOnly || (!t.isDrums && t.engine == 0))
        }
    }

    static func page(fw: Int) -> SoundPage? { all.first { $0.fw == fw } }

    /// The page the FM-1's screen is on, in the connected firmware's terms. Skiff's engine pages (16–27:
    /// OPERATOR, LANES, SOUND…), which Jib shows as EDIT 1 and 2, stand for the EDIT button.
    @MainActor static func page(_ session: DeviceSession, fw: Int) -> SoundPage? {
        if session.dialect == .skiff, (16...27).contains(fw) { return pages(session).first { $0.family == .edit } }
        return pages(session).first { $0.fw == fw }
    }

    /// The pages a button opens on the FM-1 for the selected track: its own, or on the drum track for a
    /// button without drum pages, the synth pages the FM-1 shows as "DRUM TRACK" (params.c page_for_drum).
    @MainActor static func reached(_ session: DeviceSession, _ family: SoundFamily) -> [SoundPage] {
        let own = shown(session, family)
        guard own.isEmpty, session.selectedIsDrums else { return own }
        return pages(session).filter { $0.family == family && !$0.analogOnly && !$0.drums }
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

    /// The page a parameter is on, the first one when it appears on several (as MIDI's channels do).
    @MainActor
    static func page(_ session: DeviceSession, scope: Int, id: Int) -> SoundPage? {
        pages(session).first { $0.scope == scope && ($0.ids.contains(id) || $0.routes.joined().contains(id)) && !$0.analogOnly }
    }

    @MainActor
    func title(_ session: DeviceSession) -> String {
        guard engineEdit > 0 else { return title }
        let e = session.tracks[session.selectedTrack].engine
        let t = session.editPageTitles[e] ?? []
        let name = engineEdit - 1 < t.count ? t[engineEdit - 1] : ""
        return name.isEmpty ? title : "\(title) · \(name)"
    }
}

/// A parameter's value as text, as the FM-1 shows it (EDITOR_PROTOCOL.md "fmt"; the curves for TIME,
/// LFOHZ, CUTOFF and DB are SLOOP's own, in DeviceDisplay).
func formatValue(_ d: ParamDesc?, _ v: Int) -> (shown: String, spoken: String) {
    guard let d else { return ("\(v)", "\(v)") }
    // as the FM-1's screen: its curves for times, rates, cutoffs and levels, and name lists on numbers
    if let (text, u) = DeviceDisplay.value(d, v) {
        let shown = u.isEmpty ? text : u == "%" ? "\(text)%" : "\(text) \(u)"
        let spoken = u == "%" ? "\(text) percent" : u == "dB" ? "\(text) decibels" : shown
        return (shown, spoken)
    }
    let unit = d.unit.isEmpty ? "" : " \(d.unit.lowercased())"
    switch d.format {
    case 2: let p = Int((Double(v) * 100 / 64).rounded()); return (p > 0 ? "+\(p)%" : "\(p)%", "\(p) percent")
    case 7: return (v > 0 ? "+\(v) st" : "\(v) st", "\(v) semitones")
    case 8:
        let k = v - d.min
        let n = k >= 0 && k < d.names.count ? d.names[k] : "\(v)"
        return (n, n.lowercased())
    case 10: return (Music.noteNames[((v % 12) + 12) % 12], Music.spokenNoteNames[((v % 12) + 12) % 12])
    case 11: return (v != 0 ? "ON" : "OFF", v != 0 ? "on" : "off")
    case 12: return (v > 0 ? "+\(v)" : "\(v)", "octave \(v)")
    case 14: let p = 50 + v / 4; return ("\(p)%", "\(p) percent swing")
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
    static func param(_ session: DeviceSession, scope: Int, id: Int, slot: Int) -> KnobSpec {
        let d = scope == 0 ? session.trackDesc(id) : session.globalDescs[id]
        let values = scope == 0 ? session.params : session.globals
        // locking knob turns to a step (Skiff): the knob shows that step's lock, if it has one
        let locked = scope == 0 ? session.lockStep.flatMap { s in session.motion[session.selectedTrack]?.events.first { $0.lock && $0.step == s && $0.id == id }?.value } : nil
        let v = locked ?? (id < values.count ? values[id] : 0)
        let lo = d?.min ?? 0, hi = max(d?.max ?? 127, lo)
        let f = formatValue(d, v)
        let t = session.selectedTrack
        return KnobSpec(id: "s\(scope).\(id)", colour: Theme.knob[slot % 4], label: d?.label ?? "–", value: v,
                        range: lo...hi, stepperStep: max(1, (hi - lo) / 16), shown: f.shown, spoken: f.spoken,
                        bipolar: d?.format == 2 || d?.format == 15 || (lo < 0 && hi > 0),
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
                    .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
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
    @State private var marked: String?          // the knob last turned on the FM-1, marked for a moment
    @State private var followed: UIState?       // the FM-1's screen as last followed
    @State private var activePage: String?      // not linked: the page last tapped here (linked, the FM-1's page)
    @State private var modRoute = 0             // MOD's KNOB 1: the route shown, 0…10 (Skiff's mod_ui_route)

    /// The FM-1's buttons in the order Skiff's PAGES table lists their pages (params.c): Shape's sections. GLO's
    /// shared effects keep their place after them for now; SEQ's PATTERN pages close the list.
    static let order: [SoundFamily] = [.env, .lfo, .fx, .sel, .edit, .arp, .glo, .seq]
    /// Skiff: GLO is the mixer panel and SEQ's PATTERN the Sequence page's whole-track controls (the button map).
    static let skiffOrder: [SoundFamily] = [.env, .lfo, .fx, .sel, .edit, .arp]
    /// Pages that drive one thing, shown as rows over its one graph: the first page's title → the others'.
    static let merged: [String: [String]] = ["LFO": ["LFO 2"], "INSERT": ["INSERT 2"]]

    var body: some View {
        let sections = (session.dialect == .skiff ? Self.skiffOrder : Self.order).map { ($0, SoundPage.shown(session, $0)) }.filter { !$0.1.isEmpty }
        VStack(alignment: .leading, spacing: 16) {
            EntrySoundNote(session: session)
            // the button is chosen on the pads in the left column, as on the FM-1: it scrolls to its section
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if session.selectedIsDrums, SoundPage.shown(session, ui.soundFamily).isEmpty {
                            DrumNoPages(session: session, ui: ui, family: ui.soundFamily)
                        }
                        ForEach(sections, id: \.0) { family, pages in
                            section(family, pages)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .onChange(of: ui.soundFamily) { _, f in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(f, anchor: .top) }
                }
                .onAppear { proxy.scrollTo(ui.soundFamily, anchor: .top) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)   // the page area fills its column
        .onChange(of: session.lastTouched?.at) { _, _ in follow() }
        .onChange(of: session.deviceScreen) { _, s in followScreen(s) }
        .onAppear {
            // opened by the FM-1: start on its button; opened here (a tab, a pad): keep the choice made
            if ui.pageFromDevice { followScreen(session.deviceScreen) } else { followed = session.deviceScreen }
            ui.pageFromDevice = false
        }
    }

    // MARK: A button's section: its pages in Skiff's order, merged pages as one card

    private func section(_ family: SoundFamily, _ pages: [SoundPage]) -> some View {
        // the cards: a page alone, or a page with the ones merged into it
        var cards: [[SoundPage]] = []
        for p in pages {
            if Self.merged.values.contains(where: { $0.contains(p.title) }),
               let k = cards.firstIndex(where: { Self.merged[$0[0].title]?.contains(p.title) == true }) {
                cards[k].append(p)
            } else {
                cards.append([p])
            }
        }
        let lit = ui.soundFamily == family
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(family.rawValue).font(.system(size: 13, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(lit ? Theme.text : Theme.textSecondary)
                Rectangle().fill(Theme.stepEmpty).frame(height: 1)
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("\(family.rawValue) button")
            if family == .sel, !session.selectedIsDrums { KeyMapStrip(session: session) }
            // a plain grid: a lazy one kept stale positions when the strip above it changed height
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { i in
                    GridRow(alignment: .top) {
                        card(cards[i], of: pages)
                        if i + 1 < cards.count { card(cards[i + 1], of: pages) } else { Color.clear.gridCellUnsizedAxes([.vertical]) }
                    }
                }
            }
        }
        .id(family)
    }

    // MARK: A card: one page's four columns, or rows of merged pages, over the graph

    private func card(_ rows: [SoundPage], of pages: [SoundPage]) -> some View {
        let first = rows[0]
        let onDeviceRow = rows.firstIndex { onDevice($0) }
        let activeRow = rows.firstIndex { isActive($0) }
        let lit = rows.contains { p in marked != nil && (p.ids + p.routes.joined()).contains { id in id.map { "s\(p.scope).\($0)" } == marked } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LED(on: session.screenLinked ? onDeviceRow != nil : lit)
                Text(rows.count > 1 ? rows.map { $0.title(session) }.joined(separator: " · ") : first.title(session))
                    .font(.system(size: 15, weight: .semibold))
                if let r = onDeviceRow, let k = pages.firstIndex(where: { $0.fw == rows[r].fw }) {
                    // the page the FM-1 shows, counted as its screen counts them ("FX 1/7")
                    Text("On the FM-1 · \(k + 1)/\(pages.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.10)))
                }
                if first.scope == 1 {
                    Text("all tracks").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if first.title == "MOD", !first.routes.isEmpty {
                ModColumns(session: session, ui: ui, page: first, route: $modRoute, marked: marked,
                           activate: { touch(first) })
            } else {
                ForEach(rows.indices, id: \.self) { r in
                    let p = rows[r]
                    let focused = rows.count > 1 && (activeRow ?? 0) == r
                    HStack(spacing: 4) {
                        if rows.count > 1 {
                            // the row's page: tap it to focus it (the FM-1's knobs follow the focused row)
                            Button { activate(p) } label: {
                                Text(p.title).font(.system(size: 11, weight: .semibold)).tracking(0.4)
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
                        columns(p)
                    }
                    .fixedSize(horizontal: false, vertical: true)   // the columns' own height: an empty one matches them
                    .environment(\.knobsRecording, session.recordingKnobs && p.scope == 0)
                }
            }
            graph(for: first, rows: rows)
        }
        .padding(16)
        .panel()
        // the page on the FM-1's screen: a lit edge along the top, the playhead's light
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.text)
                .frame(height: 3)
                .padding(.horizontal, 14)
                .offset(y: 1)                    // on the panel's top edge
                .glow(Theme.text.opacity(0.7), radius: 6)
                .opacity(onDeviceRow != nil ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: onDeviceRow != nil)   // the light fades; nothing else animates
                .accessibilityHidden(true)
        }
        .accessibilityValue(onDeviceRow != nil ? "on the FM-1" : "")
        // a tap anywhere on an inactive card makes it the active one (on the FM-1 too); touching a column does as well
        .contentShape(Rectangle())
        .onTapGesture { if activeRow == nil { activate(first) } }
        .accessibilityAction(named: "Show on the FM-1") { activate(first) }
        .id(first.id)
    }

    /// A page's four columns, as Skiff's cards; the column of the knob just turned is white; red rings while Skiff
    /// records the track's knob moves.
    private func columns(_ p: SoundPage) -> some View {
        ForEach(0..<4, id: \.self) { slot in
            if let id = p.ids[slot] {
                KnobControl(ui: ui, activate: { touch(p) },
                            column: (slot + 1, Theme.track[session.selectedTrack], marked == "s\(p.scope).\(id)")) {
                    KnobSpec.param(session, scope: p.scope, id: id, slot: slot)
                }
            } else {
                EmptyColumn()
            }
        }
    }

    private func onDevice(_ p: SoundPage) -> Bool {
        session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == p.fw } == true
    }
    /// The page the knobs work on: the FM-1's, or (not linked) the one last tapped here.
    private func isActive(_ p: SoundPage) -> Bool { session.screenLinked ? onDevice(p) : activePage == p.id }
    /// A column touched: its page becomes the active one; true when it already was.
    private func touch(_ p: SoundPage) -> Bool {
        let was = isActive(p)
        if !was { activate(p) }
        return was
    }

    private func activate(_ p: SoundPage) {
        activePage = p.id
        if session.screenLinked { session.showOnDevice(page: p.fw) }
    }

    /// The page's graph, as Skiff draws it under the cards (PageGraph): ENV's curve, the LFO running, DRIVE…
    @ViewBuilder private func graph(for p: SoundPage, rows: [SoundPage]) -> some View {
        // the knob being turned, here or on the FM-1 (marked), lights its point
        let turning = ui.knobGrab.flatMap { g in p.ids.firstIndex { $0.map { "s\(p.scope).\($0)" } == g.id } }
            ?? marked.flatMap { m in p.ids.firstIndex { $0.map { "s\(p.scope).\($0)" } == m } }
        if PageGraph.has(p) { PageGraph(session: session, page: p, rows: rows, hot: turning, modRoute: $modRoute) }
    }

    /// The FM-1 changed page (a button pressed on it): show that button's pages here. Holding SEL
    /// (its key layer) brings up SEL.
    private func followScreen(_ s: UIState?) {
        // only a real change on the FM-1 moves the page here: the same screen reported again must not
        // undo a button chosen on the iPad (on the drum track SEL, ENV, LFO, EDIT, ARP can't move the
        // FM-1, which stays on its page)
        guard let s, s.home != followed?.home || s.page != followed?.page || s.layer != followed?.layer else { return }
        followed = s
        if s.layer == ScreenMap.of(session).selLayer { ui.soundFamily = .sel; return }   // the keys' layer held
        // (on the drum track the FM-1 opens the synth pages too, showing "DRUM TRACK": follow those as well)
        guard !s.home, let page = SoundPage.page(session, fw: s.page),
              SoundPage.reached(session, page.family).contains(where: { $0.fw == page.fw }) else { return }
        ui.soundFamily = page.family
    }

    /// A knob turned on the FM-1: show its button's pages and mark it for a few seconds.
    private func follow() {
        guard let t = session.lastTouched, let page = SoundPage.page(session, scope: t.scope, id: t.id) else { return }
        // with the screen link the FM-1's page decides the button; a knob turn only marks its knob
        if !session.screenLinked, SoundPage.shown(session, page.family).contains(where: { $0.id == page.id }) {
            ui.soundFamily = page.family
        }
        let key = "s\(t.scope).\(t.id)"
        marked = key
        // lit as long as Skiff lights the knob just turned (ui.hot_t = 40 frames, about 600 ms)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if marked == key { marked = nil }
        }
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
        let chord = chordMode ? session.pitch(ofKey: key).map { Music.chordNotes(on: $0, root: t.root, scale: t.scale, type: t.chord) } ?? [] : []
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("What the FM-1's keys play").font(.system(size: 15, weight: .semibold))
                Text(chordMode ? "chord mode: each white key plays a \(Music.chordNames[safe: t.chord] ?? "chord"); the black keys change it"
                     : t.quant == 2 ? "white keys walk the scale" : t.quant == 1 ? "snapped to the scale" : "every key, chromatic")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
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
                    Text(session.pitch(ofKey: key).map(Music.noteName) ?? "–").font(.system(size: 13, weight: .semibold))
                    Text("plays").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Text(chord.map(Music.noteName).joined(separator: " · ")).font(.system(size: 13, weight: .semibold))
                    Text("Tap a white key to see its chord.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
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
        let label = chordMode && black ? (Music.chordModifier(ofKey: key) ?? "") : (p.map(Music.noteName) ?? "")
        let cell = Text(label)
            .font(.system(size: chordMode && black ? 11 : 12, weight: lit ? .semibold : .regular))
            .foregroundStyle(lit ? Theme.onColour : chordMode && black ? Theme.textSecondary : Theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(lit ? Theme.track[session.selectedTrack] : Color(hex: 0x232427)))
            .overlay { if chordMode && key == picked { RoundedRectangle(cornerRadius: 9).stroke(Theme.text, lineWidth: 2).padding(-2) } }
            .opacity(p == nil && !(chordMode && black) ? 0.35 : 1)
        if chordMode && !black && p != nil {
            Button { self.picked = key } label: { cell.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.map(Music.spokenNoteName) ?? "") chord")
                .accessibilityAddTraits(key == picked ? .isSelected : [])
        } else {
            cell.accessibilityLabel(chordMode && black ? "Black key: \(label)" : (p.map(Music.spokenNoteName) ?? "silent"))
        }
    }
}

/// Under the track box on the Sound tab: the knob last turned on the FM-1, large. The FM-1's screen
/// says this too, in 240 pixels; here it's readable at arm's length.
struct FollowCard: View {
    let session: DeviceSession
    let ui: EditorUI

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last turned on the FM-1").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            if let t = session.lastTouched, let page = SoundPage.page(session, scope: t.scope, id: t.id) {
                let slot = page.ids.firstIndex(of: t.id) ?? 0
                let spec = KnobSpec.param(session, scope: t.scope, id: t.id, slot: slot)
                HStack(spacing: 16) {
                    KnobControl(ui: ui, size: 72) { KnobSpec.param(session, scope: t.scope, id: t.id, slot: slot) }
                    VStack(alignment: .leading, spacing: 2) {
                        let where_ = page.title(session) == page.family.rawValue ? page.family.rawValue : "\(page.family.rawValue) · \(page.title(session))"
                        Text(where_).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        Text(spec.label).font(.system(size: 17, weight: .semibold))
                        Text(spec.shown).font(.system(size: 28, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("Turn a knob on the FM-1 and it shows here, with its button's pages on the right.")
                    .font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}
