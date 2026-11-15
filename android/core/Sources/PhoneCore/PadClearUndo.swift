// Clearing a pad without a confirm, with an Undo (batch item 13, Scott 2026-11-15), and the pattern's step count
// (batch item 9).
//
// The FM-1's own CLEAR (LIST op 4) erases the entry's pattern for good when nothing else names it (bank.c bank_put),
// and it keeps no copy, so an undo after that would have nothing to put back. LIST SET, though, only changes what the
// entry names (bank.c song_put: `lists.ent[k][e][0] = p`); the pattern it named stays in the pool. So where a clear
// would erase the pattern, the core sets the entry to a REST first and then clears the REST (song_clear_at: a REST
// goes at once, nothing goes with it). The pad is empty and the pattern is still kept, named by nothing. Undo sets
// the entry back. When the undo's time is up the core clears that pattern itself (POOL op 1, stopped only), if still
// nothing uses it, which leaves the FM-1 as its own CLEAR would have.
import Foundation
import SloopKit

extension PadsArea {
    /// A pad just cleared that undoClear can still put back.
    public struct ClearUndo: Codable, Equatable, Sendable {
        public var track: Int            // 1…6
        public var entry: Int            // 0…15
        /// What it held: a pattern number 1…64, or nil for a REST.
        public var pattern: Int?
    }
}

/// A cleared pad the core remembers.
struct ClearedPad {
    var track: Int, entry: Int           // 0-based
    var before: [SongEntry]              // the track's list before the clear
    var after: [SongEntry]               // … and after it, as the FM-1 answered
    /// The pattern (1…64) kept alive for the undo: cleared for real when the undo's time is up.
    var parked: Int?
    var at: Date
    var undoable = true
}

extension PhoneCore {
    /// How long a cleared pad can be put back.
    static var undoClearWindow: TimeInterval = 10

    func clearUndos() -> [PadsArea.ClearUndo] {
        clearedPads.filter(\.undoable).map { .init(track: $0.track + 1, entry: $0.entry, pattern: $0.before[safe: $0.entry]?.poolIndex.map { $0 + 1 }) }
    }

    /// padClear: no confirm. What the pad held is remembered for undoClear.
    func clearPad(track t: Int, entry e: Int) {
        guard let store = session.skiffSong, let list = store.song?.tracks[safe: t], list.entries.indices.contains(e) else {
            refuse("The FM-1's song hasn't been read yet. Try again in a moment."); return
        }
        let was = list.entries[e]
        guard !was.isEmpty else { log("padClear: T\(t + 1) entry \(e) is empty already"); return }
        // a pattern's pad: stopped only, as the FM-1's own CLEAR (a REST goes at once, playing too)
        if !was.isRest, session.playing {
            refuse("Stop playback to clear a pad that holds a pattern. The FM-1 only clears one while stopped.", track: t + 1, entry: e); return
        }
        var emptied = list.entries
        emptied[e] = .empty
        let erases = !was.isRest && !store.erased([t: emptied]).isEmpty
        Task {
            // where the FM-1 would erase the pattern: a REST first, so the pattern stays kept for the undo
            if erases, !(await store.send(.set(track: t, entry: e, pattern: SongEntry.rest))) { self.reportRefusal(store); return }
            guard await store.send(.clear(track: t, entry: e)) else { self.reportRefusal(store); return }
            self.clearedPads.removeAll { $0.track == t && $0.entry == e }
            self.clearedPads.append(ClearedPad(track: t, entry: e, before: list.entries, after: store.song?.tracks[safe: t]?.entries ?? emptied,
                                               parked: erases ? was.pattern : nil, at: Date()))
            self.pokeAreas(["pads", "timeline", "patterns", "editor"])
        }
    }

    private struct UndoWire: Decodable { let intent: String; let track: Int?; let entry: Int?; let steps: Int? }

