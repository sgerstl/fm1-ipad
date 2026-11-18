// Clearing a pad without a confirm, with an Undo (batch item 13, Scott 2026-11-15), and the pattern's step count
// (batch item 9).
//
// The FM-1's own CLEAR (LIST op 4) erases the entry's pattern for good when nothing else names it (bank.c bank_put),
// and it keeps no copy, so an undo after that would have nothing to put back. LIST SET, though, only changes what the
// entry names (bank.c song_put: `lists.ent[k][e][0] = p`); the pattern it named stays in the pool. So where a clear
// would erase the pattern, the core sets the entry to a REST first and then clears the REST (song_clear_at: a REST
// goes at once, nothing goes with it). The pad is empty and the pattern is still kept, named by nothing. Undo sets
// the entry back. When the undo ends the core clears that pattern itself (POOL op 1, stopped only), if still nothing
// uses it, which leaves the FM-1 as its own CLEAR would have.
//
// How long: until the next change to the song, never a timer (Scott, 2026-11-17, messages rule: "Undo: until the next
// edit or ✕. Nothing with an action leaves on a timer."). Any other edit ends it (endUndos, from handle(json:)); the
// strip's ✕ only hides the strip, so the pad's and the Timeline's menus keep "Undo clear" / "Undo delete" as long.
import Foundation
import SloopKit

extension PadsArea {
    /// A pad just cleared that undoClear can still put back.
    public struct ClearUndo: Codable, Equatable, Sendable {
        public var track: Int            // 1…6
        public var entry: Int            // 0…15
        /// What it held: a pattern number 1…64, or nil for a REST. A block: its first entry's.
        public var pattern: Int?
        /// A Timeline block deleted (`entry` is the block's id, its first entry), not one pad cleared.
        public var block = false
        /// What was taken: "pad" (the pad cleared), "block" (a Timeline block deleted) or "steps" (the pattern's notes
        /// wiped by clearSteps; the pad and its pattern stayed).
        public var kind = "pad"
    }
}

/// A cleared pad the core remembers.
struct ClearedPad {
    var track: Int, entry: Int           // 0-based
    var before: [SongEntry]              // the track's list before the clear
    var after: [SongEntry]               // … and after it, as the FM-1 answered
    /// The patterns (1…64) kept alive for the undo: cleared for real once the undo has ended.
    var parked: [Int] = []
    /// A Timeline block's delete: undone whole, or not at all.
    var block = false
    /// clearSteps: the track's steps as they were, and the pattern (0…63) they belong to.
    var steps: [SynthStep]?
    var stepsPattern: Int?
    /// The track's pad keys before it (EntryKeys.swift): an undo gives them back.
    var keys: [Int] = []
    var at: Date
    var undoable = true
}

extension PhoneCore {
    /// The intents that change the song: what the lists hold (pads, blocks), the patterns (steps, notes, length, locks,
    /// lanes), the scenes, the sounds on a track or pad, and the project itself. Any of them ends the undos (Scott,
    /// 2026-11-17, messages rule). Not here, so an undo outlives them: transport, tempo, launch and playback mode,
    /// selection, mute, solo, the mix's faders and the sound pages' knobs (playing the song, not editing it), the
    /// screens' own choices, and undoClear itself.
    static let songEdits: Set<String> = [
        "padNew", "padSet", "padClear", "padMove", "clearSteps", "setPatternSteps", "sceneStore",
        "stepAdjust", "lockClear", "locksClearAll", "stepAction", "setStepNotes", "toggleStepNote", "toggleHit",
        "blockInsert", "blockNew", "blockMove", "blockStretch", "blockDelete", "blockSetPattern", "blockDuplicate", "blockChain", "blockSplit",
        "drawLane", "clearLane", "clearPatterns", "recyclePattern", "copyPattern", "clearUnusedPatterns",
        "pickPreset", "pickUser", "clearEntrySound", "projectLoad",
    ]

    private struct EditWire: Decodable { let intent: String; let action: String? }

    /// Whether `json` is an intent that changes the song (songEdits; copying a step doesn't), and its name. Nil when
    /// no undo is open, so the common case decodes nothing.
    func songEdit(_ json: String) -> String? {
        guard clearedPads.contains(where: \.undoable),
              let w = try? JSONDecoder().decode(EditWire.self, from: Data(json.utf8)), Self.songEdits.contains(w.intent),
              !(w.intent == "stepAction" && w.action == "copy") else { return nil }
        return w.intent
    }

