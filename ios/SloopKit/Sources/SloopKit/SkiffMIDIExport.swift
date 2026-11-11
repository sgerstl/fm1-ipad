import Foundation

// A Skiff project as a MIDI file for a DAW (vault export-plan.md, export 3). Made from the project Lupe keeps (the SKF4
// record and the patterns its entries name), so it needs no FM-1 and takes no time to play: the song is worked out the
// way Skiff's sequencer plays it, from the firmware's source (Skiff-Lupe 2.5.1):
//   - the song as SONG ONCE plays it (bank.c song_poll): each track its list once, from its first entry to its last, an
//     entry's REPS its passes, a CHAIN's entries as one pattern repeated by its last entry's REPS, a REST (or an empty
//     entry inside the list) silent for the pattern before it (bank.c ent_len48); the song ends with the longest list.
//   - a step (seq.c seq_step): its length the DIV's (voice.c DIV_48), swung (core.h swing_step_len: even steps longer by
//     SWING × step / 250, own + global, at most 100), NUDGE 64ths of it later; a note as long as GATE / 128 of the step,
//     held on into a TIE (or a slide) after it; velocity 127 on an accent, 96 for 0; drum hits on the lanes' GM notes
//     (eng_drum.c DRUM_LANE_NOTE); RATCH in equal parts, each its GATE; FLAM a grace hit at 9/16 of the velocity, the
//     full one 15 ms (at most half the step) later; per-note ties carry a sounding note on; A:B trig conditions on pass
//     A of every B (seq.c step_cond_ok, passes counted from PLAY).
// Track k is MIDI channel k + 1, as Skiff's MIDI IN (CH1-6) and NOTES OUT number them, so the file plays back into an
// FM-1 on the right tracks.

public enum SkiffMIDIExport {
    /// Ticks a quarter note: every DIV, swing amount and RATCH part of a 1/16 lands within a tick.
    public static let ppq = 960
    /// eng_drum.c DRUM_LANE_NOTE: KICK SNARE CLAP HAT CL HAT OP TOM RIM BELL.
    public static let laneNotes = [36, 38, 39, 42, 46, 45, 37, 56]

    public enum Chance: Equatable, Sendable {
        /// Every step that can play plays (a chance of 0 never does).
        case everyStep
        /// Rolled once each time a step comes round, as the FM-1 does; the same seed gives the same file.
        case seeded(UInt64)
    }

    public struct Options: Equatable, Sendable {
        public var chance: Chance
        /// FILL held all song: FILL steps play and !FILL ones don't.
        public var fill: Bool
        public init(chance: Chance = .everyStep, fill: Bool = false) { self.chance = chance; self.fill = fill }
    }

    /// What the file holds and what it couldn't, in words for the export's summary.
    public struct Report: Equatable, Sendable {
        public var tempo: Int
        public var notes: Int
        /// The song's length in ticks, and in seconds at its tempo.
        public var ticks: Int
        public var seconds: Double { Double(ticks) / Double(SkiffMIDIExport.ppq) * 60 / Double(tempo) }
        /// The tracks with something in their list.
        public var tracks: [Int]
        public var leftOut: [String]
    }

    public enum ExportError: Error, Equatable, CustomStringConvertible {
        case notAProject
        case emptySong
        public var description: String {
            switch self {
            case .notAProject: "This isn't a Skiff 2 project."
            case .emptySong: "No track has anything in its list, so there's nothing to export."
            }
        }
    }

