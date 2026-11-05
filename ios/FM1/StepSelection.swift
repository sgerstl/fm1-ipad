import SloopKit
import SwiftUI

// Step editing (Scott, 2026-11-05): picked notes (a tap; a hold on empty grid, then a box) or picked steps (a drag
// along the step numbers; taps add or take off), and what can be done to them, as Arrange's section bar does for
// bars: Duplicate after (the pattern grows to fit, up to 64), Copy, Paste, Move, Transpose, Delete, Cancel. Writes
// go through TRACK_STEP as every edit does (Session.writePattern).

@MainActor
struct StepEdits {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    /// The roll's rows, top to bottom (high to low): a move or transpose by rows follows the folded scale.
    var rows: [Int] = []

    var steps: [SynthStep] { session.tracks[track].steps }
    /// What's picked: the notes, or every note on the picked steps.
    var refs: Set<NoteRef> { ui.stepSel.isEmpty ? ui.noteSel : PatternEdit.notes(steps, in: ui.stepSel) }
    var stepRange: ClosedRange<Int>? { ui.stepSel.isEmpty ? nil : ui.stepSel.min()!...ui.stepSel.max()! }
    var any: Bool { !ui.noteSel.isEmpty || !ui.stepSel.isEmpty }

    /// One change: the steps before it kept for Undo, then the steps that changed written.
    func apply(_ said: String? = nil, _ change: (inout [SynthStep], inout Int) -> Void) {
        var s = steps, len = session.tracks[track].length
        let before = (s, len)
        change(&s, &len)
        guard s != before.0 || len != before.1 else { return }
        ui.patternUndo = PatternUndo(track: track, steps: before.0, length: before.1, said: said ?? "Changed")
        session.writePattern(track: track, s, length: len)
    }

    func undo() {
        guard let u = ui.patternUndo, u.track == track else { return }
        ui.patternUndo = nil
        session.writePattern(track: track, u.steps, length: u.length)
    }

    func clear() { ui.noteSel = []; ui.stepSel = [] }

    /// A pitch by rows (the roll's folded rows), or by a semitone where the rows don't reach.
    func byRows(_ d: Int) -> (Int) -> Int? {
        { n in
            if let r = rows.firstIndex(of: n), rows.indices.contains(r - d) { return rows[r - d] }
            return n + d
        }
    }

    func duplicateAfter() {
        var said = ""
        apply("Duplicated") { s, len in
            let r = PatternEdit.duplicateAfter(&s, steps: stepRange, notes: stepRange == nil ? refs : nil, length: &len)
            guard let r else { said = "No room after it: a pattern has 64 steps at most"; return }
            said = "steps \(r.added.lowerBound + 1)–\(r.added.upperBound + 1) added" + (r.newLength != r.oldLength ? ", length \(r.oldLength) → \(r.newLength)" : "")
        }
        if ui.patternUndo != nil, !said.isEmpty { ui.patternUndo?.said = said }
    }

    func copy() {
        guard let span = stepRange ?? PatternEdit.span(steps, refs) else { return }
        var clip = Array(steps[span])
        if stepRange == nil {
            // notes picked: only they go on the clip
            for k in clip.indices where clip[k].time == .note {
                clip[k].notes = clip[k].notes.filter { refs.contains(NoteRef(step: span.lowerBound + k, note: $0)) }
                if clip[k].notes.isEmpty { clip[k].time = .rest }
            }
        }
        ui.clip = clip
    }

    func paste() {
        guard let clip = ui.clip else { return }
        let at = ui.selectedStep[track]
        apply("Pasted at step \(at + 1)") { s, len in
            for (k, st) in clip.enumerated() where at + k < s.count {
                if st.time == .note { for n in st.notes { PatternEdit.add(&s, step: at + k, note: n, velocity: st.velocity) } }
                else if st.time == .tie, s[at + k].time == .rest { s[at + k].time = .tie }
            }
            if at + clip.count > len { len = min(PatternEdit.maxSteps, at + clip.count) }
        }
    }

