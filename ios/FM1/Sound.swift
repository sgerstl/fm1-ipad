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

    @MainActor
    static func shown(_ session: SloopSession, _ family: SoundFamily) -> [SoundPage] {
        let t = session.tracks[session.selectedTrack]
        return all.filter { p in
            p.family == family && (!t.isDrums || p.drums) && (!p.analogOnly || (!t.isDrums && t.engine == 0))
        }
    }

    static func page(fw: Int) -> SoundPage? { all.first { $0.fw == fw } }

    /// The page a parameter is on, the first one when it appears on several (as MIDI's channels do).
    static func page(scope: Int, id: Int) -> SoundPage? {
        all.first { $0.scope == scope && $0.ids.contains(id) && !$0.analogOnly }
    }

    @MainActor
    func title(_ session: SloopSession) -> String {
        guard engineEdit > 0 else { return title }
        let e = session.tracks[session.selectedTrack].engine
        let t = session.editPageTitles[e] ?? []
        let name = engineEdit - 1 < t.count ? t[engineEdit - 1] : ""
        return name.isEmpty ? title : "\(title) · \(name)"
    }
}

/// A parameter's value as text, close to how the FM-1 shows it (EDITOR_PROTOCOL.md "fmt"). TIME,
/// LFOHZ, CUTOFF and DB show the raw value with the unit SLOOP gives; the device's exact curves
/// aren't in the protocol.
func formatValue(_ d: ParamDesc?, _ v: Int) -> (shown: String, spoken: String) {
    guard let d else { return ("\(v)", "\(v)") }
    let unit = d.unit.isEmpty ? "" : " \(d.unit.lowercased())"
    switch d.format {
    case 1: let p = d.max > 0 ? Int((Double(v) * 100 / Double(d.max)).rounded()) : v; return ("\(p)%", "\(p) percent")
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
    static func param(_ session: SloopSession, scope: Int, id: Int, slot: Int) -> KnobSpec {
        let d = scope == 0 ? session.trackDescs[id] : session.globalDescs[id]
        let values = scope == 0 ? session.params : session.globals
        let v = id < values.count ? values[id] : 0
        let lo = d?.min ?? 0, hi = max(d?.max ?? 127, lo)
        let f = formatValue(d, v)
        let t = session.selectedTrack
        return KnobSpec(id: "s\(scope).\(id)", colour: Theme.knob[slot % 4], label: d?.label ?? "–", value: v,
                        range: lo...hi, stepperStep: max(1, (hi - lo) / 16), shown: f.shown, spoken: f.spoken,
                        bipolar: d?.format == 2 || d?.format == 15 || (lo < 0 && hi > 0)) { nv in
            if scope == 0 { session.set(track: t, param: id, to: nv) } else { session.set(global: id, to: nv) }
        }
    }
}

struct SoundTab: View {
    let session: SloopSession
    let ui: EditorUI
    @State private var marked: String?          // the knob last turned on the FM-1, marked for a moment

    var body: some View {
        let drums = session.selectedTrack == 3
        let pages = SoundPage.shown(session, ui.soundFamily)
        VStack(alignment: .leading, spacing: 16) {
            familyBar(drums)
            ScrollView {
                if ui.soundFamily == .sel { KeyMapStrip(session: session) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(pages) { p in pagePanel(p) }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: session.lastTouched?.at) { _, _ in follow() }
        .onChange(of: session.deviceScreen) { _, s in followScreen(s) }
    }

    // MARK: The FM-1's function buttons

    private func familyBar(_ drums: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(SoundFamily.allCases) { f in
                let on = ui.soundFamily == f
                let has = !SoundPage.shown(session, f).isEmpty
                Button {
                    ui.soundFamily = f
                    // linked: the FM-1 opens the same button's first page
                    if session.screenLinked, let first = SoundPage.shown(session, f).first { session.showOnDevice(page: first.fw) }
                } label: {
                    Text(f.rawValue)
                        .font(.system(size: 15, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.text : has ? Theme.textSecondary : Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background { if on { Color.clear.raisedKey() } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(!has)
                .accessibilityLabel(f.rawValue)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityHint(has ? "" : "The drum track has no \(f.rawValue) pages")
            }
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FM-1 buttons")
    }

    // MARK: A page: its four knobs, as on the FM-1

    private func pagePanel(_ p: SoundPage) -> some View {
        let touchedHere = marked != nil && p.ids.contains { id in id.map { "s\(p.scope).\($0)" } == marked }
        // linked (fm1-ipad firmware): the light is the FM-1's own page; otherwise the knob just turned
        let onDevice = session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == p.fw } == true
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LED(on: session.screenLinked ? onDevice : touchedHere)
                Text(p.title(session)).font(.system(size: 15, weight: .semibold))
                if p.scope == 1 {
                    Text("all tracks").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { slot in
                    if let id = p.ids[slot] {
                        KnobControl(ui: ui, size: 56) { KnobSpec.param(session, scope: p.scope, id: id, slot: slot) }
                            .padding(6)
                            .background {
                                if marked == "s\(p.scope).\(id)" {
                                    RoundedRectangle(cornerRadius: 12).stroke(Theme.text, lineWidth: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1).accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(16)
        .panel()
        .contentShape(Rectangle())
        // tap a page (outside its knobs) to show it on the FM-1
        .onTapGesture { if session.screenLinked { session.showOnDevice(page: p.fw) } }
        .accessibilityAction(named: "Show on the FM-1") { session.showOnDevice(page: p.fw) }
        .id(p.id)
    }

    /// The FM-1 changed page (a button pressed on it): show that button's pages here. Holding SEL
    /// (its key layer) brings up SEL.
    private func followScreen(_ s: UIState?) {
        guard let s else { return }
        if s.layer == 5 { ui.soundFamily = .sel; return }              // LY_SCALE: SEL held
        guard !s.home, let page = SoundPage.page(fw: s.page),
              SoundPage.shown(session, page.family).contains(where: { $0.fw == page.fw }) else { return }
        ui.soundFamily = page.family
    }

    /// A knob turned on the FM-1: show its button's pages and mark it for a few seconds.
    private func follow() {
        guard let t = session.lastTouched, let page = SoundPage.page(scope: t.scope, id: t.id) else { return }
        if SoundPage.shown(session, page.family).contains(where: { $0.id == page.id }) {
            ui.soundFamily = page.family
        }
        let key = "s\(t.scope).\(t.id)"
        marked = key
        Task {
            try? await Task.sleep(for: .seconds(3))
            if marked == key { marked = nil }
        }
    }
}

/// SEL: what each of the FM-1's 27 keys plays now (root, scale, SNAP / WHITE, transpose, OCT), the
/// thing the device's SEL pages change but its screen can't show all at once.
struct KeyMapStrip: View {
    let session: SloopSession

    var body: some View {
        let t = session.tracks[session.selectedTrack]
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("What the FM-1's keys play").font(.system(size: 15, weight: .semibold))
                Text(t.quant == 2 || t.chord != 0 ? "white keys walk the scale" : t.quant == 1 ? "snapped to the scale" : "every key, chromatic")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            GeometryReader { geo in
                let w = geo.size.width / 16
                ZStack(alignment: .topLeading) {
                    ForEach(KeyboardDrawer.blackAfter, id: \.self) { k in
                        keyCell(KeyboardDrawer.whiteOffsets[k] + 1, t: t).frame(width: w - 6, height: 34)
                            .offset(x: CGFloat(k + 1) * w - (w - 6) / 2)
                    }
                    ForEach(0..<16, id: \.self) { k in
                        keyCell(KeyboardDrawer.whiteOffsets[k], t: t).frame(width: w - 6, height: 34)
                            .offset(x: CGFloat(k) * w + 3, y: 40)
                    }
                }
            }
            .frame(height: 74)
        }
        .padding(16)
        .panel()
        .padding(.bottom, 16)
        .accessibilityElement(children: .combine)
    }

    /// A key: the note it plays, lit when it's the root; silent keys are blank.
    private func keyCell(_ key: Int, t: TrackState) -> some View {
        let p = session.pitch(ofKey: key)
        let root = p.map { (($0 - t.root) % 12 + 12) % 12 == 0 } ?? false
        return Text(p.map(Music.noteName) ?? "")
            .font(.system(size: 12, weight: root ? .semibold : .regular))
            .foregroundStyle(root ? Theme.onColour : Theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(root ? Theme.track[session.selectedTrack] : Color(hex: 0x232427)))
            .opacity(p == nil ? 0.35 : 1)
    }
}

/// Under the track box on the Sound tab: the knob last turned on the FM-1, large. The FM-1's screen
/// says this too, in 240 pixels; here it's readable at arm's length.
struct FollowCard: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last turned on the FM-1").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            if let t = session.lastTouched, let page = SoundPage.page(scope: t.scope, id: t.id) {
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
