// Edit's undo and redo (Scott, 2026-11-18: "undo, with long press to redo"). One edit (a tap, a drag, a resize, a tile's slide, Clear step,
// Paste) is one undo step: the screen sends `undoMark` with a label when a gesture starts, and the step edits that follow belong to it. Before
// the first of them the pattern's steps are kept as they were; a moment after the last, as they became. Undo writes the steps it touched back,
// redo writes them forward. If the FM-1 has changed one of those steps since (recorded over it, a knob turned), the undo is skipped with a
// message, so nothing the FM-1 did is clobbered. The FM-1's own knob turns are never recorded: they aren't the phone's edits.
// Per pattern, for the session, 50 deep; a new edit after an undo clears the redo. Locks live in the automation store, not the steps, so
// clearing a step's locks isn't undone here.
import Foundation
import SloopKit

struct StepUndoEntry {
    var key: String
    var track: Int
    var label: String
    var before: [SynthStep]
    var after: [SynthStep]
    /// The steps this edit changed.
    func touched(_ s: DeviceSession) -> [Int] { before.indices.filter { $0 < after.count && before[$0] != after[$0] } }
}

extension PhoneCore {
    static let undoDepth = 50
    /// The edit intents an undo step records (stepAction's copy changes nothing).
    static let undoableIntents: Set<String> = ["setStepNotes", "toggleStepNote", "toggleHit", "stepAdjust", "stepAction"]

    /// A pattern's history key: the track and the pattern it is on.
    func undoKey(_ t: Int) -> String { "\(t):\(session.skiffSong?.song?.tracks[safe: t]?.patternOn.map(String.init) ?? "-")" }

    private struct UndoWire: Decodable { let intent: String; let label: String?; let action: String? }

    func handleStepUndoJSON(_ json: String) -> Bool {
        guard json.contains("\"undoMark\"") || json.contains("\"stepUndo\"") || json.contains("\"stepRedo\""),
              let w = try? JSONDecoder().decode(UndoWire.self, from: Data(json.utf8)) else { return false }
        switch w.intent {
        case "undoMark": closeUndo(); undoLabelNext = w.label
        case "stepUndo": closeUndo(); stepUndo()
        case "stepRedo": closeUndo(); stepRedo()
        default: return false
        }
        pokeAreas(["editor"])
        return true
    }

    /// Before an edit intent: the pattern as it is, if no undo step is open for it yet. After: as it became, a moment later.
    func noteUndoable(_ json: String) {
        guard canWrite(), let w = try? JSONDecoder().decode(UndoWire.self, from: Data(json.utf8)), Self.undoableIntents.contains(w.intent),
              !(w.intent == "stepAction" && w.action == "copy") else { return }
        let t = editorTrack(), key = undoKey(t)
        guard session.tracks.indices.contains(t) else { return }
        if openUndo?.key != key { closeUndo() }
        if openUndo == nil {
            let now = session.tracks[t].steps
            openUndo = StepUndoEntry(key: key, track: t, label: undoLabelNext ?? "edit", before: now, after: now)
            undoLabelNext = nil
        }
        undoAfterTask?.cancel()
        undoAfterTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, let self, var e = self.openUndo, self.session.tracks.indices.contains(e.track) else { return }
            e.after = self.session.tracks[e.track].steps
            self.openUndo = e
            self.pokeAreas(["editor"])
        }
    }

    /// The open undo step ends (its "after" taken now if the moment hasn't come); kept when it changed anything, and the redo cleared.
    func closeUndo() {
        undoAfterTask?.cancel(); undoAfterTask = nil
        guard var e = openUndo else { return }
        openUndo = nil
        if session.tracks.indices.contains(e.track), e.after == e.before { e.after = session.tracks[e.track].steps }
        guard !e.touched(session).isEmpty else { return }
        stepUndos[e.key, default: []].append(e)
        if stepUndos[e.key]!.count > Self.undoDepth { stepUndos[e.key]!.removeFirst() }
        stepRedos[e.key] = []
    }

    private func stepUndo() {
        let key = undoKey(editorTrack())
        guard var stack = stepUndos[key], let e = stack.popLast() else { return }
        stepUndos[key] = stack
        guard apply(e, from: e.after, to: e.before) else { return }
        stepRedos[key, default: []].append(e)
    }

    private func stepRedo() {
        let key = undoKey(editorTrack())
        guard var stack = stepRedos[key], let e = stack.popLast() else { return }
        stepRedos[key] = stack
        guard apply(e, from: e.before, to: e.after) else { return }
        stepUndos[key, default: []].append(e)
    }

    /// Writes [to] over the touched steps, if each is still as [from] left it; otherwise nothing, with a message (the FM-1 changed it since).
    private func apply(_ e: StepUndoEntry, from: [SynthStep], to: [SynthStep]) -> Bool {
        guard canWrite() else { refuseReadOnly("stepUndo"); return false }
        let s = session
        guard s.tracks.indices.contains(e.track) else { return false }
        let idx = e.touched(s)
        let now = s.tracks[e.track].steps
        if let changed = idx.first(where: { $0 < now.count && now[$0] != from[$0] }) {
            refuse("Step \(changed + 1) changed on the FM-1 since, so that undo was skipped.", track: e.track + 1)
            return false
        }
        for i in idx where i < to.count { s.write(track: e.track, index: i, to[i]) }
        pokeAreas(["editor"])
        return true
    }
}
