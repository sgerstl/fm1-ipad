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

/// What's picked and what can be done to it, and the line after a change (with Undo). Icon keys (Scott, 2026-11-06:
/// the old bar of words covered the velocity and the motion lanes): on the Song tab it sits in the pattern header's
/// empty middle, under the divider's handle (`inline`), so nothing over the grid's foot is covered; on Sequence it
/// still floats over the grid's foot. Every key is 44 pt to touch (36 pt drawn), named for VoiceOver and the pointer.
struct SelectionBar: View {
    let edits: StepEdits
    var notes = true                      // the drum grid: steps only (no transpose)
    var inline = false                    // the Song tab's pattern header: no floating panel of its own

    var body: some View {
        let ui = edits.ui
        let undo = ui.patternUndo.flatMap { $0.track == edits.track ? $0 : nil }
        let picking = edits.any || ui.clip != nil
        HStack(spacing: 0) {
            if picking {
                Text(ui.stepSel.isEmpty ? "\(ui.noteSel.count) note\(ui.noteSel.count == 1 ? "" : "s")" : "steps \(label(ui.stepSel))")
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
                    .padding(.horizontal, 8)
                if edits.any {
                    icon("plus.square.on.square", "Duplicate after", primary: true) { edits.duplicateAfter() }
                    icon("doc.on.doc", "Copy") { edits.copy() }
                }
                if ui.clip != nil { icon("doc.on.clipboard", "Paste at the selected step") { edits.paste() } }
                if edits.any {
                    gap
                    icon("arrow.left", "Move a step earlier") { edits.move(by: -1) }
                    icon("arrow.right", "Move a step later") { edits.move(by: 1) }
                    if notes {
                        gap
                        icon("arrow.down", "Transpose down a semitone") { edits.transpose(-1) }
                        icon("arrow.up", "Transpose up a semitone") { edits.transpose(1) }
                    }
                    gap
                    icon("trash", "Delete") { edits.delete() }
                    icon("xmark", "Cancel the selection") { edits.clear() }.keyboardShortcut(.cancelAction)
                }
            }
            if let u = undo {
                if picking { gap }
                // what changed, in words while there's room (it gives way first), and Undo
                Text(u.said).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    .padding(.horizontal, 6).layoutPriority(-1)
                    .accessibilityHidden(true)
                icon("arrow.uturn.backward", "Undo: \(u.said)") { edits.undo() }.keyboardShortcut("z", modifiers: .command)
                if !picking { icon("xmark", "Dismiss") { ui.patternUndo = nil } }
            }
        }
        .padding(.horizontal, inline ? 0 : 4)
        .background { if !inline && (picking || undo != nil) { RoundedRectangle(cornerRadius: 12).fill(Theme.panel).elevationShadow(.selected, Look()) } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection")
    }

    /// 8 pt more between groups (the keys already sit 8 pt apart inside their 44 pt targets).
    private var gap: some View { Color.clear.frame(width: 8, height: 1).accessibilityHidden(true) }

    private func label(_ s: Set<Int>) -> String {
        guard let a = s.min(), let b = s.max() else { return "" }
        return s.count == b - a + 1 ? (a == b ? "\(a + 1)" : "\(a + 1)–\(b + 1)") : "\(s.count) picked"
    }

    private func icon(_ s: String, _ label: String, primary: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: s).font(.system(size: 15, weight: .semibold)).foregroundStyle(primary ? Theme.onColour : Theme.text)
                .frame(width: 36, height: 36).raisedKey(primary: primary)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .help(label)
        .accessibilityLabel(label)
    }
}
