import SloopKit
import SwiftUI

// Skiff's selected step (canvas board 15, design/boards/steps.py; 2026-11-05): its notes, ‹ › through the steps; the
// four values the FM-1's knobs turn on NOTES (PITCH START LENGTH VELOCITY, params.c's NOTES page), numbered as the
// knobs are; then FEEL's (CHANCE, RATCHET, COND, NUDGE); then what every recorded parameter sounds at this step and
// where it comes from (motion.c: a lock on the step, the latest recorded change before it, or the sound), worked out
// from the records without playing. Skiff's step bytes after the velocity (editor.c ed_step_reply): hits ×3, chance
// 0–100, ratchet 1–4, FLAM, COND (TC_*), NUDGE + 32, the notes' tie mask. LENGTH is the steps it holds: its TIE steps
// after it, as the roll's grip sets them (setLength).
struct SkiffStepInspector: View {
    let session: DeviceSession
    let ui: EditorUI

    static let conditions = ["--", "FILL", "!FILL", "1:2", "2:2", "1:3", "2:3", "3:3", "1:4", "2:4", "3:4", "4:4"]

    @State private var soundFrame: CGRect = .zero    // the collapsed "Sound at this step" key, for its menu

    var body: some View {
        let t = session.selectedTrack, i = ui.selectedStep[t]
        // never a scroll (Scott, 2026-11-06): everything when it fits, else the sound rows behind a disclosure
        ViewThatFits(in: .vertical) {
            content(t, i, collapsed: false)
            content(t, i, collapsed: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(i + 1)")
        .onChange(of: i) { _, n in if session.lockStep != nil { session.lockStep = n } }
        .onDisappear { session.lockStep = nil }
    }

    private func content(_ t: Int, _ i: Int, collapsed: Bool) -> some View {
        let s = session.tracks[t].steps[i]
        let tint = Theme.track[t]
        let locks = session.motion[t]?.events.contains { $0.lock && $0.step == i } ?? false
        return VStack(alignment: .leading, spacing: collapsed ? 10 : 12) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    // (short: the step's notes ride on this line instead of their own row)
                    Text("T\(t + 1) \(session.tracks[t].displayName)" + (collapsed && s.isOn ? " · " + s.notes.map(Music.noteName).joined(separator: " ") : ""))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary).lineLimit(1)
                    Text("Step \(i + 1)").font(.system(size: 20, weight: .semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                if locks {
                    Button("Clear locks") { Task { await session.clearLocks(track: t, step: i) } }
                        .font(.system(size: 12, weight: .semibold)).underline()
                        .frame(minHeight: 44)
                        .disabled(session.song.songPlaying)
                        .accessibilityHint("Takes this step's locks off; its recorded changes stay")
                }
                stepKey("chevron.left", "Previous step") { go(-1) }
                stepKey("chevron.right", "Next step") { go(1) }
            }
            if !collapsed { notes(s, tint) }
            // NOTES' four (their badges say which knob), two by two: the column is too narrow for four across
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    column(1, tint, s.isOn) { pitchSpec(t, i) }
                    column(2, tint, s.isOn) { moveSpec(t, i) }
                }
                GridRow {
                    column(3, tint, s.isOn) { lengthSpec(t, i) }
                    column(4, tint, s.isOn) { velocitySpec(t, i) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            // FEEL's four: no knob numbers, so they fit across
            HStack(spacing: 4) {
                column(0, tint, s.isOn && s.extra.count >= 4) { extraSpec(t, i, k: 3, label: "CHANCE", range: 0...100, shown: { "\($0)%" }) }
                column(0, tint, s.isOn) { ratchetSpec(t, i) }
                column(0, tint, s.isOn && s.extra.count >= 7) {
                    extraSpec(t, i, k: 6, label: "COND", range: 0...11, shown: { Self.conditions[safe: $0] ?? "--" }, choices: Self.conditions)
                }
                column(0, tint, s.isOn && s.extra.count >= 8) { nudgeSpec(t, i) }
            }
            .fixedSize(horizontal: false, vertical: true)
            if !collapsed { Rectangle().fill(Theme.stepEmpty).frame(height: 1) }
            if collapsed {
                // a short box: the sound rows in a menu, and the lock key beside it, one row
                HStack(spacing: 8) {
                    soundAtStep(t, i, tint, collapsed: true)
                    lockKey(i, compact: true)
                }
            } else {
                soundAtStep(t, i, tint, collapsed: false)
                lockKey(i)
            }
        }
    }

    private func go(_ d: Int) {
        let t = session.selectedTrack, n = session.stepCount
        ui.selectedStep[t] = (ui.selectedStep[t] + d + n) % n
    }

    private func stepKey(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44).raisedKey()
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(label)
    }

    private func notes(_ s: SynthStep, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            if s.isOn {
                ForEach(Array(s.notes.enumerated()), id: \.offset) { _, n in
                    Text(Music.noteName(n)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7).fill(tint))
                        .accessibilityLabel(Music.spokenNoteName(n))
                }
            } else {
                Text(s.time == .tie ? "Held from the step before" : "No notes: tap the grid to add one")
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.well))
            }
        }
    }

    /// A column, dim (and inert) where the step has nothing to turn.
    @ViewBuilder private func column(_ n: Int, _ tint: Color, _ on: Bool, _ make: @escaping () -> KnobSpec) -> some View {
        if on {
            KnobControl(ui: ui, column: (n, tint, false), make: make)
        } else {
            ColumnFace(spec: make(), number: n, tint: tint, hot: false, dim: true)
                .accessibilityElement().accessibilityLabel("\(make().label.capitalized), nothing to change on this step")
        }
    }

    // MARK: The knobs

    private func write(_ t: Int, _ i: Int, _ change: (inout SynthStep) -> Void) {
        var st = session.tracks[t].steps[i]
        change(&st)
        session.write(track: t, index: i, st)
    }

    private func pitchSpec(_ t: Int, _ i: Int) -> KnobSpec {
        let s = session.tracks[t].steps[i], n = s.notes.first ?? 60
        return KnobSpec(id: "step.pitch", colour: Theme.track[t], label: "PITCH", value: n, range: 0...127, stepperStep: 1,
                        shown: Music.noteName(n), spoken: Music.spokenNoteName(n), bipolar: false) { v in
            write(t, i) { st in
                // the chord moves together, as PITCH moves the selection's notes
                let d = v - (st.notes.first ?? v)
                st.notes = st.notes.map { min(127, max(0, $0 + d)) }
            }
        }
    }

    /// START: the step's notes moved to another step (swapped with what's there), the selection with them.
    private func moveSpec(_ t: Int, _ i: Int) -> KnobSpec {
        KnobSpec(id: "step.move", colour: Theme.track[t], label: "MOVE", value: i, range: 0...(session.stepCount - 1), stepperStep: 1,
                 shown: "Step \(i + 1)", spoken: "step \(i + 1)", bipolar: false) { v in
            guard v != i else { return }
            let a = session.tracks[t].steps[i], b = session.tracks[t].steps[v]
            session.write(track: t, index: v, a)
            session.write(track: t, index: i, b)
            ui.selectedStep[t] = v
        }
    }

    /// LENGTH: the steps it holds for, itself and the TIE steps after it.
    private func lengthSpec(_ t: Int, _ i: Int) -> KnobSpec {
        let steps = session.tracks[t].steps
        var len = 1
        while i + len < steps.count, steps[i + len].time == .tie { len += 1 }
        return KnobSpec(id: "step.length", colour: Theme.track[t], label: "LENGTH", value: len, range: 1...max(1, min(16, steps.count - i)),
                        stepperStep: 1, shown: "\(len) step\(len == 1 ? "" : "s")", spoken: "\(len) steps", bipolar: false, defaultValue: 1) { v in
            session.setLength(track: t, start: i, steps: v)
        }
    }

    private func velocitySpec(_ t: Int, _ i: Int) -> KnobSpec {
        let v = session.tracks[t].steps[i].velocity
        return KnobSpec(id: "step.velocity", colour: Theme.track[t], label: "VELOCITY", value: max(1, v), range: 1...127, stepperStep: 8,
                        shown: "\(v)", spoken: "\(v)", bipolar: false, defaultValue: 100) { n in write(t, i) { $0.velocity = n } }
    }

    private func ratchetSpec(_ t: Int, _ i: Int) -> KnobSpec {
        let r = session.tracks[t].steps[i].ratchets.first ?? 0
        return KnobSpec(id: "step.ratchet", colour: Theme.track[t], label: "RATCHET", value: r, range: 0...3, stepperStep: 1,
                        shown: "×\(r + 1)", spoken: "\(r + 1) hits", bipolar: false, defaultValue: 0,
                        choices: ["×1", "×2", "×3", "×4"]) { v in write(t, i) { st in st.ratchets = Array(repeating: v, count: max(1, st.notes.count)) } }
    }

    private func nudgeSpec(_ t: Int, _ i: Int) -> KnobSpec {
        // NUDGE + 32 on the wire (editor.c), 64ths of a step: −32…31
        let s = session.tracks[t].steps[i], n = s.extra.count >= 8 ? (Int(s.extra[7]) & 63) - 32 : 0
        return KnobSpec(id: "step.nudge", colour: Theme.track[t], label: "NUDGE", value: n, range: -32...31, stepperStep: 2,
                        shown: n > 0 ? "+\(n)" : "\(n)", spoken: "\(n) sixty-fourths of a step", bipolar: true, defaultValue: 0) { v in
            write(t, i) { st in if st.extra.count >= 8 { st.extra[7] = UInt8(min(max(v, -32), 31) + 32) } }
        }
    }

    private func extraSpec(_ t: Int, _ i: Int, k: Int, label: String, range: ClosedRange<Int>, shown: @escaping (Int) -> String,
                           choices: [String]? = nil) -> KnobSpec {
        let s = session.tracks[t].steps[i], v = s.extra.count > k ? min(max(Int(s.extra[k]), range.lowerBound), range.upperBound) : range.lowerBound
        return KnobSpec(id: "step.\(label)", colour: Theme.track[t], label: label, value: v, range: range, stepperStep: 1,
                        shown: shown(v), spoken: shown(v), bipolar: false, defaultValue: range.lowerBound == 0 && label == "CHANCE" ? 100 : 0,
                        choices: choices) { n in write(t, i) { st in if st.extra.count > k { st.extra[k] = UInt8(n) } } }
    }

    // MARK: The sound at this step

    /// What the track's sound is at this step, a parameter a line: its mark (recorded, locked, the sound's own), name and
    /// value; the source said to VoiceOver. Collapsed (a short box), behind "Sound at this step".
    @ViewBuilder private func soundAtStep(_ t: Int, _ i: Int, _ tint: Color, collapsed: Bool) -> some View {
        let m = session.motion[t] ?? TrackMotion()
        let ids = MotionLanes.laneIDs(session, ui, track: t)
        if ids.isEmpty {
            Text("Nothing recorded or locked on T\(t + 1).").font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
        } else if collapsed {
            Button {
                ui.menu = JibMenu(title: "Sound at step \(i + 1)", groups: {
                    [ids.map { id in
                        let r = m.value(of: id, at: i, base: session.cell(id).value)
                        let mark = r.source == .lock ? "◆ " : r.source == .recorded ? "— " : ""
                        return MenuItem.note("\(mark)\(session.trackDesc(id)?.label ?? "\(id)")  \(formatValue(session.trackDesc(id), r.value).shown)")
                    }]
                }, at: CGPoint(x: soundFrame.minX, y: soundFrame.maxY))
            } label: {
                HStack(spacing: 4) {
                    Text("Sound at this step").font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { soundFrame = $0 }
            .accessibilityHint("Lists what each recorded parameter is at this step")
        } else {
            rows(ids, m, i, tint)
        }
    }

    private func rows(_ ids: [Int], _ m: TrackMotion, _ i: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ids, id: \.self) { id in
                let base = session.cell(id).value
                let r = m.value(of: id, at: i, base: base)
                let name = session.trackDesc(id)?.label ?? "\(id)"
                let value = formatValue(session.trackDesc(id), r.value).shown
                HStack(spacing: 10) {
                    Group {
                        switch r.source {
                        case .lock: Diamond(colour: tint).frame(width: 12, height: 12)
                        case .recorded: RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 12, height: 3)
                        case .sound: Rectangle().stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [3, 2])).frame(width: 12, height: 1)
                        }
                    }
                    .frame(width: 16)
                    Text(name).font(.system(size: 13)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                }
                .frame(height: 26)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(name), \(value), " + (r.source == .lock ? "locked on this step" : r.source == .recorded ? "recorded" : "the sound's own"))
            }
        }
    }

    /// Knob turns to this step: a lock there, as holding a step and turning a knob does on the FM-1.
    private func lockKey(_ i: Int, compact: Bool = false) -> some View {
        Button {
            session.lockStep = session.lockStep == nil ? i : nil
        } label: {
            Label(compact ? "Lock" : session.lockStep == nil ? "Lock knob turns to step \(i + 1)" : "Locking knob turns to step \(i + 1)",
                  systemImage: session.lockStep == nil ? "lock.open" : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(session.lockStep == nil ? Theme.text : Theme.onColour)
                .padding(.horizontal, compact ? 12 : 0)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(session.lockStep == nil ? Theme.control : Theme.text))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(session.song.songPlaying)
        .accessibilityLabel(session.lockStep == nil ? "Lock knob turns to step \(i + 1)" : "Locking knob turns to step \(i + 1)")
        .accessibilityHint("While on, turning a knob of this track sets a lock on this step instead of changing the sound")
        .accessibilityAddTraits(.isToggle)
    }
}
