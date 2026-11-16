// Managing patterns (board 79, design/boards/phone-patterns.html; Scott, 2026-11-15, after the full pool on LUPE TEST).
//
// `patterns`: every kept pattern number with its length, how many things use it, where this music uses it, and
// whether saved projects hold it too. All of it from POOL and LIST, which the song store already reads, so it is
// live and costs no new traffic, playing too.
//
// `patternPictures`: each kept pattern's notes, small. A pattern a track is on is drawn from that track's steps
// (live, playing too). The others come from the FM-1's stored records (backup objects 16…31, SkiffPoolRead), which
// the FM-1 gives only while stopped, and whose first read on a connection sends BACKUP_LIST (it stops the transport
// and writes the waiting patterns to flash). So they are read only while the Patterns sheet is open
// (`patternsOpen`), only stopped, three quiet seconds after a stop or a change (as the iPad's pads do), cached, and
// read again only for the chunks whose POOL entries changed.
//
// The intents (each behind the read-only gate, each answered in the `notice` area): clearPatterns, recyclePattern,
// copyPattern. Mirrored by android/app/.../core (P2's).
import Foundation
import SloopKit

public struct PatternsArea: Codable, Equatable, Sendable {
    public struct Use: Codable, Equatable, Sendable {
        public var track: Int            // 1…6
        public var entry: Int            // 0…15
    }
    public struct Item: Codable, Equatable, Sendable {
        public var number: Int           // 1…64
        public var len: Int              // steps, 1…64
        /// The FM-1's own count (POOL), at most 127: entries in the tracks' lists and in the saved projects, and a
        /// track on it that no entry names.
        public var uses: Int
        /// The entries of this music that name it.
        public var here: [Use]
        /// The tracks on it now (1…6).
        public var on: [Int]
        /// Saved projects hold it too: the FM-1 counts more uses than this music shows. That includes the saved
        /// copy of the music that is loaded.
        public var saved: Bool
        /// Nothing uses it: Clear and Recycle may take it.
        public var unused: Bool
    }
    /// Pattern numbers free, kept and unused (kept, nothing uses them): free + kept = 64.
    public var free: Int
    public var kept: Int
    public var unused: Int
    /// The kept patterns, by number.
    public var patterns: [Item]
    /// The number Recycle would take (the lowest unused), if there is one.
    public var recycle: Int?
    /// Playing, and some kept pattern has no current picture: the stored notes load on a stop.
    public var picturesWaitForStop: Bool
    /// Stopped with the sheet open, and some kept pattern's picture is still being read from the FM-1.
    public var picturesLoading: Bool
}

public struct PatternPicturesArea: Codable, Equatable, Sendable {
    public struct Picture: Codable, Equatable, Sendable {
        public var number: Int           // 1…64
        public var len: Int
        /// A kit's pattern: draw `hits`. Otherwise draw `notes`.
        public var drums: Bool
        /// Per step (`len` of them): the highest note that starts there (MIDI 0…127), or -1 for none.
        public var notes: [Int]
        /// Per step: how many drum lanes hit there.
        public var hits: [Int]
        /// Drawn from the track playing it (current), not from the FM-1's stored copy.
        public var live: Bool
    }
    public var pictures: [Picture]
}

