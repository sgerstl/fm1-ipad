import SloopKit
import SwiftUI

// Skiff's EDIT engine pages (Scott, 2026-11-05: "let's get em done"), as the FM-1 lays them out (params.c PAGES 16–22,
// ui.c page_visible): LANES (DRUM), LANE MIX (DRUM, DRUM-X), SOUND (DRUM-X), SAMPLES (SAMPLE on a user set),
// OPERATOR and ALL OPS (FM6), SLICES (SLICE). KNOB 1 picks a lane, a sound, a sample or an operator on most of
// them, and with the screen link's cursor that pick is the FM-1's, both ways (ShapeMarks.picks).

enum SkiffEdit {
    /// The lanes' names and the tiles' abbreviations (eng_drum.c), BD to CB.
    static let laneNames = ["KICK", "SNARE", "CLAP", "CL HAT", "OP HAT", "TOM", "RIM", "BELL"]
    static let laneShort = ["BD", "SD", "CP", "CH", "OH", "TM", "RS", "CB"]

    /// What KNOB 1 picks on a page, as ShapeMarks keys it: LANES, LANE MIX and SOUND share the lane (on DRUM-X the
    /// FM-1 shares it between SOUND and LANE MIX; on DRUM, LANES' lane is the grid's).
    static func pickKey(_ title: String) -> String? {
        switch title {
        case "LANES", "LANE MIX", "SOUND": "lane"
        case "SAMPLES": "sample"
        case "OPERATOR": "op"
        default: nil
        }
    }

    /// The user set a SAMPLE track plays (0…2 for USR1…USR3), found by the names of SAMPLE's SET (P_E0, the
    /// first engine parameter): nil on a built-in set or another engine.
    @MainActor static func userSlot(_ session: DeviceSession) -> Int? {
        let t = session.tracks[session.selectedTrack]
        guard session.dialect == .skiff, t.engine == SkiffPages.Engine.sample,
              let e0 = SoundPage.pages(session).first(where: { $0.engineEdit == 1 })?.ids.first ?? nil,
              let d = session.trackDesc(e0), let usr1 = d.names.firstIndex(of: "USR1") else { return nil }
        let k = session.cell(e0).value - d.min - usr1
        return (0..<3).contains(k) ? k : nil
    }
}

// MARK: LANES and LANE MIX

/// KNOB 1 the lane, by its name; then the lane's LEVEL, TUNE and DECAY (LANES) or LEVEL and PAN (LANE MIX), over
/// the eight faders (ui_graph.c graph_lanes, graph_lmix), where a tap picks a lane too.
struct LaneColumns: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    @Binding var lane: Int
    let marked: String?
    let activate: () -> Bool

    var body: some View {
        let tint = Theme.track[session.selectedTrack]
        let l = min(max(lane, 0), 7)
        let ids = page.picks[safe: l] ?? []
        let labels = page.title == "LANES" ? ["LEVEL", "TUNE", "DECAY"] : ["LEVEL", "PAN", nil]
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                KnobControl(ui: ui, activate: activate, column: (1, tint, false)) { laneSpec }
                ForEach(0..<3, id: \.self) { k in
                    if let id = ids[safe: k] ?? nil, let label = labels[k] {
                        KnobControl(ui: ui, activate: activate, column: (k + 2, tint, marked == "s0.\(id)")) {
                            KnobSpec.param(session, scope: 0, id: id, slot: k + 1).relabelled(label)
                        }
                    } else {
                        EmptyColumn()
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            LaneFaders(session: session, page: page, lane: l, mix: page.title == "LANE MIX") { lane = $0; _ = activate() }
                .frame(height: page.title == "LANE MIX" ? 150 : 128)
                .recessed(8)
        }
    }

    private var laneSpec: KnobSpec {
        KnobSpec(id: "lane.pick", colour: Theme.knob[0], label: "LANE", value: lane, range: 0...7, stepperStep: 1,
                 shown: SkiffEdit.laneNames[safe: lane] ?? "–", spoken: "lane \(lane + 1), \((SkiffEdit.laneNames[safe: lane] ?? "").lowercased())",
                 bipolar: false, defaultValue: 0) { lane = $0 }
    }
}

