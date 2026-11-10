import SloopKit
import SwiftUI

// The Song tab's whole-track controls. 2026-11-05: SWING, LEVEL, STEPS and PAN in a popover under the selected lane's
// header. 2026-11-06 (Scott): no popover and no key for it; a small grey box with the knobs sits at the right end of
// the timeline just under the selected lane (above it on the last lanes), no header, no title, and a knob turns on a
// slide up or down from the first touch. SWING is left out: it sets every track, so in a box under one lane it read as
// that track's; it stays on the Mixer's Global card. The FM-1's PATTERN button lights the box (its flash ring).

/// The selected track's knobs at the timeline's right end (SkiffArrangePage places it): HOME's four, then LEVEL, STEPS, PAN.
struct TrackKnobBox: View {
    let session: DeviceSession
    let ui: EditorUI
    /// On the selected row's tab (the Song tab): no card of its own, the tab is its surface.
    var embedded = false
    /// The knob last turned on the FM-1, lit as the sound panel lights it (Scott, 2026-11-07: "work exactly like the
    /// ones in the panel").
    @State private var marks = ShapeMarks()
    /// Pads' and the Timeline's: the box shown on the selected lane (shared). Its close key shuts it, so nobody has to
    /// remember the head's double tap (Scott, 2026-11-10), which stays.
    @AppStorage("padControlsOpen") private var controlsOpen = true

    /// Two rows (Scott, 2026-11-06): the FM-1's four knobs as HOME has them for this sound, then LEVEL, STEPS, PAN.
    /// Its width on a tab: HOME's four 92 pt columns, their gaps, 8 pt each side.
    static let width: CGFloat = 4 * 92 + 3 * 4 + 16
    /// Two rows of 56 pt boxes, their 4 pt gap, and 8 pt above and below: the same border as its sides on the tint (Scott,
    /// 2026-11-09: 4 pt top and bottom read as no border; 116 had crushed the rows, 2026-11-07).
    static let height: CGFloat = 132
    /// Its corners on a tab: the tiles' 6 and the 8 pt inset round them (outer = inner + inset), so the tint runs an
    /// even width round every tile (Scott, 2026-11-09).
    static let outerRadius: CGFloat = 6 + 8
    /// Taller by a row of chips while the selected track has an effect applied (Scott, 2026-11-10, board 46).
    static let chipRow: CGFloat = 22 + 4
    @MainActor static func height(for session: DeviceSession) -> CGFloat {
        height + (TrackChips.of(session, session.selectedTrack).isEmpty ? 0 : chipRow)
    }
    /// KnobSpec.all's LEVEL, STEPS, PAN (0 is SWING, global).
    static let knobs = 1..<4

    /// What KNOB 1…4 turn on Skiff's HOME: the engine's four main parameters (Skiff 2.2, each eng_*.c's `.knob`).
    /// 0…7 are the engine's own (P_E0…P_E7, from INFO's first engine parameter); ATK and REL are the shared envelope's.
    enum HomeParam { case e(Int), atk, rel }
    static let homeKnobs: [[HomeParam]] = [
        [.e(4), .e(5), .atk, .rel],          // 0 ANALOG
        [.e(4), .e(5), .e(6), .rel],         // 1 DIGITAL (retired)
        [.e(2), .e(3), .e(4), .rel],         // 2 PHASE
        [.e(1), .e(2), .e(3), .rel],         // 3 LOFI
        [.e(0), .e(4), .atk, .rel],          // 4 SAMPLE
        [.e(0), .e(4), .e(5), .e(2)],        // 5 VOICE
        [.e(5), .e(6), .e(7), .e(1)],        // 6 TRIO
        [.e(0), .e(4), .e(6), .e(7)],        // 7 WHEEL
        [.e(1), .e(2), .e(3), .e(5)],        // 8 GRAIN
        [.e(1), .e(2), .e(3), .e(4)],        // 9 PHYS
        [.e(1), .e(2), .e(3), .e(4)],        // 10 DRUM
        [.e(2), .e(3), .e(1), .rel],         // 11 NOISE
        [.e(2), .e(3), .e(4), .e(7)],        // 12 FM6
        [.e(0), .e(1), .e(3), .e(6)],        // 13 SLICE
        [.e(0), .e(1), .e(2), .e(3)],        // 14 DRUM-X
    ]
    static func homeIDs(_ session: DeviceSession) -> [Int] {
        guard session.dialect == .skiff, let e0 = session.info?.firstEngineParam,
              let row = homeKnobs[safe: session.tracks[session.selectedTrack].engine] else { return [] }
        return row.map { switch $0 { case .e(let n): e0 + n; case .atk: 1; case .rel: 4 } }
    }

