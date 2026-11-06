import Foundation

/// What each track of Skiff's song is doing and will do next, for the Song tab's marks (Skiff's README, "SONG ON",
/// "SONG ONCE", "Playing an entry"; EDITOR_PROTOCOL.md LIST, PERFORM). Skiff doesn't report how many of an entry's
/// REPS have played, so the pass is counted here: from the clock (CountedPlayhead's passes) since the track came
/// onto its entry (`arrival`).
public enum SongPlayback {
    /// LAUNCH (PERFORM op 5): where a launch while playing lands.
    public enum Launch: Int, Sendable, CaseIterable { case loop = 0, bar = 1, beat = 2, now = 3 }

    public struct Marks: Equatable, Sendable {
        /// The block playing (its first entry), and which pass of its REPS this is (1-based), when known.
        public var playing: Int?
        public var pass: Int?
        public var reps = 1
        /// SONG OFF: the block loops.
        public var loops = false
        /// SONG ON and ONCE: the block the track moves to when these REPS end; `wraps` when that's the first again.
        public var next: Int?
        public var wraps = false
        /// SONG ONCE on the last block: the track goes quiet after it.
        public var ends = false
        /// A launch waiting (LIST's staged entry): its block, and the ticks until it lands, when known.
        public var queued: Int?
        public var launchIn: Double?
        public init() {}
    }

    /// The marks of one track. `blocks` are the track's blocks in order (rests and gaps count: Skiff plays them);
    /// `passCount` the passes it has begun since Start, `arrivalPass` the pass it came onto its entry on.
    public static func marks(mode: SongMode, list: SongList, blocks: [SongBlock], passCount: Int?, arrivalPass: Int?,
                             launchIn: Double?) -> Marks {
        var m = Marks()
        if let e = list.entryOn, let k = blocks.firstIndex(where: { $0.entries.contains(e) }) {
            let b = blocks[k]
            m.playing = b.id
            m.reps = max(1, b.reps)
            if let p = passCount, let a = arrivalPass, p >= a { m.pass = (p - a) % m.reps + 1 }
            switch mode {
            case .off: m.loops = true
            case .on, .once:
                if k + 1 < blocks.count { m.next = blocks[k + 1].id }
                else if mode == .on, let f = blocks.first, f.id != b.id { m.next = f.id; m.wraps = true }
                else if mode == .on { m.loops = true }                 // a single block: it plays again
                else { m.ends = true }
            }
        }
        // LIST's staged entry is also the song's own next (SONG ON and ONCE stage it as the REPS run out): a launch
        // only when it's another block than that
        if let s = list.staged, let q = blocks.first(where: { $0.entries.contains(s) }), q.id != m.next {
            m.queued = q.id
            m.launchIn = launchIn
        }
        return m
    }

    /// Ticks until a launch lands: the track's pass end (LOOP; `passProgress` 0…1 of `passTicks`), the next bar, the next
    /// beat, or now. nil when the clock isn't known.
    public static func ticksToLaunch(_ launch: Launch, ticks: Int, passProgress: Double?, passTicks: Double) -> Double? {
        guard ticks >= 0 else { return nil }
        switch launch {
        case .loop: return passProgress.map { (1 - $0) * passTicks }
        case .bar: return Double(96 - ticks % 96)
        case .beat: return Double(24 - ticks % 24)
        case .now: return 0
        }
    }
}
