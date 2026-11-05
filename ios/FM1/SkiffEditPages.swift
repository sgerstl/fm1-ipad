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
