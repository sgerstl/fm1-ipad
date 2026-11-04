import SloopKit
import SwiftUI

/// The drum track has no SEL, ENV, LFO, EDIT or ARP pages (params.c page_for_drum). Rather than an
/// empty area, those buttons show their usual pages greyed out, knobs without values, under one line
/// that says why and where the drum version lives (SLOOP README: TUNE and DECAY per sound on the
/// DRUMS screen's SOUND page; movement from the FX pages the drums do have).
struct DrumNoPages: View {
    let session: DeviceSession
    let ui: EditorUI
    let family: SoundFamily

    var body: some View {
        // the synth track's pages for this button, as they would be
        let ghosts = SoundPage.reached(session, family)
        VStack(alignment: .leading, spacing: 16) {
            reason
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach(Array(stride(from: 0, to: ghosts.count, by: 2)), id: \.self) { i in
                    GridRow {
                        ghost(ghosts[i])
                        if i + 1 < ghosts.count { ghost(ghosts[i + 1]) } else { Color.clear.gridCellUnsizedAxes([.vertical]) }
                    }
                }
            }
            .accessibilityHidden(true)               // the line above says it; dead knobs aren't read out
        }
    }

    private var message: (title: String, detail: String) {
        switch family {
        case .sel: ("The drum track doesn't follow the key", "Each white key plays one drum sound, so root, scale and chords belong to the synth tracks.")
        case .env: ("The drum track has no envelope", "Each drum sound has its own TUNE and DECAY, on the FM-1's DRUMS screen (its SOUND page).")
        case .lfo: ("The drum track has no LFO", "For movement on the drums, use the FX pages: FILTER, SLICER and INSERT work on the drum track.")
        case .edit: ("The drum track has no engine to edit", "The kit is the sound: pick another one to change it.")
        case .arp: ("The arpeggiator is for the synth tracks", "The drum track plays its sounds as they're programmed.")
        default: ("Nothing here for the drum track", "")
        }
    }

    private var reason: some View {
        let m = message
        return HStack(alignment: .center, spacing: 16) {
            TrackChip(track: session.drumTrack ?? 0, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(m.title).font(.system(size: 17, weight: .semibold))
                Text(m.detail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            if family == .lfo {
                Button { ui.soundFamily = .fx } label: { key("Open FX") }.buttonStyle(PressSink())
            } else if family == .edit {
                Button { ui.presetsPanel = true } label: { key("Kits…") }.buttonStyle(PressSink())
            }
        }
        .padding(16)
        .panel()
        .accessibilityElement(children: .combine)
    }

    private func key(_ t: String) -> some View {
        Text(t).fontWeight(.semibold).padding(.horizontal, 16).frame(height: 44).raisedKey()
    }

    /// A page as on a synth track, greyed: its title and knob labels, no values, no rings. The one the
    /// FM-1 shows ("DRUM TRACK" there) keeps its lit edge and tag, as every page does.
    private func ghost(_ p: SoundPage) -> some View {
        let onDevice = session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == p.fw } == true
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LED(on: onDevice)
                Text(p.engineEdit > 0 ? (p.engineEdit == 1 ? "EDIT 1" : "EDIT 2") : p.title).font(.system(size: 15, weight: .semibold))
                if onDevice {
                    Text("On the FM-1").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.10)))
                }
                Spacer()
            }
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { slot in
                    VStack(spacing: 6) {
                        Circle().stroke(Theme.textTertiary, style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                            .frame(width: 44, height: 44)
                            .opacity(p.ids[slot] == nil ? 0 : 1)
                        Text(label(p, slot)).font(.system(size: 12)).lineLimit(1)
                        Text(" ").font(.system(size: 15))           // where the value would be
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(Theme.textTertiary)
        .padding(16)
        .panel()
        .opacity(onDevice ? 0.85 : 0.6)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.text).frame(height: 3).padding(.horizontal, 14).offset(y: 1)
                .shadow(color: Theme.text.opacity(0.7), radius: 6)
                .opacity(onDevice ? 1 : 0)
        }
    }

    private func label(_ p: SoundPage, _ slot: Int) -> String {
        guard p.engineEdit == 0, let id = p.ids[slot] else { return "" }
        return Self.labels[id] ?? ""
    }

    /// The synth pages' knob labels (params.c), for the ghosts: the drum track's own descriptions
    /// don't cover these parameters.
    static let labels: [Int: String] = [
        1: "ATK", 2: "DEC", 3: "SUS", 4: "REL", 5: "FLT", 6: "PIT", 7: "SHP", 59: "ESYNC",
        9: "RATE", 10: "WAVE", 11: "PHS", 12: "FADE", 13: "PIT", 14: "FLT", 15: "SHP", 16: "AMP",
        60: "SYNC", 61: "TRIG", 62: "POL",
        25: "ROOT", 26: "SCL", 27: "QNT", 49: "CHORD", 28: "TRN", 51: "STRUM", 52: "VLEAD",
        17: "MODE", 18: "RATE", 19: "OCT", 20: "GATE",
    ]
}
