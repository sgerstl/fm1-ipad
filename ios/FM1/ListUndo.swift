import SloopKit
import SwiftUI

// Clearing a pad or deleting Timeline blocks without a confirm, with an Undo (batch item 13 and its follow-up, Scott
// 2026-11-15; P1's SloopKit route, 2ea3f0c). LIST CLEAR erases a pattern nothing else names, for good; LIST SET doesn't.
// So an entry whose pattern would be erased is set to REST first, and then removed: the pattern stays kept on the FM-1
// for the undo. Undo rewrites the track's list as it was (patterns, REPS, chains, sounds). When the undo ends (anything
// else changes the song), each kept pattern still unused is cleared with POOL op 1, stopped, as the FM-1's own CLEAR
// would have left it. One strip for the app (ListUndoStrip, at the root): what went, and Undo, for 8 s; the pad's or
// block's menu keeps Undo until the next change. iPhone and iPad.

@MainActor
enum ListUndo {
    /// Whether the last removal can still be undone: nothing has changed the song since.
    static func undoable(_ ui: EditorUI, _ store: SkiffSongStore) -> Bool {
        ui.padClear.map { $0.depth == store.undoStack.count && $0.depth > 0 } ?? false
    }

    static func undo(_ ui: EditorUI, _ store: SkiffSongStore) {
        guard undoable(ui, store), let c = ui.padClear else { return }
        ui.padClear = nil
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

/// The Undo strip, at the foot of the screen over every tab: what went, and Undo, for 8 s (or until anything else
/// changes the song); then the pad's or block's menu keeps Undo until the next change.
struct ListUndoStrip: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if let store = session.skiffSong, let c = ui.padClear, ListUndo.undoable(ui, store), !c.stripGone {
                HStack(spacing: 10) {
                    Text(c.title).font(.lupe(14)).lineLimit(1)
                    Spacer(minLength: 0)
                    Button { ListUndo.undo(ui, store) } label: {
                        Text("Undo").font(.lupe(14, .semibold)).padding(.horizontal, 14).frame(height: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(PressSink())
                    .accessibilityHint("Puts it back")
                }
                .padding(.leading, 14).padding(.trailing, 6)
                .frame(maxWidth: 520)
                .background(RoundedRectangle(cornerRadius: 12).fill(Elevation.held.surface).elevationShadow(.held))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id(c.id)
                .task(id: c.id) {
                    try? await Task.sleep(for: .seconds(8))
                    if ui.padClear?.id == c.id { ui.padClear?.stripGone = true }
                }
                .onAppear { UIAccessibility.post(notification: .announcement, argument: c.title + ". Undo is available") }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, ui.phone ? 44 : 72)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3), value: ui.padClear?.id)
        // anything else changing the song ends the undo: its kept patterns go
        .onChange(of: session.skiffSong?.undoStack.count) { _, n in
            if let c = ui.padClear, let store = session.skiffSong, c.depth != n { ui.padClear = nil; ListUndo.finish(c, store, session) }
        }
    }
}
