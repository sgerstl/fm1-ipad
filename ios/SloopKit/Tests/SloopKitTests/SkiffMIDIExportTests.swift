import Foundation
import Testing
@testable import SloopKit

/// The MIDI export, from records built the way Skiff writes them (bank.c bk_pack_raw, project.c step_put9), played the
/// way its sequencer plays them (seq.c, bank.c song_poll): see SkiffMIDIExport.swift for the rules and their sources.
@Suite struct SkiffMIDIExportTests {
    // MARK: building records as Skiff writes them

    /// project.c step_put9.
    static func put9(_ s: SkiffPattern.Step) -> [UInt8] {
        let r = s.ratchet - 1
        var b = [UInt8](repeating: 0, count: 9)
        for j in 0..<4 { b[j] = UInt8((j < s.notes.count ? s.notes[j] : 0) | ((s.condition >> j) & 1) << 7) }
        let flags = (s.accent ? 1 : 0) | (s.slide ? 2 : 0)
        b[4] = UInt8(s.notes.count | s.time.rawValue << 3 | flags << 5 | (s.flam ? 128 : 0))
        b[5] = UInt8(s.velocity | (r & 1) << 7)
        b[6] = UInt8(s.hits)
        b[7] = UInt8(s.hits != 0 ? s.hitAccents & s.hits : s.ties)
        let prob = s.chance >= 100 ? 0 : s.chance == 0 ? 101 : s.chance
        b[8] = UInt8(prob | (r >> 1) << 7)
        return b
    }