extension PhoneCore {
    /// nil until the FM-1's pool and lists are read.
    public func patternsArea() -> PatternsArea? {
        guard let store = session.skiffSong, let pool = store.pool?.patterns, pool.count == 64, let song = store.song else { return nil }
        var items: [PatternsArea.Item] = []
        let live = livePatterns()
        var missing = false
        for p in 0..<64 where pool[p].length > 0 {
            var here: [PatternsArea.Use] = [], on: [Int] = [], unnamed = 0
            for (t, l) in song.tracks.enumerated() {
                for (e, x) in l.entries.enumerated() where x.poolIndex == p { here.append(.init(track: t + 1, entry: e)) }
                if l.patternOn == p {
                    on.append(t + 1)
                    // (bank.c pool_refs) a track on it whose own entry doesn't name it counts as a use
                    if l.entryOn.map({ l.entries[safe: $0]?.poolIndex != p }) ?? true { unnamed += 1 }
                }
            }
            let uses = pool[p].uses
            items.append(.init(number: p + 1, len: pool[p].length, uses: uses, here: here, on: on,
                               saved: uses > here.count + unnamed, unused: uses == 0))
            if live[p] == nil, patternSeen[safe: p] != Self.poolSig(pool[p]) { missing = true }
        }
        let unused = items.filter(\.unused)
        return PatternsArea(free: pool.filter(\.isFree).count, kept: items.count, unused: unused.count, patterns: items,
                            recycle: unused.first?.number, picturesWaitForStop: session.playing && missing,
                            picturesLoading: !session.playing && patternsOpen && missing)
    }

    /// nil until the pool is read. The pictures there are: a track's own for the pattern it is on, the stored ones read
    /// since the sheet opened.
    public func patternPicturesArea() -> PatternPicturesArea? {
        guard let pool = session.skiffSong?.pool?.patterns, pool.count == 64 else { return nil }
        let live = livePatterns()
        let pictures = (0..<64).compactMap { p -> PatternPicturesArea.Picture? in
            guard pool[p].length > 0 else { return nil }
            return live[p] ?? patternStored[p]
        }
        return PatternPicturesArea(pictures: pictures)
    }

    static func poolSig(_ p: PatternPool.Pattern) -> String { "\(p.length).\(p.uses)" }

    /// The pattern each track is on, drawn from the track's steps as they are now.
    func livePatterns() -> [Int: PatternPicturesArea.Picture] {
        var out: [Int: PatternPicturesArea.Picture] = [:]
        let s = session
        for k in s.trackIndices {
            guard let p = s.skiffSong?.song?.tracks[safe: k]?.patternOn, k < s.tracks.count, out[p] == nil else { continue }
            let t = s.tracks[k], n = max(1, min(64, t.length)), kit = s.isKit(k)
            let grid = t.gridSteps
            let notes = (0..<n).map { i in !kit && i < t.steps.count && t.isOn(i) ? (t.steps[i].notes.max() ?? -1) : -1 }
            let hits = (0..<n).map { i in kit && i < grid.count ? (0..<8).filter { grid[i].has($0) }.count : 0 }
            out[p] = .init(number: p + 1, len: n, drums: kit, notes: notes, hits: hits, live: true)
        }
        return out
    }

    static func picture(_ p: Int, _ s: SkiffPatternSketch) -> PatternPicturesArea.Picture {
        let n = max(1, min(64, s.length))
        return .init(number: p + 1, len: n, drums: s.drums,
                     notes: (0..<n).map { s.steps[$0].note ? (s.steps[$0].notes.max() ?? -1) : -1 },
                     hits: (0..<n).map { s.steps[$0].note ? s.steps[$0].hits : 0 }, live: false)
    }

    /// One look at the stored patterns, if the sheet is open and the FM-1 is stopped and quiet: the chunks whose POOL
    /// entries changed since they were read. Never while playing (the GET is refused, and its LIST would stop it).
    func pollPatternPictures() async {
        let s = session
        guard patternsOpen, !patternsReading, s.isConnected, s.dialect == .skiff, !s.playing,
              let store = s.skiffSong, !store.offline, !store.busy, let pool = store.pool?.patterns, pool.count == 64 else { return }
        guard Date().timeIntervalSince(max(s.stoppedAt, store.lastChange)) >= Self.picturesQuiet else { return }
        let sig = pool.map(Self.poolSig)
        if patternSeen.count != 64 { patternSeen = Array(repeating: "", count: 64) }
        let chunks = (0..<16).filter { c in (0..<4).contains { sig[4 * c + $0] != patternSeen[4 * c + $0] } }
        guard !chunks.isEmpty else { return }
        patternsReading = true
        defer { patternsReading = false }
        guard let recs = await s.readSkiffPool(chunks: chunks) else { return }     // playing again, or busy: next time
        for c in chunks {
            for k in 0..<4 {
                let p = 4 * c + k
                patternStored[p] = recs[p].flatMap { SkiffPatternSketch(record: $0) }.map { Self.picture(p, $0) }
                patternSeen[p] = sig[p]
            }
        }
        pokeAreas(["patterns", "patternPictures"])
    }

