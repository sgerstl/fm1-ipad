import SloopKit
import SwiftUI

/// The selected step. Raised keys change it; read-outs (the notes) sit in wells, under the brief's
/// "raised to press, recessed to read".
struct SelectedStepPanel: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        let t = session.selectedTrack
        let i = ui.selectedStep[t]
        // two rows, beside the track box: the step's notes and timing, then its feel and the knobs
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Text("Step \(i + 1)").font(.system(size: 22, weight: .semibold))
                }
                .frame(width: 96, alignment: .leading)
                .accessibilityElement(children: .combine)
                if t == 3 { drumDetails(session.tracks[3].drumSteps[i], part: 0) } else { synthDetails(session.tracks[t].steps[i], track: t, part: 0) }
                Spacer(minLength: 0)
            }
            HStack(alignment: .bottom, spacing: 24) {
                if t == 3 { drumDetails(session.tracks[3].drumSteps[i], part: 1) } else { synthDetails(session.tracks[t].steps[i], track: t, part: 1) }
                Spacer(minLength: 0)
                KnobRow(session: session, ui: ui)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected step")
    }

    @ViewBuilder private func synthDetails(_ s: SynthStep, track: Int, part: Int) -> some View {
        let i = ui.selectedStep[track]
        let on = s.isOn
        if part == 0 {
        // Notes are read here and added or removed in the grid, so they stay read-outs.
        field("Notes") {
            HStack(spacing: 6) {
                if on {
                    ForEach(Array(s.notes.enumerated()), id: \.offset) { _, n in
                        readout(Music.noteName(n)).accessibilityLabel(Music.spokenNoteName(n))
                    }
                } else {
                    readout(s.time == .tie ? "Held" : "Tap the grid", dim: true)
                }
            }
        }
        field("Step") {
            // Note needs a note: with none, it waits for a tap in the grid.
            SegmentedKeys(label: "Step", options: ["Note", "Tie", "Rest"], selected: s.time.rawValue,
                          enabled: [!s.notes.isEmpty || s.time == .note, true, true]) { k in
                var st = s; st.time = StepTime(rawValue: k) ?? .rest
                session.write(track: track, index: i, st)
            }
        }
        } else {
        // the step's own values, grouped bottom left: velocity turns like the track knobs (touch, trace
        // the ring; tap for − / +), in the track's colour; ratchet is x1..x4 hits in the step (SLOOP
        // keeps one per note: the keys set every note of the step)
        HStack(alignment: .bottom, spacing: 16) {
            KnobControl(ui: ui) { velocitySpec(track: track, index: i) }
                .disabled(!on)
                .opacity(on ? 1 : 0.4)
            field("Ratchet") {
                SegmentedKeys(label: "Ratchet", options: ["×1", "×2", "×3", "×4"], selected: on ? (s.ratchets.max() ?? 0) : -1,
                              enabled: Array(repeating: on, count: 4), minWidth: 44) { k in
                    var st = session.tracks[track].steps[i]
                    st.ratchets = Array(repeating: k, count: st.notes.count)
                    session.write(track: track, index: i, st)
                }
            }
        }
        field("Feel") {
            HStack(spacing: 8) {
                ToggleKey(name: "Accent", on: s.accent && on, enabled: on) {
                    var st = s; st.accent.toggle(); session.write(track: track, index: i, st)
                }
                ToggleKey(name: "Slide", on: s.slide && on, enabled: on) {
                    var st = s; st.slide.toggle(); session.write(track: track, index: i, st)
                }
            }
        }
        }
    }

    /// Read fresh on every turn: the grown ring re-asks while the finger moves.
    private func velocitySpec(track: Int, index i: Int) -> KnobSpec {
        let st = session.tracks[track].steps[i]
        return KnobSpec(id: "stepVelocity", colour: Theme.track[track], label: "VELOCITY", value: st.velocity, range: 1...127,
                        stepperStep: 8, shown: "\(st.velocity)", spoken: "\(st.velocity)", bipolar: false) { v in
            var now = session.tracks[track].steps[i]
            now.velocity = v
            session.write(track: track, index: i, now)
        }
    }

    @ViewBuilder private func drumDetails(_ s: DrumStep, part: Int) -> some View {
        let lane = ui.selectedLane
        let i = ui.selectedStep[3]
        let has = s.has(lane)
        if part == 0 {
        field("Hits") {
            HStack(spacing: 6) {
                if s.lanes.isEmpty { readout("Tap the grid", dim: true) }
                // a hit picks the lane the level and ratchet keys act on
                ForEach(s.lanes.prefix(4), id: \.self) { l in
                    Button { ui.selectedLane = l } label: {
                        Text(Music.drumLanes[l]).fontWeight(l == lane ? .semibold : .regular)
                            .foregroundStyle(l == lane ? Theme.text : Theme.textSecondary)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background { if l == lane { RoundedRectangle(cornerRadius: 9).fill(Theme.pressed).recessed(9) } else { Color.clear.raisedKey() } }
                    }
                    .buttonStyle(PressSink())
                    .accessibilityAddTraits(l == lane ? .isSelected : [])
                }
                if s.lanes.count > 4 { readout("+\(s.lanes.count - 4)", dim: true) }
            }
        }
        field("\(Music.drumLanes[lane]) level") {
            SegmentedKeys(label: "\(Music.drumLanes[lane]) level", options: Music.levelNames, selected: has ? s.level(lane) : -1,
                          enabled: Array(repeating: has, count: 4)) { k in
                session.write(drumIndex: i, s.setting(lane, on: true, level: k, ratchet: s.ratchet(lane)))
            }
        }
        } else {
        field("\(Music.drumLanes[lane]) ratchet") {
            SegmentedKeys(label: "\(Music.drumLanes[lane]) ratchet", options: ["×1", "×2", "×3", "×4"], selected: has ? s.ratchet(lane) : -1,
                          enabled: Array(repeating: has, count: 4), minWidth: 36) { k in
                session.write(drumIndex: i, s.setting(lane, on: true, level: s.level(lane), ratchet: k))
            }
        }
        }
    }

    // MARK: Layout and read-outs

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)       // the controls carry their own labels
            content()
        }
        .accessibilityElement(children: .contain)
    }

    private func readout(_ text: String, dim: Bool = false) -> some View {
        Text(text)
            .foregroundStyle(dim ? Theme.textSecondary : Theme.text)
            .padding(.horizontal, 12)
            .frame(minWidth: 52, minHeight: 44)
            .recessed(9)
    }
}