    /// bank.c bk_pack_raw: version, LEN DIV SWING GATE DIR + 64, the steps, the NUDGE plane.
    static func record(length: Int = 16, division: Int = 2, swing: Int = 0, gate: Int = 64, direction: Int = 0,
                       motion: Int = 0, _ steps: [Int: SkiffPattern.Step]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: 888)
        r[0] = steps.values.contains { $0.ties != 0 } ? 3 : 1
        r[1] = 103
        for (i, v) in [length, division, swing, gate, direction].enumerated() { r[2 + i] = UInt8(v + 64) }
        r[7] = UInt8(motion)
        for i in 0..<64 {
            var s = steps[i] ?? { var e = SkiffPattern.Step(); e.time = .note; return e }()
            if steps[i] == nil { s.notes = [] }
            r.replaceSubrange((8 + 9 * i)..<(8 + 9 * i + 9), with: put9(s))
        }
        for i in stride(from: 0, to: 64, by: 4) {          // core.h nudge_pack
            var w = 0
            for j in 0..<4 { w |= ((steps[i + j]?.nudge ?? 0) & 63) << (6 * j) }
            r[584 + i / 4 * 3] = UInt8(w & 0xFF); r[585 + i / 4 * 3] = UInt8(w >> 8 & 0xFF); r[586 + i / 4 * 3] = UInt8(w >> 16 & 0xFF)
        }
        return r
    }

    static func note(_ n: [Int], velocity: Int = 100, _ edit: (inout SkiffPattern.Step) -> Void = { _ in }) -> SkiffPattern.Step {
        var s = SkiffPattern.Step(); s.notes = n; s.velocity = velocity; edit(&s); return s
    }

    /// A project: Skiff 2.5.1's fresh record with these lists (track → [(pattern + 1 or 65, REPS byte)]), these patterns.
    static func project(_ lists: [Int: [(Int, Int)]], _ patterns: [Int: [UInt8]], tempo: Int? = nil, swing: Int? = nil, song: Int = 2) -> SkiffProjectData {
        var b = Array(SkiffProjectData.blank251.record)
        for (t, list) in lists {
            for (e, (p, reps)) in list.enumerated() {
                let o = SKF4.entriesAt + 4 * (t * 16 + e)
                b[o] = UInt8(p); b[o + 1] = UInt8(reps)
            }
        }
        b[SKF4.songModeAt] = UInt8(song)
        if let tempo { b[SKF4.globalsAt + 1] = UInt8(tempo & 0xFF); b[SKF4.globalsAt + 2] = UInt8(tempo >> 8) }
        if let swing { b[SKF4.globalsAt + 3] = UInt8(swing & 0xFF); b[SKF4.globalsAt + 4] = UInt8(swing >> 8) }
        let s = SKF4.hash(b[0..<SKF4.sumAt])
        for k in 0..<4 { b[SKF4.sumAt + k] = UInt8(s >> (8 * k) & 0xFF) }
        return SkiffProjectData(record: b, patterns: patterns, firmware: SkiffFirmware.v2_5_1.rawValue)
    }

    static func notes(_ p: SkiffProjectData, _ o: SkiffMIDIExport.Options = .init()) throws -> [(tick: Int, ch: Int, note: Int, vel: Int, len: Int)] {
        let (f, _) = try SkiffMIDIExport.midiFile(p, name: "T", options: o)
        return f.tracks.flatMap { $0.events }.compactMap { e in
            if case .note(let n, let v, let l) = e.kind { return (e.tick, e.channel, n, v, l) }
            return nil
        }.sorted { ($0.tick, $0.ch, $0.note) < ($1.tick, $1.ch, $1.note) }
    }

    // MARK: reading

    @Test func readsAStepAsSkiffWroteIt() throws {
        let s = Self.note([60, 64], velocity: 90) { s in
            s.accent = true; s.ratchet = 3; s.chance = 40; s.condition = 5; s.nudge = -7; s.ties = 0b10
        }
        let p = try #require(SkiffPattern(record: Self.record(length: 12, division: 4, swing: 30, gate: 100, direction: 2, [3: s])))
        #expect(p.length == 12 && p.division == 4 && p.swing == 30 && p.gate == 100 && p.direction == .pingPong)
        let r = p.steps[3]
        #expect(r.notes == [60, 64] && r.velocity == 90 && r.accent && !r.slide)
        #expect(r.ratchet == 3 && r.chance == 40 && r.condition == 5 && r.nudge == -7 && r.ties == 0b10)
        #expect(!p.steps[0].sounds)
    }

    @Test func refusesWhatNoFirmwareWrites() {
        var r = Self.record([0: Self.note([60])])
        #expect(SkiffPattern(record: r) != nil)
        r[8 + 4] = 5                                        // five notes
        #expect(SkiffPattern(record: r) == nil)
        var e = Self.record([:]); e[0] = 0                  // empty
        #expect(SkiffPattern(record: e) == nil)
    }

    @Test func readsTheSongFromTheRecord() throws {
        let rec = try #require(SkiffProjectData.blank251.project)
        #expect(rec.tempo == 120)                           // a new unit's (captured from skiff-sim, 2026-11-11)
        let p = Self.project([1: [(5, 16), (65, 2), (0, 0)]], [:], tempo: 97, song: 1)
        let r = try #require(p.project)
        #expect(r.tempo == 97 && r.songMode == .on)
        let e = r.entries(track: 1)
        #expect(e[0] == SongEntry(pattern: 5, reps: 1, chained: true))
        #expect(e[1] == SongEntry(pattern: 65, reps: 3))
        #expect(e[2].isEmpty)
    }

    // MARK: the song

    @Test func aPatternsPassesInTime() throws {
        let pat = Self.record([0: Self.note([60]), 4: Self.note([62]), 8: Self.note([64]), 12: Self.note([65])])
        let n = try Self.notes(Self.project([0: [(1, 1)]], [0: pat]))   // REPS 2
        #expect(n.map(\.tick) == [0, 960, 1920, 2880, 3840, 4800, 5760, 6720])
        #expect(n.allSatisfy { $0.len == 120 && $0.vel == 100 && $0.ch == 0 })   // a 1/16 is 240 ticks; GATE 64: half
        let (_, report) = try SkiffMIDIExport.midiFile(Self.project([0: [(1, 1)]], [0: pat]), name: "T")
        #expect(report.ticks == 7680 && report.notes == 8 && report.tracks == [0])
        #expect(abs(report.seconds - 4) < 0.001)              // two bars at 120
    }

    @Test func velocityAccentAndDrumLanes() throws {
        let pat = Self.record([0: Self.note([60], velocity: 0), 1: Self.note([60], velocity: 50) { $0.accent = true },
                               2: { var s = SkiffPattern.Step(); s.hits = 0b11; s.hitAccents = 0b10; s.velocity = 80; return s }()])
        let n = try Self.notes(Self.project([0: [(1, 0)]], [0: pat]))
        #expect(n.map(\.vel) == [96, 127, 80, 127])
        #expect(n.map(\.note) == [60, 60, 36, 38])
    }

    @Test func aTieAndASlideHoldTheNoteOn() throws {
        var tie = SkiffPattern.Step(); tie.time = .tie
        let pat = Self.record(gate: 64, [0: Self.note([60]), 1: tie, 2: tie, 4: Self.note([62]) { $0.slide = true }, 5: Self.note([67])])
        let n = try Self.notes(Self.project([0: [(1, 0)]], [0: pat]))
        #expect(n[0].note == 60 && n[0].tick == 0 && n[0].len == 2 * 240 + 120)    // to the last TIE's GATE
        #expect(n[1].note == 62 && n[1].len == 240)                                 // the slide: on to the next note
        #expect(n[2].note == 67 && n[2].tick == 1200 && n[2].len == 120)
    }

    @Test func perNoteTiesCarryOneNoteOfAChord() throws {
        let pat = Self.record([0: Self.note([60, 64]), 1: Self.note([60, 67]) { $0.ties = 0b01 }])
        let n = try Self.notes(Self.project([0: [(1, 0)]], [0: pat]))
        let c = n.filter { $0.note == 60 }, e = n.first { $0.note == 64 }!, g = n.first { $0.note == 67 }!
        #expect(c.count == 1 && c[0].len == 240 + 120)       // one C, on through the second step
        #expect(e.len == 120)                                // E, not tied on, ends at its GATE
        #expect(g.tick == 240 && g.len == 120)
    }

    @Test func swingNudgeRatchetAndFlam() throws {
        // SWING 30 + the global 20 = 50: even steps 240 + 48, odd 240 − 48
        let sw = Self.record(swing: 30, [0: Self.note([60]), 1: Self.note([60]), 2: Self.note([60])])
        #expect(try Self.notes(Self.project([0: [(1, 0)]], [0: sw], swing: 20)).map(\.tick) == [0, 288, 480])
        // NUDGE +16: a quarter of the step late
        let nu = Self.record([1: Self.note([60]) { $0.nudge = 16 }])
        #expect(try Self.notes(Self.project([0: [(1, 0)]], [0: nu])).map(\.tick) == [300])
        // RATCH ×4 at GATE 64: four 60-tick parts, each 30 long
        let ra = Self.record([0: Self.note([60]) { $0.ratchet = 4 }])
        let r = try Self.notes(Self.project([0: [(1, 0)]], [0: ra]))
        #expect(r.map(\.tick) == [0, 60, 120, 180] && r.allSatisfy { $0.len == 30 })
        // FLAM at 120 BPM: the grace at 9/16, the full hit 15 ms (28 ticks) later
        let fl = Self.record([0: Self.note([60], velocity: 96) { $0.flam = true }])
        let f = try Self.notes(Self.project([0: [(1, 0)]], [0: fl]))
        #expect(f.map(\.tick) == [0, 28] && f.map(\.vel) == [55, 96])
    }

    @Test func chainsRestsAndTheLongestList() throws {
        let a = Self.record(length: 4, [0: Self.note([60])]), b = Self.record(length: 8, [0: Self.note([72])])
        // T1: A (pattern 1) on CHAIN into B (pattern 2) × 2, then a REST: A B A B rest(B's 8 steps)
        // T2: a REST first (from the list's end round: pattern 1, 4 steps), then pattern 1
        let p = Self.project([0: [(1, 16), (2, 1), (65, 0)], 1: [(65, 0), (1, 0)]], [0: a, 1: b])
        let n = try Self.notes(p)
        #expect(n.filter { $0.ch == 0 }.map(\.tick) == [0, 960, 2880, 3840])
        #expect(n.filter { $0.ch == 1 }.map(\.tick) == [960])
        let (_, r) = try SkiffMIDIExport.midiFile(p, name: "T")
        #expect(r.ticks == 2 * (960 + 1920) + 1920)          // the longest list, its rest included
        #expect(r.leftOut.isEmpty)
    }

    @Test func pingPongAndReverse() throws {
        let steps = Dictionary(uniqueKeysWithValues: (0..<4).map { ($0, Self.note([60 + $0])) })
        let ping = Self.record(length: 4, direction: 2, steps)
        #expect(try Self.notes(Self.project([0: [(1, 1)]], [0: ping])).map(\.note) == [60, 61, 62, 63, 62, 61, 60, 61])
        let rev = Self.record(length: 4, direction: 1, steps)
        #expect(try Self.notes(Self.project([0: [(1, 0)]], [0: rev])).map(\.note) == [63, 62, 61, 60])
    }

    @Test func trigConditionsFillAndChance() throws {
        // 1:2 plays on the first of every two passes; 2:3 on the second of three
        let tc = Self.record(length: 1, [0: Self.note([60]) { $0.condition = 3 }])
        #expect(try Self.notes(Self.project([0: [(1, 3)]], [0: tc])).map(\.tick) == [0, 480])
        let tc23 = Self.record(length: 1, [0: Self.note([60]) { $0.condition = 6 }])
        #expect(try Self.notes(Self.project([0: [(1, 5)]], [0: tc23])).map(\.tick) == [240, 960])
        // FILL out unless held; !FILL the other way round
        let fill = Self.record([0: Self.note([60]) { $0.condition = 1 }, 1: Self.note([62]) { $0.condition = 2 }])
        let p = Self.project([0: [(1, 0)]], [0: fill])
        #expect(try Self.notes(p).map(\.note) == [62])
        #expect(try Self.notes(p, .init(fill: true)).map(\.note) == [60])
        #expect(try SkiffMIDIExport.midiFile(p, name: "T").report.leftOut.contains { $0.contains("FILL") })
        // a chance of 30: every step plays, or rolled the same way for the same seed
        let ch = Self.record(length: 16, Dictionary(uniqueKeysWithValues: (0..<16).map { ($0, Self.note([60]) { $0.chance = 30 }) }))
        let cp = Self.project([0: [(1, 0)]], [0: ch])
        #expect(try Self.notes(cp).count == 16)
        let r1 = try Self.notes(cp, .init(chance: .seeded(7))).map(\.tick), r2 = try Self.notes(cp, .init(chance: .seeded(7))).map(\.tick)
        #expect(r1 == r2 && r1.count < 16)
        // a chance of 0 never plays
        let never = Self.record([0: Self.note([60]) { $0.chance = 0 }])
        #expect(try Self.notes(Self.project([0: [(1, 0)]], [0: never])).isEmpty)
    }

    @Test func saysWhatItLeftOut() throws {
        let pat = Self.record(direction: 3, motion: 2, [0: Self.note([60])])
        let r = try SkiffMIDIExport.midiFile(Self.project([2: [(1, 0)]], [0: pat], song: 1), name: "T").report
        #expect(r.leftOut.contains { $0.contains("SONG on") })
        #expect(r.leftOut.contains { $0.contains("T3 plays in random order") })
        #expect(r.leftOut.contains { $0.contains("Knob motion on pattern 01") })
    }

    @Test func anEmptySongIsRefused() {
        #expect(throws: SkiffMIDIExport.ExportError.emptySong) { try SkiffMIDIExport.midiFile(SkiffProjectData.blank251, name: "T") }
        let bad = SkiffProjectData(record: [1, 2, 3], patterns: [:], firmware: "")
        #expect(throws: SkiffMIDIExport.ExportError.notAProject) { try SkiffMIDIExport.midiFile(bad, name: "T") }
    }


    /// A real project off the iPad (Files › Lupe › Skiff › Projects, a .json) as a .mid, to open in a DAW beside the FM-1:
    ///   MIDI_EXPORT_PROJECT=~/Downloads/<uuid>.json MIDI_EXPORT_OUT=~/Desktop swift test --filter exportsARealProject
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MIDI_EXPORT_PROJECT"] != nil)) func exportsARealProject() throws {
        let env = ProcessInfo.processInfo.environment
        struct File: Decodable { var name: String; var skiff: SkiffProjectData? }
        let f = try JSONDecoder().decode(File.self, from: Data(contentsOf: URL(fileURLWithPath: (env["MIDI_EXPORT_PROJECT"]! as NSString).expandingTildeInPath)))
        let p = try #require(f.skiff, "not a Skiff project")
        let (data, report) = try SkiffMIDIExport.data(p, name: f.name)
        let out = URL(fileURLWithPath: ((env["MIDI_EXPORT_OUT"] ?? "~/Desktop") as NSString).expandingTildeInPath)
            .appending(path: SkiffMIDIExport.fileName(f.name))
        try data.write(to: out)
        print("wrote", out.path, "·", report.notes, "notes ·", String(format: "%.1f s", report.seconds), "· left out:", report.leftOut)
    }

    // MARK: the file

    @Test func theFileParsesBack() throws {
        let pat = Self.record([0: Self.note([60]), 2: Self.note([67], velocity: 70)])
        let (data, _) = try SkiffMIDIExport.data(Self.project([0: [(1, 0)], 3: [(1, 0)]], [0: pat], tempo: 90), name: "Night Drive")
        let smf = try SMF(data)
        #expect(smf.format == 1 && smf.ppq == 960 && smf.tracks.count == 3)   // tempo, T1, T4
        #expect(smf.tracks[0].names == ["Night Drive"] && smf.tracks[0].tempo == 666_667)
        #expect(smf.tracks[1].names == ["T1 ANALOG"] && smf.tracks[2].names.first?.hasPrefix("T4") == true)
        #expect(smf.tracks[1].notes.map { [$0.tick, $0.channel, $0.note, $0.velocity, $0.length] } == [[0, 0, 60, 100, 120], [480, 0, 67, 70, 120]])
        #expect(smf.tracks[2].notes.allSatisfy { $0.channel == 3 })
        #expect(smf.tracks.allSatisfy { $0.end == 3840 })                    // every track ends with the song
        #expect(SkiffMIDIExport.fileName("A/B: C") == "A-B- C.mid" && SkiffMIDIExport.fileName("  ") == "Lupe song.mid")
    }

    @Test func variableLengthQuantities() {
        #expect(MIDIFile.vlq(0) == [0] && MIDIFile.vlq(127) == [127] && MIDIFile.vlq(128) == [0x81, 0])
        #expect(MIDIFile.vlq(0x0FFF_FFFF) == [0xFF, 0xFF, 0xFF, 0x7F])
    }
}