    /// After an edit's handler has run (handle(json:)): every undo still open ends. A write refused while read-only or
    /// refused on the spot (`refusedNow`: "Stop to rearrange", "isn't playing that pad") changed nothing, so it ends
    /// nothing. The handler's own sends are still to come, so a clear ends the clears before it and then offers its own.
    func endUndos(after intent: String, refusedNow: Bool) {
        guard !refusedNow, canWrite(), clearedPads.contains(where: \.undoable) else { return }
        if intent == "projectLoad" {
            // another project: its pattern numbers aren't the cleared pad's, so nothing parked is cleared on it
            clearedPads.removeAll()
        } else {
            for i in clearedPads.indices { clearedPads[i].undoable = false }
        }
        pokeAreas(["pads", "timeline"])
    }

    func clearUndos() -> [PadsArea.ClearUndo] {
        clearedPads.filter(\.undoable).map { .init(track: $0.track + 1, entry: $0.entry, pattern: $0.before[safe: $0.entry]?.poolIndex.map { $0 + 1 }, block: $0.block,
                                                    kind: $0.steps != nil ? "steps" : $0.block ? "block" : "pad") }
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
        let keysBefore = entryKeys(t)
        Task {
            // where the FM-1 would erase the pattern: a REST first, so the pattern stays kept for the undo
            if erases, !(await store.send(.set(track: t, entry: e, pattern: SongEntry.rest))) { self.reportRefusal(store); return }
            guard await store.send(.clear(track: t, entry: e)) else { self.reportRefusal(store); return }
            self.clearedPads.removeAll { $0.track == t && $0.entry == e }
            self.clearedPads.append(ClearedPad(track: t, entry: e, before: list.entries, after: store.song?.tracks[safe: t]?.entries ?? emptied,
                                               parked: erases ? [was.pattern] : [], keys: keysBefore, at: Date()))
            self.pokeAreas(["pads", "timeline", "patterns", "editor"])
        }
    }

    /// blockDelete: no confirm either. The track's list rewritten without the block; the patterns that would be left
    /// with nothing naming them are kept for the undo (an entry the rewrite would CLEAR, erasing its pattern, is set
    /// to a REST first), and cleared when the undo's time is up.
    func deleteBlock(track t: Int, to es: [SongEntry], block id: Int, removing: [Int]) {
        guard let store = session.skiffSong, let list = store.song?.tracks[safe: t] else { return }
        if let why = store.blocked(track: t, to: es) { refuse("Delete: \(why)", track: t + 1, entry: id); return }
        // the pads after the block keep their keys as they move up
        let keysBefore = entryKeys(t)
        var moved = keysBefore.indices.filter { !removing.contains($0) }.map { keysBefore[$0] }
        moved += Array(repeating: 0, count: max(0, keysBefore.count - moved.count))
        hintKeys(track: t, to: es, keys: moved)
        let gone = store.erased([t: es])
        let rests = list.entries.indices.filter { i in es[i].isEmpty && (list.entries[i].poolIndex.map { gone.contains($0) } ?? false) }
        Task {
            for i in rests {
                guard await store.send(.set(track: t, entry: i, pattern: SongEntry.rest)) else {
                    self.reportRefusal(store)
                    _ = await store.rewrite(track: t, to: list.entries, focus: id, confirmed: true)      // as it was
                    return
                }
            }
            guard await store.rewrite(track: t, to: es, focus: id, confirmed: true) else {
                self.reportRefusal(store)
                if !rests.isEmpty { _ = await store.rewrite(track: t, to: list.entries, focus: id, confirmed: true) }
                return
            }
            self.clearedPads.removeAll { $0.track == t }             // (the list moved: an older undo on it no longer fits)
            self.clearedPads.append(ClearedPad(track: t, entry: id, before: list.entries, after: store.song?.tracks[safe: t]?.entries ?? es,
                                               parked: gone.map { $0 + 1 }, block: true, keys: keysBefore, at: Date()))
            self.pokeAreas(["pads", "timeline", "patterns", "editor"])
        }
    }

