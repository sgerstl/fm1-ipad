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
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text("Step \(i + 1)").font(.system(size: 22, weight: .semibold))
            }
            .frame(width: 96, alignment: .leading)
            .accessibilityElement(children: .combine)

            if t == 3 { drumDetails(session.tracks[3].drumSteps[i]) } else { synthDetails(session.tracks[t].steps[i], track: t) }

            Spacer(minLength: 0)
            KnobRow(session: session, ui: ui)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)       // the page's height budget leaves this panel 104 pt; the knob tray needs about 86
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected step")
    }

    @ViewBuilder private func synthDetails(_ s: SynthStep, track: Int) -> some View {
        let i = ui.selectedStep[track]
        let on = s.isOn
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
        field("Velocity") {
            StepperKeys(label: "Velocity", value: s.velocity, range: 1...127, enabled: on) { v in
                var st = s; st.velocity = v
                session.write(track: track, index: i, st)
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

    @ViewBuilder private func drumDetails(_ s: DrumStep) -> some View {
        let lane = ui.selectedLane
        let i = ui.selectedStep[3]
        let has = s.has(lane)
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
        field("\(Music.drumLanes[lane]) ratchet") {
            SegmentedKeys(label: "\(Music.drumLanes[lane]) ratchet", options: ["×1", "×2", "×3", "×4"], selected: has ? s.ratchet(lane) : -1,
                          enabled: Array(repeating: has, count: 4), minWidth: 36) { k in
                session.write(drumIndex: i, s.setting(lane, on: true, level: s.level(lane), ratchet: k))
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