/// A Standard MIDI File read back: just enough to check what the writer wrote.
struct SMF {
    struct Note { var tick, channel, note, velocity, length: Int }
    struct Track { var names: [String] = []; var tempo: Int?; var notes: [Note] = []; var end = 0 }
    var format = 0, ppq = 0
    var tracks: [Track] = []

    init(_ data: Data) throws {
        let b = [UInt8](data)
        var i = 0
        func u(_ n: Int) -> Int { var v = 0; for _ in 0..<n { v = v << 8 | Int(b[i]); i += 1 }; return v }
        func vlq() -> Int { var v = 0; while true { let x = b[i]; i += 1; v = v << 7 | Int(x & 0x7F); if x & 0x80 == 0 { return v } } }
        guard String(decoding: b[0..<4], as: UTF8.self) == "MThd" else { throw DecodeError.short(cmd: 0) }
        i = 8; format = u(2); let n = u(2); ppq = u(2)
        for _ in 0..<n {
            guard String(decoding: b[i..<(i + 4)], as: UTF8.self) == "MTrk" else { throw DecodeError.short(cmd: 1) }
            i += 4; let len = u(4), stop = i + len
            var t = Track(), tick = 0, on: [Int: (Int, Int, Int)] = [:]
            while i < stop {
                tick += vlq()
                let s = b[i]; i += 1
                if s == 0xFF {
                    let type = b[i]; i += 1; let l = vlq(); let d = Array(b[i..<(i + l)]); i += l
                    if type == 0x03 { t.names.append(String(decoding: d, as: UTF8.self)) }
                    if type == 0x51 { t.tempo = Int(d[0]) << 16 | Int(d[1]) << 8 | Int(d[2]) }
                    if type == 0x2F { t.end = tick }
                } else if s & 0xF0 == 0x90 {
                    on[Int(b[i]) | Int(s & 15) << 8] = (tick, Int(s & 15), Int(b[i + 1])); i += 2
                } else if s & 0xF0 == 0x80 {
                    if let o = on.removeValue(forKey: Int(b[i]) | Int(s & 15) << 8) {
                        t.notes.append(Note(tick: o.0, channel: o.1, note: Int(b[i]), velocity: o.2, length: tick - o.0))
                    }
                    i += 2
                } else { i += 2 }
            }
            t.notes.sort { ($0.tick, $0.note) < ($1.tick, $1.note) }
            tracks.append(t)
        }
    }
}