    /// The project as a MIDI file: a tempo track, then one track per FM-1 track with a list.
    public static func midiFile(_ project: SkiffProjectData, name: String, options: Options = Options()) throws -> (file: MIDIFile, report: Report) {
        guard let rec = project.project else { throw ExportError.notAProject }
        let patterns = Dictionary(project.patterns.compactMap { p in SkiffPattern(record: Array(p.data)).map { (p.id, $0) } },
                                  uniquingKeysWith: { a, _ in a })
        let tempo = rec.tempo ?? 120
        var rng = SplitMix(seed: { if case .seeded(let s) = options.chance { return s }; return 0 }())
        var tracks: [MIDIFile.Track] = [], used: [Int] = [], end = 0, notes = 0
        var notes100 = 0, fillSkipped = 0, random: [Int] = [], motion = Set<Int>()
        for k in 0..<SKF4.tracks {
            var r = TrackRender(channel: k, globalSwing: rec.globalSwing, tempo: tempo, options: options)
            r.render(entries: rec.entries(track: k), patterns: patterns, rng: &rng)
            guard r.listed else { continue }
            used.append(k)
            end = max(end, r.tick)
            notes += r.events.count
            notes100 += r.chancy; fillSkipped += r.fillSkipped
            if r.random { random.append(k) }
            motion.formUnion(r.motion)
            let engine = SkiffEngines.name(rec.engine(track: k))
            tracks.append(MIDIFile.Track(name: "T\(k + 1)" + (engine.map { " \($0)" } ?? ""), events: r.events))
        }
        guard !used.isEmpty else { throw ExportError.emptySong }

        var leftOut: [String] = []
        if rec.songMode != .once {
            leftOut.append("Each track plays its list once, as SONG ONCE does\(rec.songMode == .on ? " (the FM-1 loops each list with SONG on)" : "").")
        }
        if notes100 > 0 {
            leftOut.append(options.chance == .everyStep
                ? "\(notes100) \(notes100 == 1 ? "step has" : "steps have") a chance under 100%; every one plays in the file."
                : "\(notes100) \(notes100 == 1 ? "step has" : "steps have") a chance under 100%; rolled once for the file.")
        }
        if fillSkipped > 0 {
            leftOut.append("\(fillSkipped) FILL \(fillSkipped == 1 ? "step is" : "steps are") left out\(options.fill ? "" : " (FILL wasn't held)"); !FILL steps play.")
        }
        for k in random { leftOut.append("T\(k + 1) plays in random order on the FM-1; the file has its steps in order.") }
        if !motion.isEmpty {
            leftOut.append("Knob motion on \(motion.count == 1 ? "pattern" : "patterns") \(motion.sorted().map { String(format: "%02d", $0 + 1) }.joined(separator: ", ")) isn't in the file yet.")
        }
        let file = MIDIFile(ppq: ppq, tempo: Double(tempo), name: name, tracks: tracks, end: end)
        return (file, Report(tempo: tempo, notes: notes, ticks: end, tracks: used, leftOut: leftOut))
    }

    /// The file's bytes and its summary.
    public static func data(_ project: SkiffProjectData, name: String, options: Options = Options()) throws -> (data: Data, report: Report) {
        let (f, r) = try midiFile(project, name: name, options: options)
        return (f.data, r)
    }

    /// "Night Drive.mid": the project's name as a file name ("/" and ":" can't be in one), "Lupe song" when it has none.
    public static func fileName(_ name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return (n.isEmpty ? "Lupe song" : n) + ".mid"
    }
}

/// One track's list played through once.
struct TrackRender {
    let channel: Int
    let globalSwing: Int
    let tempo: Int
    let options: SkiffMIDIExport.Options

    var events: [MIDIFile.Event] = []
    var tick = 0
    /// Passes since PLAY (take.c take_pass: the first counts 1), for the trig conditions.
    var pass = 0
    var listed = false
    var chancy = 0, fillSkipped = 0
    var random = false
    var motion = Set<Int>()
    /// Notes held on past their GATE: into a TIE, a slide, or a note the next step ties.
    var open: [(note: Int, start: Int, velocity: Int)] = []

    init(channel: Int, globalSwing: Int, tempo: Int = 120, options: SkiffMIDIExport.Options) {
        self.channel = channel; self.globalSwing = globalSwing; self.tempo = tempo; self.options = options
    }

    mutating func render(entries: [SongEntry], patterns: [Int: SkiffPattern], rng: inout SplitMix) {
        guard let first = entries.firstIndex(where: { !$0.isEmpty }), let last = entries.lastIndex(where: { !$0.isEmpty }) else { return }
        listed = true
        var e = first
        while e <= last {
            // a chain: entries on CHAIN with the one they end on (an empty entry ends it)
            var j = e
            while j < last, entries[j].chained, !entries[j].isEmpty, !entries[j + 1].isEmpty { j += 1 }
            for rep in 0..<max(1, entries[j].reps) {
                for part in e...j {
                    if let id = entries[part].poolIndex, let p = patterns[id] {
                        if p.motionCount > 0 { motion.insert(id) }
                        play(p, fresh: e < j || rep == 0, rng: &rng)
                    } else {
                        close(at: tick)
                        tick += Self.restTicks(entries, at: part, patterns: patterns)
                        pass += 1
                    }
                }
            }
            e = j + 1
        }
        close(at: tick)
    }

    /// bank.c ent_len48: a REST (or an empty entry inside the list) lasts the pattern before it, looking back round from
    /// the list's end for one first; a list of rests only, a bar.
    static func restTicks(_ entries: [SongEntry], at e: Int, patterns: [Int: SkiffPattern]) -> Int {
        let n = entries.count
        for back in 0..<n {
            let j = (e - back + n) % n
            if let id = entries[j].poolIndex, let p = patterns[id] { return p.length * stepTicks(p.division) }
        }
        return 4 * SkiffMIDIExport.ppq
    }

    static func stepTicks(_ division: Int) -> Int {
        Int(CountedPlayhead.divisionTicks[max(0, min(9, division))]) * SkiffMIDIExport.ppq / 24
    }

    // where a pass of a pattern is: the step playing and, in PING, which way
    var pos = 0, down = false

    mutating func play(_ p: SkiffPattern, fresh: Bool, rng: inout SplitMix) {
        let L = p.length
        if p.direction == .random { random = true }
        if fresh { pos = p.direction == .reverse ? L - 1 : 0; down = false }
        pos = min(pos, L - 1)
        let base = Self.stepTicks(p.division)
        let swing = max(0, min(100, p.swing + globalSwing))
        let sw = swing * base / 250
        pass += 1
        for _ in 0..<L {
            let i = pos
            let len = i & 1 == 1 ? base - sw : base + sw
            let nx = after(p.direction, i, L)
            step(p.steps[i], at: tick, length: len, gate: p.gate, next: p.steps[nx.pos], rng: &rng)
            tick += len
            (pos, down) = (nx.pos, nx.down)
        }
    }

    /// seq.c seq_after (RAND plays forward here).
    func after(_ d: SkiffPattern.Direction, _ i: Int, _ L: Int) -> (pos: Int, down: Bool) {
        switch d {
        case .reverse: return (i > 0 ? i - 1 : L - 1, false)
        case .pingPong:
            guard L >= 2 else { return (0, false) }
            let n = down ? (i > 0 ? i - 1 : 1) : (i + 1 < L ? i + 1 : L - 2)
            return (n, n < i)                       // (seq.c: seq_down = the next below the playing one)
        case .forward, .random: return ((i + 1) % L, false)
        }
    }

    /// seq.c step_cond_ok.
    func conditionPasses(_ c: Int) -> Bool {
        let A = [0, 0, 0, 1, 2, 1, 2, 3, 1, 2, 3, 4], B = [1, 1, 1, 2, 2, 3, 3, 3, 4, 4, 4, 4]
        guard c > 0, c < 12 else { return true }
        if c == 1 || c == 2 { return (c == 1) == options.fill }
        return pass > 0 && (pass - 1) % B[c] + 1 == A[c]
    }

    mutating func emit(_ note: Int, _ start: Int, _ end: Int, _ velocity: Int) {
        let s = max(0, start)
        events.append(MIDIFile.Event(tick: s, channel: channel, kind: .note(note: note, velocity: velocity, length: max(1, end - s))))
    }

    /// What was held on ends at `t`.
    mutating func close(at t: Int) {
        for v in open { emit(v.note, v.start, t, v.velocity) }
        open = []
    }

    mutating func step(_ s: SkiffPattern.Step, at t: Int, length len: Int, gate: Int, next: SkiffPattern.Step, rng: inout SplitMix) {
        let gateEnd = t + len * gate / 128
        // its trig condition, then its chance: a step that doesn't play ends what rang before
        if s.condition != 0 && !conditionPasses(s.condition) {
            if s.condition <= 2 && s.sounds { fillSkipped += 1 }
            close(at: t); return
        }
        if s.chance == 0 { close(at: t); return }
        if s.chance < 100 && s.sounds {
            chancy += 1
            if case .seeded = options.chance, Int(rng.next() % 100) >= s.chance { close(at: t); return }
        }
        // held into the next step: a slide, a TIE after it, or (per note) a tie of the next step's
        let holdAll = s.slide || next.time == .tie
        func heldOn(_ note: Int) -> Bool {
            holdAll || (next.time == .note && next.hits == 0 && next.notes.indices.contains { next.ties >> $0 & 1 == 1 && next.notes[$0] == note })
        }
        switch s.time {
        case .tie:
            guard !open.isEmpty else { return }
            if !holdAll {
                let held = open.filter { heldOn($0.note) }
                for v in open where !heldOn(v.note) { emit(v.note, v.start, gateEnd, v.velocity) }
                open = held
            }
            return
        case .rest:
            close(at: t); return
        case .note:
            guard s.sounds else { close(at: t); return }
        }
        let start = t + s.nudge * len / 64
        let velocity = s.accent ? 127 : (s.velocity == 0 ? 96 : s.velocity)
        var play: [(note: Int, velocity: Int, tied: Bool)] = s.notes.indices.map { (s.notes[$0], velocity, s.ties >> $0 & 1 == 1) }
        for l in 0..<8 where s.hits >> l & 1 == 1 {
            play.append((SkiffMIDIExport.laneNotes[l], s.hitAccents >> l & 1 == 1 ? 127 : velocity, false))
        }
        // what rang before: a note this step ties goes on, the rest ends as this step starts
        var carried: [(note: Int, start: Int, velocity: Int)] = []
        for v in open {
            if play.contains(where: { $0.tied && $0.note == v.note }) { carried.append(v) } else { emit(v.note, v.start, start, v.velocity) }
        }
        open = []
        for v in carried {
            if heldOn(v.note) { open.append(v) } else { emit(v.note, v.start, gateEnd, v.velocity) }
        }
        let fresh = play.filter { n in !n.tied }            // (a tie never starts a note)
        if s.ratchet > 1 {
            let part = len / s.ratchet, pg = part * gate / 128
            for q in 0..<s.ratchet { for n in fresh { emit(n.note, start + q * part, start + q * part + pg, n.velocity) } }
        } else if s.flam {
            let at = flamTicks(len)
            for n in fresh {
                emit(n.note, start, start + at, n.velocity * 9 / 16 + 1)
                if heldOn(n.note) { open.append((n.note, start + at, n.velocity)) } else { emit(n.note, start + at, max(gateEnd, start + at + 1), n.velocity) }
            }
        } else {
            for n in fresh {
                if heldOn(n.note) { open.append((n.note, start, n.velocity)) } else { emit(n.note, start, gateEnd, n.velocity) }
            }
        }
    }

    /// seq.c flam_at: FLAM_SAMPLES (15 ms) at the song's tempo, in ticks, at most half the step.
    func flamTicks(_ len: Int) -> Int { max(1, min(len / 2, SkiffMIDIExport.ppq * tempo * 15 / 60_000)) }
}

/// A small seeded generator (SplitMix64), so a rolled export is the same each time.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