    private struct PatternsWire: Decodable {
        let intent: String
        let open: Bool?, numbers: [Int]?, confirmed: Bool?, track: Int?, entry: Int?, number: Int?
    }

    private static func list(_ ns: [Int]) -> String {
        let s = ns.map { String(format: "%02d", $0) }
        return s.count < 2 ? s.joined() : s.dropLast().joined(separator: ", ") + " and " + s[s.count - 1]
    }

    /// patternsOpen, clearPatterns, recyclePattern, copyPattern. True when `json` was one of them.
    func handlePatternsJSON(_ json: String) -> Bool {
        let names = ["patternsOpen", "clearPatterns", "recyclePattern", "copyPattern"]
        guard names.contains(where: { json.contains("\"\($0)\"") }),
              let w = try? JSONDecoder().decode(PatternsWire.self, from: Data(json.utf8)), names.contains(w.intent) else { return false }
        if w.intent == "patternsOpen" {
            // not a write: it only lets the stored pictures be read while the sheet shows
            patternsOpen = w.open ?? true
            pokeAreas(["patterns"])
            return true
        }
        guard canWrite() else { refuseReadOnly(w.intent); return true }
        guard let store = session.skiffSong, let pool = store.pool?.patterns, pool.count == 64, let song = store.song else {
            refuse("The FM-1's patterns haven't been read yet. Try again in a moment."); return true
        }
        func unused(_ n: Int) -> Bool { (1...64).contains(n) && pool[n - 1].length > 0 && pool[n - 1].uses == 0 }
        func free() -> Int { store.pool?.free ?? 0 }

        switch w.intent {
        case "clearPatterns":
            // POOL op 1 for each: only a pattern nothing uses, only stopped, and it can't be undone
            var asked: [Int] = []
            for n in w.numbers ?? [] where (1...64).contains(n) && !asked.contains(n) { asked.append(n) }
            asked.sort()
            guard !asked.isEmpty else { log("clearPatterns: no numbers"); return true }
            let take = asked.filter(unused), used = asked.filter { !unused($0) }
            guard !take.isEmpty else {
                refuse(used.count == 1 ? "Pattern \(Self.list(used)) is in use or empty, so it can't be cleared. Only a pattern nothing uses can."
                                       : "Patterns \(Self.list(used)) are in use or empty, so they can't be cleared. Only patterns nothing uses can.")
                return true
            }
            guard !session.playing else { refuse("Stop playback to clear patterns. The FM-1 only clears them while stopped."); return true }
            guard w.confirmed == true else { log("clearPatterns erases \(Self.list(take)) for good: the screen must confirm"); return true }
            Task {
                var done: [Int] = [], failed: [(Int, SongRC)] = []
                for n in take {
                    let rc = await store.poolOp(1, pattern: n - 1)
                    if rc.isDone { done.append(n) } else { failed.append((n, rc)) }
                    if rc == .playing { break }
                }
                var text = done.isEmpty ? "" : "Cleared \(done.count == 1 ? "pattern" : "patterns") \(Self.list(done)). \(free()) pattern numbers are free."
                if !failed.isEmpty {
                    let why = failed.contains { $0.1 == .playing } ? "the FM-1 is playing: stop and try again"
                            : failed.contains { $0.1 == .inUse } ? "something uses them now" : "the FM-1 refused"
                    text += (text.isEmpty ? "" : " ") + "Not cleared: \(Self.list(take.filter { !done.contains($0) })) (\(why))."
                }
                if !used.isEmpty { text += " Left alone because they are in use or empty: \(Self.list(used))." }
                self.log("clearPatterns: \(text)")
                // all asked for went: a confirmation; anything not cleared makes it a refusal (it says what to do)
                self.publishNotice(NoticeArea(text: text, kind: failed.isEmpty && !done.isEmpty ? .confirmation : .refusal))
                self.pokeAreas(["patterns", "patternPictures", "pads", "timeline"])
            }
        case "recyclePattern":
            // the lowest unused number onto the entry (LIST SET), then emptied (POOL op 2): a fresh pattern with no
            // free number. Its old steps are gone for good; EMPTY is stopped only
            guard let t1 = w.track, let e = w.entry, song.tracks.indices.contains(t1 - 1), (0..<16).contains(e) else {
                log("recyclePattern: missing track or entry"); return true
            }
            guard let n = (1...64).first(where: unused) else {
                refuse("No pattern is unused, so there is none to recycle. Free one first: delete a pad that uses a pattern, or reuse a kept pattern.", track: t1, entry: e)
                return true
            }
            guard !session.playing else {
                refuse("Stop playback to recycle a pattern. The FM-1 only empties one while stopped.", track: t1, entry: e); return true
            }
            Task {
                guard await store.send(.set(track: t1 - 1, entry: e, pattern: n)) else { self.reportRefusal(store); return }
                let rc = await store.poolOp(2, pattern: n - 1)
                if rc.isDone {
                    self.publishNotice(NoticeArea(text: "Pattern \(Self.list([n])) was emptied and put on T\(t1) pad \(e + 1).", track: t1, entry: e, kind: .confirmation))
                    self.log("recyclePattern: \(n) emptied onto T\(t1) entry \(e)")
                } else {
                    self.refuse("Pattern \(Self.list([n])) is on T\(t1) pad \(e + 1), but the FM-1 didn't empty it"
                                + (rc == .playing ? " because it is playing. Stop, then empty it." : ". It still holds its old steps."), track: t1, entry: e)
                }
                self.pokeAreas(["patterns", "patternPictures", "pads", "timeline", "editor"])
            }
        default:    // copyPattern: an empty entry pointed at it (LIST SET), then that entry's pattern copied (LIST COPY)
            guard let n = w.number, let t1 = w.track, let e = w.entry, song.tracks.indices.contains(t1 - 1), (0..<16).contains(e) else {
                log("copyPattern: missing number, track or entry"); return true
            }
            guard (1...64).contains(n), pool[n - 1].length > 0 else {
                refuse("Pattern \(n) holds nothing on the FM-1, so there is nothing to copy.", track: t1, entry: e); return true
            }
            guard free() > 0 else {
                refuse("All 64 patterns are taken, so a copy has no number to go to. Clear unused patterns, or recycle one.", track: t1, entry: e); return true
            }
            guard song.tracks[t1 - 1].entries[e].isEmpty else {
                refuse("T\(t1) pad \(e + 1) isn't empty. A copy goes onto an empty pad.", track: t1, entry: e); return true
            }
            Task {
                guard await store.send(.set(track: t1 - 1, entry: e, pattern: n)) else { self.reportRefusal(store); return }
                guard await store.send(.copy(track: t1 - 1, entry: e)) else { self.reportRefusal(store); return }
                let made = store.song?.tracks[safe: t1 - 1]?.entries[safe: e]?.poolIndex.map { $0 + 1 }
                self.publishNotice(NoticeArea(text: "Pattern \(Self.list([n])) was copied to \(made.map { Self.list([$0]) } ?? "a new number") on T\(t1) pad \(e + 1).",
                                              track: t1, entry: e, kind: .confirmation))
                self.pokeAreas(["patterns", "patternPictures", "pads", "timeline"])
            }
        }
        return true
    }
}
