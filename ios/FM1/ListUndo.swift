import SloopKit
import SwiftUI

// Clearing a pad or deleting Timeline blocks without a confirm, with an Undo (batch item 13 and its follow-up, Scott
// 2026-11-15; P1's SloopKit route, 2ea3f0c). LIST CLEAR erases a pattern nothing else names, for good; LIST SET doesn't.
// So an entry whose pattern would be erased is set to REST first, and then removed: the pattern stays kept on the FM-1
// for the undo. Undo rewrites the track's list as it was (patterns, REPS, chains, sounds). When the undo ends (anything
// else changes the song), each kept pattern still unused is cleared with POOL op 1, stopped, as the FM-1's own CLEAR
// would have left it. The app strip (Messages.swift) says what went, with Undo, until the next change or ✕ (the
// messages rule, 2026-11-17: no Undo on a timer); the pad's or block's menu keeps Undo until the next change.

@MainActor
enum ListUndo {
    /// Whether the last removal can still be undone: nothing has changed the song since.
    static func undoable(_ ui: EditorUI, _ store: SkiffSongStore) -> Bool {
        ui.padClear.map { $0.depth == store.undoStack.count && ($0.depth > 0 || $0.steps != nil) } ?? false
    }

    static func undo(_ ui: EditorUI, _ store: SkiffSongStore, _ session: DeviceSession) {
        guard undoable(ui, store), let c = ui.padClear else { return }
        ui.padClear = nil
        // Clear steps: the notes written back (steps edited since are left as they are)
        if let steps = c.steps { StepClear.undo(session, steps); return }
        Task { _ = await store.rewrite(track: c.track, to: c.before, focus: c.entry, confirmed: true) }
    }

    /// The undo ended: kept patterns still unused are cleared, after the store is quiet (it takes one change at a time).
    static func finish(_ c: PadClear, _ store: SkiffSongStore, _ session: DeviceSession) {
        guard !c.keptAll.isEmpty else { return }
        Task {
            while store.busy || Date().timeIntervalSince(store.lastChange) < 1 { try? await Task.sleep(for: .milliseconds(250)) }
            for p in c.keptAll {
                let onTrack = store.song?.tracks.contains { $0.patternOn == p } ?? false
                guard !session.playing, !onTrack, (store.pool?.patterns[safe: p]?.uses ?? 1) == 0 else { continue }
                _ = await store.poolOp(1, pattern: p)
            }
        }
    }

    /// Track t's list becomes `after` (a Timeline delete: the blocks gone, the rest closing up), with no confirm: entries
    /// whose patterns would be erased go to REST first so the patterns stay for the undo.
    static func remove(track t: Int, entries range: ClosedRange<Int>, after: [SongEntry], what: String,
                       store: SkiffSongStore, session: DeviceSession, ui: EditorUI) {
        guard let list = store.song?.tracks[safe: t] else { return }
        let before = list.entries
        // refused before anything is sent (P1, 4d2e44a): otherwise the REST steps would land and the rewrite then refuse
        if let why = store.blocked(track: t, to: after) {
            store.refuse(track: t, entry: range.lowerBound, why, needsStop: why.hasPrefix("Stop")); return
        }
        let gone = Set(store.erased([t: after]))
        if !gone.isEmpty, session.playing {
            store.refuse(track: t, entry: range.lowerBound, "Stop to delete: the FM-1 changes the song only while stopped", needsStop: true)
            return
        }
        let toRest = range.filter { i in list.entries[safe: i]?.poolIndex.map(gone.contains) ?? false }
        Task {
            for i in toRest { guard await store.send(.set(track: t, entry: i, pattern: SongEntry.rest)) else { return } }
            guard await store.rewrite(track: t, to: after, focus: range.lowerBound, confirmed: true) else { return }
            if let old = ui.padClear { finish(old, store, session) }
            ui.padClear = PadClear(track: t, entry: range.lowerBound, what: what, depth: store.undoStack.count, before: before,
                                   kept: nil, keptAll: Array(gone))
        }
    }
}