    var body: some View {
        let t = session.selectedTrack
        let home = Self.homeIDs(session)
        let chips = TrackChips.of(session, t)
        VStack(alignment: .leading, spacing: 4) {
            // the track's effects in a row above the tiles, as many as fit, the last "+N" (board 46)
            if !chips.isEmpty { ChipRow(session: session, ui: ui, track: t, chips: chips, width: Self.width - 16) }
            // HOME's four as the columns everywhere else (Scott, 2026-11-06), the track's colour, numbered as the FM-1's
            // knobs; a slide turns one, as on every column (the way Settings says), and it turns that knob's parameter on the FM-1 too
            if !home.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(home.enumerated()), id: \.offset) { k, id in
                        KnobControl(ui: ui, column: (number: k + 1, tint: Theme.track[t], hot: marks.key == "s0.\(id)")) {
                            KnobSpec.param(session, scope: 0, id: id, slot: k)
                        }
                        .frame(width: 92, height: 56)
                    }
                }
            }
            // LEVEL, STEPS, PAN as boxes like the four, without a knob number (Scott, 2026-11-07: the dials "aren't
            // working as dials anymore")
            HStack(spacing: 4) {
                ForEach(Self.knobs, id: \.self) { k in
                    KnobControl(ui: ui, column: (number: 0, tint: Theme.track[t], hot: false)) { KnobSpec.all(session)[k] }
                        .frame(width: 92, height: 56)
                }
                // the cell beside PAN: a small round close key in its bottom right corner, round and dark so it
                // reads as a key, not a fifth parameter; its touch the full 44 pt
                if embedded {
                    Color.clear.frame(width: 92, height: 56)
                        .overlay(alignment: .bottomTrailing) { CloseControlsKey { controlsOpen = false } }
                }
            }
        }
        .environment(\.compactColumns, true)
        .padding(.horizontal, embedded ? 8 : 6)
        .padding(.vertical, 8)
        .frame(height: (Self.homeIDs(session).isEmpty ? 72 : Self.height) + (chips.isEmpty ? 0 : Self.chipRow))
        .background { if !embedded { RoundedRectangle(cornerRadius: 12).fill(Elevation.held.surface).elevationShadow(.held) } }
        .background { TouchFollower(session: session) { if let k = session.lastTouched { marks.mark("s\(k.scope).\(k.id)") } } }
        .flashRing(ui, .trackPanel)
        // the SEQ pad's TRACK page still asks for the popover by name (SoundPanel): light the box instead
        .onChange(of: ui.trackControlsOpen) { _, open in
            guard open else { return }
            ui.trackControlsOpen = false
            ui.flash = Flash(target: .trackPanel, id: (ui.flash?.id ?? 0) + 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(t + 1) knobs")
    }
}

/// A lane header's chip, which mutes (Scott, 2026-11-06, as SLOOP's Song tab did): on the selected track a tap mutes
/// and unmutes, on another it selects. To VoiceOver it's the track's mute switch on every lane (the name beside it
/// selects), so muting another track is one action there too.
struct MuteChip: View {
    let session: DeviceSession
    let track: Int
    let selected: Bool
    var size: CGFloat = 28

    var body: some View {
        Toggle(isOn: Binding(get: { session.tracks[track].mute },
                             set: { if $0 != session.tracks[track].mute { session.toggleMute(track: track) } })) {
            Text("Mute track \(track + 1)")
        }
        .toggleStyle(MuteChipStyle(track: track, selected: selected, size: size) { session.select(track: track) })
    }
}

private struct MuteChipStyle: ToggleStyle {
    let track: Int
    let selected: Bool
    let size: CGFloat
    let select: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        Button { selected ? configuration.isOn.toggle() : select() } label: {
            TrackChip(track: track, size: size, muted: configuration.isOn, selected: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: configuration.isOn))
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// The track controls' close key (Scott, 2026-11-10: "a little close button… a quarter of the size of the other squares"):
/// a 28 pt dark disc with a cross, in a 44 pt touch area anchored to the box's bottom right corner.
struct CloseControlsKey: View {
    let close: () -> Void
    var body: some View {
        Button(action: close) {
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.control))      // (no ring: Scott, 2026-11-10, subtler; × 12.9:1 on it)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel("Close track controls")
        .accessibilityHint("Double-tapping the track's head opens them again")
    }
}