    func move(by d: Int) {
        let picked = refs
        var dest: [NoteRef: NoteRef] = [:]
        apply("Moved") { s, _ in dest = PatternEdit.move(&s, picked, by: d, pitch: { $0 }) }
        reselect(dest)
        if !ui.stepSel.isEmpty { ui.stepSel = Set(ui.stepSel.map { min(63, max(0, $0 + d)) }) }
    }

    func transpose(_ d: Int) {
        let picked = refs
        var dest: [NoteRef: NoteRef] = [:]
        apply("Transposed") { s, _ in dest = PatternEdit.transpose(&s, picked, pitch: { min(127, max(0, $0 + d)) }) }
        reselect(dest)
    }

    func delete() {
        let picked = refs, range = stepRange
        apply("Deleted") { s, _ in
            if let range {
                // whole steps: notes, TIEs and a kit step's hits
                for i in range {
                    s[i].time = .rest; s[i].notes = []; s[i].levels = []; s[i].ratchets = []
                    if s[i].extra.count >= 3 { s[i].extra[0] = 0; s[i].extra[1] = 0; s[i].extra[2] = 0 }
                }
            } else {
                for r in picked { PatternEdit.remove(&s, r) }
            }
        }
        clear()
    }

    func reselect(_ dest: [NoteRef: NoteRef]) {
        if ui.stepSel.isEmpty { ui.noteSel = Set(ui.noteSel.map { dest[$0] ?? $0 }) }
    }
}

/// The bar under the grid while something's picked, and the line after a change (with Undo).
struct SelectionBar: View {
    let edits: StepEdits
    var notes = true                      // the drum grid: steps only (no transpose)

    var body: some View {
        let ui = edits.ui
        VStack(spacing: 6) {
            if let u = ui.patternUndo, u.track == edits.track {
                HStack(spacing: 10) {
                    Text(u.said).font(.system(size: 13))
                    Button("Undo") { edits.undo() }.font(.system(size: 13, weight: .semibold)).frame(minHeight: 36)
                        .keyboardShortcut("z", modifiers: .command)
                    Button { ui.patternUndo = nil } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                        .frame(width: 36, height: 36).accessibilityLabel("Dismiss")
                }
                .padding(.horizontal, 12)
                .background(Capsule().fill(Theme.control))
            }
            if edits.any || ui.clip != nil {
                HStack(spacing: 6) {
                    Text(ui.stepSel.isEmpty ? "\(ui.noteSel.count) note\(ui.noteSel.count == 1 ? "" : "s")" : "steps \(label(ui.stepSel))")
                        .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 8)
                    if edits.any {
                        key("Duplicate after", primary: true) { edits.duplicateAfter() }
                        key("Copy") { edits.copy() }
                    }
                    if ui.clip != nil { key("Paste") { edits.paste() } }
                    if edits.any {
                        Text("Move").font(.system(size: 12)).foregroundStyle(Theme.textSecondary).padding(.leading, 4)
                        icon("chevron.left", "Move a step earlier") { edits.move(by: -1) }
                        icon("chevron.right", "Move a step later") { edits.move(by: 1) }
                        if notes {
                            Text("Transpose").font(.system(size: 12)).foregroundStyle(Theme.textSecondary).padding(.leading, 4)
                            icon("minus", "Transpose down a semitone") { edits.transpose(-1) }
                            icon("plus", "Transpose up a semitone") { edits.transpose(1) }
                        }
                        key("Delete") { edits.delete() }
                        key("Cancel") { edits.clear() }.keyboardShortcut(.cancelAction)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel).elevationShadow(.selected, Look()))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection")
    }

    private func label(_ s: Set<Int>) -> String {
        guard let a = s.min(), let b = s.max() else { return "" }
        return s.count == b - a + 1 ? (a == b ? "\(a + 1)" : "\(a + 1)–\(b + 1)") : "\(s.count) picked"
    }

    private func key(_ t: String, primary: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(primary ? Theme.onColour : Theme.text)
                .padding(.horizontal, 10).frame(minHeight: 36).raisedKey(primary: primary).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
    }

    private func icon(_ s: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: s).font(.system(size: 13, weight: .semibold)).frame(width: 36, height: 36).raisedKey().contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(label)
    }
}