    /// undoClear{track, entry} (or with neither: the last clear) and setPatternSteps{steps}. True when `json` was one of them.
    func handleUndoClearJSON(_ json: String) -> Bool {
        guard json.contains("\"undoClear\"") || json.contains("\"setPatternSteps\""),
              let w = try? JSONDecoder().decode(UndoWire.self, from: Data(json.utf8)), ["undoClear", "setPatternSteps"].contains(w.intent) else { return false }
        guard canWrite() else { refuseReadOnly(w.intent); return true }
        if w.intent == "setPatternSteps" { setPatternSteps(w.steps); return true }
        // no track and entry: the last pad cleared that can still come back
        let last = clearedPads.last(where: \.undoable)
        guard let t1 = w.track ?? last.map({ $0.track + 1 }), let e = w.entry ?? last?.entry else {
            refuse("There is no clear to undo any more."); return true
        }
        let t = t1 - 1
        guard let k = clearedPads.firstIndex(where: { $0.track == t && $0.entry == e && $0.undoable }),
              let store = session.skiffSong, let now = store.song?.tracks[safe: t]?.entries else {
            refuse("That clear can't be undone any more.", track: t1, entry: e); return true
        }
        let c = clearedPads[k]
        let was = c.before[e]
        if let p = was.poolIndex, (store.pool?.patterns[safe: p]?.length ?? 0) == 0 {
            clearedPads.remove(at: k)
            refuse("Pattern \(was.label) is gone from the FM-1, so the pad can't come back.", track: t1, entry: e); return true
        }
        guard now[e].isEmpty else {
            clearedPads.remove(at: k)
            refuse("T\(t1) pad \(e + 1) holds something new, so the clear wasn't undone.", track: t1, entry: e); return true
        }
        // nothing else changed on the track since: the whole list as it was (a chain's link with it); else this pad alone
        var back = now
        if now == c.after { back = c.before } else { back[e] = was; back[e].chained = false }
        clearedPads.remove(at: k)
        pokeAreas(["pads"])
        Task {
            if !(await store.rewrite(track: t, to: back, focus: e, confirmed: true)) { self.reportRefusal(store) }
            self.pokeAreas(["pads", "timeline", "patterns", "editor"])
        }
        return true
    }

    /// The undo's time over: the record goes, and a pattern kept alive for it is cleared as the FM-1's CLEAR would
    /// have (POOL op 1), once stopped, if nothing uses it. Called from the core's half-second loop.
    func pollClearedPads() async {
        guard !clearedPads.isEmpty else { return }
        let now = Date()
        var changed = false
        for i in clearedPads.indices where clearedPads[i].undoable && now.timeIntervalSince(clearedPads[i].at) > Self.undoClearWindow {
            clearedPads[i].undoable = false; changed = true
        }
        clearedPads.removeAll { !$0.undoable && $0.parked == nil }
        if changed { pokeAreas(["pads"]) }
        guard let store = session.skiffSong, session.isConnected else { clearedPads.removeAll(); return }
        // not in the middle of the person's own changes: a second quiet first (the store takes one change at a time)
        guard !session.playing, !store.busy, now.timeIntervalSince(store.lastChange) > 1, let pool = store.pool?.patterns, pool.count == 64,
              let k = clearedPads.firstIndex(where: { !$0.undoable }), let n = clearedPads[k].parked else { return }
        clearedPads.remove(at: k)
        // used again since (put on a pad from the Patterns sheet), or gone: left as it is
        guard pool[n - 1].length > 0, pool[n - 1].uses == 0,
              !(store.song?.tracks.contains { $0.patternOn == n - 1 } ?? false) else { return }
        let rc = await store.poolOp(1, pattern: n - 1)
        log(rc.isDone ? "padClear: pattern \(n) cleared, its undo's time over" : "padClear: pattern \(n) not cleared (\(rc)); it stays as an unused pattern")
        pokeAreas(["pads", "patterns", "timeline"])
    }

    /// LENGTH (Skiff's P_SLEN, SEQ › PATTERN's knob 1; found by its DESC label, so the same on 2.2 and 2.5.1): the
    /// editor's track's step count, 1…the FM-1's NSTEP.
    func setPatternSteps(_ steps: Int?) {
        let s = session, t = editorTrack()
        guard s.isConnected, s.tracks.indices.contains(t) else { refuse("The FM-1 hasn't been read yet. Try again in a moment."); return }
        guard let steps else { log("setPatternSteps: missing steps"); return }
        let n = max(1, min(s.stepCount, steps))
        if s.selectedTrack != t { s.select(track: t) }
        s.set(track: t, param: s.ids.length, to: n)
        pokeAreas(["editor"])
    }
}
