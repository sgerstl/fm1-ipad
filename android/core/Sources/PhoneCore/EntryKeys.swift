// A stable key for every pad and Timeline block (P2's row animations, 2026-11-15): `pads.rows[].entries[].key` and
// `timeline.tracks[].blocks[].key`. The FM-1 names an entry only by its place, and a rewrite moves places, so the
// core keeps the keys itself, per track, for as long as it runs:
// - its own rewrites say where each key goes (a move or swap: the key travels; a block deleted: the others keep
//   theirs; an undo: the old keys back; a copy or a new pattern: a new key);
// - any other change to a list (the FM-1's own, a project loading) is matched by content: the same pattern in the
//   same place keeps its key, a pattern that moved takes its key along, a pad changed in place keeps its key, and
//   anything else is new.
// An empty entry's key is 0. Keys are never reused within a run.
import Foundation
import SloopKit

extension PhoneCore {
    /// Track `t`'s sixteen keys, brought up to date with its list as it is now.
    func entryKeys(_ t: Int) -> [Int] {
        guard let list = session.skiffSong?.song?.tracks[safe: t] else { return Array(repeating: 0, count: 16) }
        let pats = list.entries.map(\.pattern)
        if let seen = keySeen[t], seen == pats, let k = keys[t] { return k }
        var new = Array(repeating: 0, count: pats.count)
        if let h = keyHints[t], h.patterns == pats {
            new = h.keys                                   // the core's own rewrite: it said where each goes
            keyHints[t] = nil
        } else if let old = keys[t], let oldPats = keySeen[t], old.count == pats.count {
            var used = Set<Int>()
            // the same thing in the same place
            for i in pats.indices where pats[i] != 0 && oldPats[i] == pats[i] && old[i] != 0 { new[i] = old[i]; used.insert(i) }
            // the same pattern from another place: the nearest one not taken
            for i in pats.indices where pats[i] != 0 && new[i] == 0 {
                let from = pats.indices.filter { !used.contains($0) && old[$0] != 0 && oldPats[$0] == pats[i] }
                    .min { abs($0 - i) < abs($1 - i) }
                if let j = from { new[i] = old[j]; used.insert(j) }
            }
            // changed in place (another pattern put on the pad)
            for i in pats.indices where pats[i] != 0 && new[i] == 0 && old[i] != 0 && !used.contains(i) { new[i] = old[i]; used.insert(i) }
        }
        for i in pats.indices {
            if pats[i] == 0 { new[i] = 0 } else if new[i] == 0 { nextKey += 1; new[i] = nextKey }
        }
        keys[t] = new; keySeen[t] = pats
        return new
    }

    /// The core is about to rewrite track `t` to `entries`: `keys` is where each key goes (0: a new one, or empty).
    func hintKeys(track t: Int, to entries: [SongEntry], keys k: [Int]) {
        keyHints[t] = (entries.map(\.pattern), k)
    }
}