    /// padMove{track, from, toTrack, to}: a pad dragged to another place, as the iPad's drag (SloopKit's PadMove and
    /// the song store's rewrite; pattern-pad.md B15–B17). Its own track only: onto a filled pad the two swap; onto an
    /// empty one it moves there (past the list's end: to the first empty place) and its old place stays empty (B18 is
    /// open; this is what the iPad does today). Stopped only: Skiff rewrites a list only while stopped.
    func movePad(track t: Int, from: Int, toTrack: Int, to: Int) {
        guard let store = session.skiffSong, let list = store.song?.tracks[safe: t], list.entries.indices.contains(from),
              list.entries.indices.contains(to), store.song?.tracks.indices.contains(toTrack) == true else {
            refuse("The FM-1's song hasn't been read yet. Try again in a moment."); return
        }
        guard !list.entries[from].isEmpty else { log("padMove: T\(t + 1) entry \(from) is empty"); return }
        guard toTrack == t else {
            // the iPad: a filled pad of another row takes nothing; an empty one is offered a copy or the same pattern
            refuse("A pad moves only within its own track. To use this pattern on T\(toTrack + 1), put it there (the same pattern, shared) or copy it.",
                   track: t + 1, entry: from)
            return
        }
        guard !session.playing else {
            refuse("Stop to rearrange: the FM-1 moves pads only while stopped.", track: t + 1, entry: from); return
        }
        guard let r = PadMove.apply(list.entries, from: from, to: to) else { log("padMove: nothing to move"); return }
        if let why = store.blocked(track: t, to: r.entries) { refuse(why, track: t + 1, entry: from); return }
        clearedPads.removeAll { $0.track == t && $0.steps == nil }      // (the list moved: an undo of an older clear no longer fits)
        // the keys travel with their pads: a swap, or the one pad to where it lands
        var k = entryKeys(t)
        if list.entries[to].isEmpty { k[r.landed] = k[from]; if r.landed != from { k[from] = 0 } } else { k.swapAt(from, to) }
        hintKeys(track: t, to: r.entries, keys: k)
        Task {
            guard await store.rewrite(track: t, to: r.entries, focus: r.landed, confirmed: true) else { self.reportRefusal(store); return }
            // the editor's pad goes with it
            if let p = self.pickedPad, p.track == t + 1 {
                if p.entry == from { self.pickedPad = PadsArea.Ref(track: t + 1, entry: r.landed) }
                else if p.entry == r.landed, !list.entries[to].isEmpty { self.pickedPad = PadsArea.Ref(track: t + 1, entry: from) }
            }
            self.pokeAreas(["pads", "timeline", "patterns", "editor"])
        }
    }

    /// A step with a note, a tie or a drum hit in it.
    static func holdsSomething(_ st: SynthStep) -> Bool {
        !st.notes.isEmpty || st.time == .tie || (0..<8).contains { st.kitLanes.has($0) }
    }

    /// clearSteps{track, entry}: the pattern's notes wiped, its pad and every entry naming it kept. Each step written
    /// empty (TRACK_STEP, which Skiff takes while playing), not POOL's EMPTY, so it works playing and what was there
    /// can be written back. TRACK_STEP writes the pattern the track is on: a pad the track isn't on is gone to first
    /// while stopped (as a tap on it does), and refused while playing.
    func clearSteps(track t: Int, entry e: Int) {
        let s = session
        guard let store = s.skiffSong, let list = store.song?.tracks[safe: t], list.entries.indices.contains(e), s.tracks.indices.contains(t) else {
            refuse("The FM-1's song hasn't been read yet. Try again in a moment."); return
        }
        guard let p = list.entries[e].poolIndex else {
            refuse("T\(t + 1) pad \(e + 1) holds no pattern, so there are no notes to clear.", track: t + 1, entry: e); return
        }
        let on = list.patternOn == p
        if !on, s.playing {
            refuse("T\(t + 1) isn't playing that pad. While playing, only the pattern a track is on can have its notes cleared: launch the pad first, or stop.",
                   track: t + 1, entry: e)
            return
        }
        Task {
            if !on {
                guard await store.send(.play(track: t, entry: e)) else { self.reportRefusal(store); return }
                await s.rereadSteps(track: t)
                guard store.song?.tracks[safe: t]?.patternOn == p else {
                    self.refuse("T\(t + 1) didn't go to pad \(e + 1), so its notes weren't cleared.", track: t + 1, entry: e); return
                }
            }
            // each step that holds something written empty. (Not SloopKit's clearAll and undo: on Skiff an emptied
            // step reads back with its extra bytes, which isn't `SynthStep.empty`, so that undo puts nothing back and
            // that clear writes all 64 steps.)
            let taken = s.tracks[t].steps
            for i in taken.indices where Self.holdsSomething(taken[i]) { s.write(track: t, index: i, .empty) }
            self.clearedPads.removeAll { $0.track == t && $0.entry == e && $0.steps != nil }
            self.clearedPads.append(ClearedPad(track: t, entry: e, before: list.entries, after: list.entries, steps: taken, stepsPattern: p, at: Date()))
            self.pokeAreas(["pads", "editor", "patternPictures"])
        }
    }