/// The eight lanes as faders: LEVEL filled in the track's colour from the foot, the picked lane white, its name tile
/// filled; LANE MIX adds each lane's PAN under its fader (a line, the centre tick, a marker) and the pan as text.
struct LaneFaders: View {
    let session: DeviceSession
    let page: SoundPage
    let lane: Int
    let mix: Bool
    let pick: (Int) -> Void

    var body: some View {
        let tint = Theme.track[session.selectedTrack]
        let levels = (0..<8).map { page.picks[safe: $0]?.first.flatMap { $0 }.map { session.cell($0).value } ?? 0 }
        let pans = (0..<8).map { k in mix ? (page.picks[safe: k]?[safe: 1] ?? nil).map { session.cell($0).value } ?? 0 : 0 }
        GeometryReader { g in
            let w = g.size.width / 8
            HStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { k in
                    let on = k == lane
                    let colour = on ? Theme.text : tint
                    VStack(spacing: 6) {
                        GeometryReader { f in
                            let h = f.size.height, fill = CGFloat(levels[k]) / 127 * (h - 6)
                            ZStack(alignment: .bottom) {
                                Capsule().fill(Theme.stepEmpty).frame(width: 6)
                                Capsule().fill(colour).frame(width: 6, height: max(0, fill))
                                RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 20, height: 6).offset(y: -max(0, fill - 3))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                        if mix { panMark(pans[k], colour: colour) }
                        Text(SkiffEdit.laneShort[k]).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(on ? Theme.onColour : Theme.textSecondary)
                            .frame(width: min(36, w - 6), height: 20)
                            .background(RoundedRectangle(cornerRadius: 4).fill(on ? Theme.text : Theme.control))
                    }
                    .padding(.vertical, 8)
                    .frame(width: w)
                    .contentShape(Rectangle())
                    .onTapGesture { pick(k) }
                    .accessibilityElement()
                    .accessibilityLabel(SkiffEdit.laneNames[k].capitalized)
                    .accessibilityValue("level \(levels[k] * 100 / 127) percent" + (mix ? ", pan \(MixerStrips.pan(pans[k]))" : ""))
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private func panMark(_ p: Int, colour: Color) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Capsule().fill(Theme.stepEmpty).frame(width: 26, height: 2)
                Rectangle().fill(Theme.textTertiary).frame(width: 1, height: 7)
                RoundedRectangle(cornerRadius: 1).fill(colour).frame(width: 5, height: 8).offset(x: CGFloat(p) * 12 / 64)
            }
            .frame(height: 8)
            Text(MixerStrips.pan(p)).font(.system(size: 11)).monospacedDigit().foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: Sheets: rows of four knobs (the FM-1's windows, SELECT stepping them there)

/// A sheet page's windows as rows, each titled; the row the FM-1's knobs are on (its second cursor) is lit.
struct SheetRows: View {
    let ui: EditorUI
    let rows: [(title: String, knobs: [(() -> KnobSpec)?])]
    let lit: Int?
    let tint: Color
    let activate: () -> Bool

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 4) {
                    Text(rows[r].title).font(.system(size: 11, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(lit == r ? Theme.onColour : Theme.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                        .frame(width: 52).frame(maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lit == r ? Theme.text : Theme.control))
                        .accessibilityLabel("\(rows[r].title) row" + (lit == r ? ", the FM-1's knobs" : ""))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(0..<4, id: \.self) { k in
                        if let make = rows[r].knobs[safe: k] ?? nil {
                            KnobControl(ui: ui, activate: activate, column: (k + 1, tint, false), make: make)
                        } else {
                            EmptyColumn()
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A row of tiles that picks one (the lane, the sound, the operator), as KNOB 1 or PRESETS does on the FM-1.
struct PickTiles: View {
    let titles: [String]
    var details: [String] = []
    var dim: Set<Int> = []
    let picked: Int
    let label: String
    let pick: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(titles.indices, id: \.self) { k in
                let on = k == picked
                Button { pick(k) } label: {
                    VStack(spacing: 2) {
                        Text(titles[k]).font(.system(size: 13, weight: .semibold))
                        if let d = details[safe: k] { Text(d).font(.system(size: 11)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7) }
                    }
                    .foregroundStyle(on ? Theme.onColour : dim.contains(k) ? Theme.textTertiary : Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(on ? Theme.text : Theme.control))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel("\(label) \(titles[k])" + (details[safe: k].map { ", \($0)" } ?? ""))
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

extension KnobSpec {
    /// A knob over a value Lupe keeps outside the track's parameters (a patch's field, a kit's value, a mix level).
    static func plain(_ id: String, _ label: String, _ v: Int, _ range: ClosedRange<Int>, shown: String? = nil, spoken: String? = nil,
                      choices: [String]? = nil, bipolar: Bool = false, slot: Int, set: @escaping (Int) -> Void) -> KnobSpec {
        let s = shown ?? choices?[safe: v - range.lowerBound] ?? "\(v)"
        return KnobSpec(id: id, colour: Theme.knob[slot % 4], label: label, value: v, range: range,
                        stepperStep: max(1, (range.upperBound - range.lowerBound) / 16), shown: s, spoken: spoken ?? s.lowercased(),
                        bipolar: bipolar, defaultValue: nil, choices: choices, set: set)
    }
}

// MARK: SOUND (DRUM-X): the kit's sound, its four windows (ui_dx.c DX_WIN)

struct DXSoundPage: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    @Binding var lane: Int
    let activate: () -> Bool

    var body: some View {
        let tint = Theme.track[session.selectedTrack]
        let l = min(max(lane, 0), 7)
        let k = session.skiffEdit?.kit[l]
        VStack(alignment: .leading, spacing: 10) {
            PickTiles(titles: SkiffEdit.laneShort, picked: l, label: "Sound") { lane = $0; _ = activate() }
            if k != nil {
                SheetRows(ui: ui, rows: rows(l), lit: litWindow, tint: tint, activate: activate)
            } else {
                Text("Reading the kit…").font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(minHeight: 44)
            }
            Text("The kit is the project's: every DRUM-X track plays it, MORPH blending A into B.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        }
        .task(id: l) { await session.skiffEdit?.readKit(lane: l) }
        .onChange(of: session.deviceScreen) { _, _ in Task { await session.skiffEdit?.readKit(lane: l) } }
    }

    private var litWindow: Int? {
        guard let s = session.deviceScreen, !s.home, s.page == page.fw else { return nil }
        return s.cursor2
    }

    private func rows(_ l: Int) -> [(title: String, knobs: [(() -> KnobSpec)?])] {
        func ab(_ i: Int, _ b: Bool, _ slot: Int) -> () -> KnobSpec {
            { [session] in
                let k = session.skiffEdit?.kit[l] ?? DXLane(lane: l)
                let v = b ? k.b[i] : k.a[i]
                return .plain("dx.\(l).\(b ? "b" : "a")\(i)", "\(DXLane.names[i]) \(b ? "B" : "A")", v, 0...127, slot: slot) { n in
                    session.skiffEdit?.editKit(lane: l) { if b { $0.b[i] = n } else { $0.a[i] = n } }
                }
            }
        }
        func mode(_ label: String, _ path: WritableKeyPath<DXLane, Int>, _ names: [String], _ slot: Int) -> () -> KnobSpec {
            { [session] in
                let v = session.skiffEdit?.kit[l]?[keyPath: path] ?? 0
                return .plain("dx.\(l).\(label)", label, v, 0...(names.count - 1), choices: names, slot: slot) { n in
                    session.skiffEdit?.editKit(lane: l) { $0[keyPath: path] = n }
                }
            }
        }
        let level: (() -> KnobSpec)? = (page.picks[safe: l]?.first ?? nil).map { id in
            { [session] in KnobSpec.param(session, scope: 0, id: id, slot: 2).relabelled("LEVEL") }
        }
        return [("PITCH", [ab(0, false, 0), ab(0, true, 1), ab(1, false, 2), ab(1, true, 3)]),
                ("DECAY NOISE", [ab(2, false, 0), ab(2, true, 1), ab(3, false, 2), ab(3, true, 3)]),
                ("COLOR LEVEL", [ab(4, false, 0), ab(4, true, 1), level, mode("DRIVE", \.drive, ["OFF", "ON"], 3)]),
                ("MODE", [mode("WAVE", \.wave, ["SIN", "FM", "MTL", "BEL"], 0), mode("FILTER", \.filter, ["LP", "BP", "HP"], 1),
                          mode("SNAP", \.snap, ["OFF", "ON"], 2), mode("P SHAPE", \.pitchShape, ["DECAY", "LONG", "NOISE", "SINE"], 3)])]
    }
}

// MARK: SAMPLES: a user set's sounds, each one's LEVEL, REVERB, DELAY (SMP_MIX)

struct SampleMixPage: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    @Binding var sample: Int
    let activate: () -> Bool

    var body: some View {
        let tint = Theme.track[session.selectedTrack]
        let slot = SkiffEdit.userSlot(session)
        let m = slot.flatMap { session.skiffEdit?.mixes[$0] }
        VStack(alignment: .leading, spacing: 10) {
            if let slot, let m, !m.zones.isEmpty {
                let z = min(max(sample, 0), m.zones.count - 1)
                PickTiles(titles: m.zones.indices.map { "\($0 + 1)" },
                          details: m.zones.map { "\(Music.noteName($0.lowerBound))–\(Music.noteName($0.upperBound))" },
                          picked: z, label: "Sample") { sample = $0; _ = activate() }
                SheetRows(ui: ui, rows: [("USR\(slot + 1)", [nil, knob(slot, z, \.level, "LEVEL", 1), knob(slot, z, \.reverb, "REVERB", 2),
                                                           knob(slot, z, \.delay, "DELAY", 3)])],
                          lit: nil, tint: tint, activate: activate)
                ZoneMap(zones: m.zones, picked: z, tint: tint) { sample = $0; _ = activate() }
                    .frame(height: 64).recessed(8)
                if m.rc == 2 {
                    Text("This set fills its slot, so the mix plays but isn't kept after the FM-1 is switched off.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
            } else if let slot, m != nil {
                Text("USR\(slot + 1) has no sounds yet.").font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(minHeight: 44)
            } else {
                Text("Reading the set…").font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(minHeight: 44)
            }
        }
        .task(id: slot) { if let slot { await session.skiffEdit?.readMix(slot: slot) } }
        .onChange(of: session.deviceScreen) { _, _ in Task { if let slot { await session.skiffEdit?.readMix(slot: slot) } } }
    }

    private func knob(_ slot: Int, _ z: Int, _ path: WritableKeyPath<SampleMix, [Int]>, _ label: String, _ k: Int) -> () -> KnobSpec {
        { [session] in
            let v = session.skiffEdit?.mixes[slot]?[keyPath: path][safe: z] ?? 0
            let p = (v * 100 + 63) / 127
            return .plain("smx.\(slot).\(z).\(label)", label, v, 0...127, shown: "\(p)%", spoken: "\(p) percent", slot: k) { n in
                session.skiffEdit?.editMix(slot: slot) { $0[keyPath: path][z] = n }
            }
        }
    }
}

/// The set's sounds over the keys (MIDI 21–108): each one's range a bar, the picked one white.
struct ZoneMap: View {
    let zones: [ClosedRange<Int>]
    let picked: Int
    let tint: Color
    let pick: (Int) -> Void

    var body: some View {
        GeometryReader { g in
            let x = { (n: Int) in CGFloat(n - 21) / 88 * (g.size.width - 16) + 8 }
            ZStack(alignment: .topLeading) {
                ForEach([24, 36, 48, 60, 72, 84, 96, 108], id: \.self) { c in
                    Text(Music.noteName(c)).font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                        .position(x: x(c), y: g.size.height - 8)
                }
                ForEach(zones.indices, id: \.self) { k in
                    let z = zones[k]
                    RoundedRectangle(cornerRadius: 3).fill(k == picked ? Theme.text : tint.opacity(0.7))
                        .frame(width: max(4, x(z.upperBound + 1) - x(z.lowerBound) - 2), height: 22)
                        .offset(x: x(z.lowerBound), y: 10)
                        .onTapGesture { pick(k) }
                        .accessibilityElement()
                        .accessibilityLabel("Sample \(k + 1), \(Music.noteName(z.lowerBound)) to \(Music.noteName(z.upperBound))")
                        .accessibilityAddTraits(k == picked ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}

// MARK: SLICES: SOURCE and DIV here; the markers only on the FM-1 (no command reaches them)

struct SlicesNote: View {
    let session: DeviceSession
    let page: SoundPage

    var body: some View {
        HStack(spacing: 12) {
            Text("Slices are moved, split and joined on the FM-1: the editor protocol has no command for them.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            if session.screenLinked {
                Button { session.showOnDevice(page: page.fw) } label: {
                    Text("Open on the FM-1").font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).frame(minHeight: 44).raisedKey().contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
            }
        }
    }
}