    private struct UndoWire: Decodable { let intent: String; let track: Int?; let entry: Int?; let steps: Int?; let from: Int?; let toTrack: Int?; let to: Int? }

    /// undoClear{track, entry} (or with neither: the last clear), setPatternSteps{steps}, padMove, clearSteps. True when `json` was one of them.
    func handleUndoClearJSON(_ json: String) -> Bool {
        let names = ["undoClear", "setPatternSteps", "padMove", "clearSteps"]
        guard names.contains(where: { json.contains("\"\($0)\"") }),
              let w = try? JSONDecoder().decode(UndoWire.self, from: Data(json.utf8)), names.contains(w.intent) else { return false }
        guard canWrite() else { refuseReadOnly(w.intent); return true }
        if w.intent == "setPatternSteps" { setPatternSteps(w.steps); return true }
        if w.intent == "padMove" {
            guard let t1 = w.track, let from = w.from, let to = w.to else { log("padMove: missing track, from or to"); return true }
            movePad(track: t1 - 1, from: from, toTrack: (w.toTrack ?? t1) - 1, to: to)
            return true
        }
        if w.intent == "clearSteps" {
            guard let t1 = w.track, let e = w.entry else { log("clearSteps: missing track or entry"); return true }
            clearSteps(track: t1 - 1, entry: e)
            return true
        }
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
        if let taken = c.steps {
            // the notes back, where the steps are still empty (a step filled in since stays as it is now)
            clearedPads.remove(at: k)
            guard store.song?.tracks[safe: t]?.patternOn == c.stepsPattern else {
                refuse("T\(t1) is on another pattern now, so its notes can't be put back.", track: t1, entry: e); return true
            }
            let cur = session.tracks[t].steps
            for i in taken.indices where i < cur.count && Self.holdsSomething(taken[i]) && !Self.holdsSomething(cur[i]) {
                session.write(track: t, index: i, taken[i])
            }
            pokeAreas(["pads", "editor", "patternPictures"])
            return true
        }
        let was = c.before[e]
        if let p = was.poolIndex, (store.pool?.patterns[safe: p]?.length ?? 0) == 0 {
            clearedPads.remove(at: k)
            refuse("Pattern \(was.label) is gone from the FM-1, so the pad can't come back.", track: t1, entry: e); return true
        }
        guard c.block || now[e].isEmpty else {
            clearedPads.remove(at: k)
            refuse("T\(t1) pad \(e + 1) holds something new, so the clear wasn't undone.", track: t1, entry: e); return true
        }
        // nothing else changed on the track since: the whole list as it was (a chain's link with it); else this pad alone
        var back = now
        if now == c.after { back = c.before } else if !c.block { back[e] = was; back[e].chained = false } else {
            clearedPads.remove(at: k)
            refuse("T\(t1) changed after the delete, so it can't be undone.", track: t1, entry: e); return true
        }
        clearedPads.remove(at: k)
        // the old keys back: all of them when the whole list goes back, else this pad's
        var keysBack = entryKeys(t)
        if back == c.before, c.keys.count == keysBack.count { keysBack = c.keys } else if c.keys.indices.contains(e) { keysBack[e] = c.keys[e] }
        hintKeys(track: t, to: back, keys: keysBack)
        pokeAreas(["pads"])
        Task {
            if !(await store.rewrite(track: t, to: back, focus: e, confirmed: true)) { self.reportRefusal(store) }
            self.pokeAreas(["pads", "timeline", "patterns", "editor"])
        }
        return true
    }

    /// An undo ended by the next edit (endUndosIfEdit): the record goes, and a pattern kept alive for it is cleared as
    /// the FM-1's CLEAR would have (POOL op 1), once stopped, if nothing uses it. Called from the core's half-second loop.
    func pollClearedPads() async {
        guard !clearedPads.isEmpty else { return }
        let now = Date()
        clearedPads.removeAll { !$0.undoable && $0.parked.isEmpty }
        guard let store = session.skiffSong, session.isConnected else { clearedPads.removeAll(); return }
        // not in the middle of the person's own changes: a second quiet first (the store takes one change at a time)
        guard !session.playing, !store.busy, now.timeIntervalSince(store.lastChange) > 1, let pool = store.pool?.patterns, pool.count == 64,
              let k = clearedPads.firstIndex(where: { !$0.undoable }), let n = clearedPads[k].parked.first else { return }
        clearedPads[k].parked.removeFirst()                      // one pattern a look
        if clearedPads[k].parked.isEmpty { clearedPads.remove(at: k) }
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
