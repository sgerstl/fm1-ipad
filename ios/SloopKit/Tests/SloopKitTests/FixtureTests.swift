import Foundation
import Testing
@testable import SloopKit

/// Traffic captured from the FM-1 on SLOOP 2.8.4 with tools/sloopcapture.swift (2026-10-31).
/// snapshot-0: every read pass 1 makes, the device stopped. live-1: the same, then 60 s of WATCH 3
/// while Scott played, switched tracks and recorded steps. SLOOP's web editor was open at the same
/// time, so live-1 also holds replies to requests this app never sends.
struct Capture {
    struct Line: Decodable { let t: Double; let dir: String; let hex: String }
    let frames: [(dir: String, bytes: [UInt8])]

    init(_ name: String) throws {
        let url = Bundle.module.url(forResource: name, withExtension: "jsonl", subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        frames = try text.split(separator: "\n").map {
            let l = try JSONDecoder().decode(Line.self, from: Data($0.utf8))
            return (l.dir, l.hex.split(separator: " ").map { UInt8($0, radix: 16)! })
        }
    }

    var rx: [(cmd: UInt8, body: [UInt8])] { frames.filter { $0.dir == "rx" }.compactMap { Frame.decode($0.bytes) } }
    func replies(_ cmd: UInt8) -> [[UInt8]] { rx.filter { $0.cmd == cmd }.map(\.body) }
}

@Suite struct FixtureTests {
    let snap: Capture
    init() throws { snap = try Capture("snapshot-0") }

    @Test func infoIsSloop284Protocol12() throws {
        let info = try DeviceInfo(snap.replies(Cmd.info)[0])
        #expect(info.version == "FELUCCA SLOOP 2.8.4")
        #expect(info.protocolVersion == 12)
        #expect(info.isSupported)
        #expect(info.trackCount == 4)
        #expect(info.stepCount == 64)
        #expect(info.paramCount == 71)
        #expect(info.firstEngineParam == 63)
        #expect(info.engines.count == 12)
        #expect(info.engines.prefix(2) == ["ANALOG", "DIGITAL"])
    }

    @Test func trackList() throws {
        let list = try TrackList(snap.replies(Cmd.track)[0])
        #expect(list.tracks.count == 4)
        #expect(list.selected == 1)
        #expect(list.tracks[3].engine == 12)       // the drum track: engine byte == engine count
        #expect(list.tracks.allSatisfy { (0...127).contains($0.level) })
    }

    @Test func presetNamesForEveryEngine() throws {
        let all = try snap.replies(Cmd.names).map(PresetNames.init)
        #expect(all.map(\.engine) == Array(0..<12))
        #expect(all[1].names[1] == "DX RHODES")
        #expect(all.allSatisfy { !$0.names.isEmpty && $0.names.allSatisfy { !$0.isEmpty } })
    }

    @Test func everySynthStepDecodes() throws {
        let steps = try snap.replies(Cmd.trackStep).map(TrackStepReply.init)
        #expect(steps.count == 192)
        #expect(Set(steps.map { $0.track * 64 + $0.index }).count == 192)
        let chord = try #require(steps.first { $0.track == 1 && $0.index == 0 })
        #expect(chord.step.notes == [0x43, 0x3B, 0x3E])
        #expect(chord.step.time == .note)
        #expect(chord.step.velocity == 100)
        for s in steps.map(\.step) {
            #expect(s.notes.count <= 4)
            #expect(s.isOn == !s.notes.isEmpty || s.time != .note)
        }
    }

    @Test func everyDrumStepDecodes() throws {
        let steps = try snap.replies(Cmd.drumStep).map(DrumStepReply.init)
        #expect(steps.map(\.index) == Array(0..<64))
        #expect(steps[0].step.has(0))                      // kick on step 1
        for s in steps.map(\.step) {
            for lane in 0..<16 where !s.has(lane) { #expect(s.level(lane) == 0 && s.ratchet(lane) == 0) }
        }
    }

    @Test func paramsAndDesc() throws {
        let params = try snap.replies(Cmd.trackParam).map { try ParamValue($0, cmd: Cmd.trackParam) }
        #expect(params.count == 28)
        let lengths = params.filter { $0.id == Param.length }.map(\.value)
        #expect(lengths.allSatisfy { (1...64).contains($0) })
        let globals = try snap.replies(Cmd.get).map { try ParamValue($0, cmd: Cmd.get) }
        #expect(globals.first { $0.id == Global.bpm }?.value == 108)
        let scale = try ParamDesc(snap.replies(Cmd.desc)[0])
        #expect(scale.label == "SCL")
        #expect(scale.names == Music.scales.map(\.name))
    }

    @Test func liveState() throws {
        let l = try LiveState(snap.replies(Cmd.live)[0])
        #expect(snap.replies(Cmd.live)[0].count == 50)
        #expect(l.bpm == 108)
        #expect(l.playing == false)
        #expect(l.selected == 1)
        #expect(l.tracks.count == 4)
        #expect(l.tracks[0].length == 32)
    }

    @Test func requestsMatchTheirReplies() throws {
        // Pair each request the capture sent with the next reply of its command.
        var pending: [Request] = []
        for f in snap.frames {
            guard let (cmd, body) = Frame.decode(f.bytes) else { continue }
            if f.dir == "tx" { pending.append(try #require(request(cmd: cmd, args: body))) }
            else if let i = pending.firstIndex(where: { $0.cmd == cmd }) {
                #expect(pending[i].matches(body), "\(pending[i]) vs \(hexString(body))")
                pending.remove(at: i)
            }
        }
        #expect(pending.isEmpty)
    }

    @Test func liveCapturePushesDecode() throws {
        let live = try Capture("live-1")
        let pushes = try live.rx.filter { Cmd.pushes.contains($0.cmd) }.compactMap { try Push(cmd: $0.cmd, body: $0.body) }
        #expect(pushes.count == 75)
        let reloads = pushes.compactMap { if case .reload(_, _, let t) = $0 { t } else { nil } }
        #expect(reloads == [1, 2, 3, 2, 1, 0])
        let stepTracks = Set(pushes.compactMap { if case .stepChanged(_, let t) = $0 { t } else { nil } })
        #expect(stepTracks == [0, 1, 2, 3])
    }

    @Test func foreignRepliesDoNotMatchOurRequests() throws {
        // live-1 holds TRACK_STEP and DRUM_STEP replies another editor asked for.
        let r = Request.trackStep(track: 0, index: 5)
        #expect(!r.matches([1, 5, 0, 0, 0, 0, 0, 2, 0, 100, 0, 0, 0]))
        #expect(r.matches([0, 5, 0, 0, 0, 0, 0, 2, 0, 100, 0, 0, 0]))
        #expect(!Request.drumStep(index: 3).matches([4] + Array(repeating: 0, count: 13)))
    }
}

/// Rebuilds a Request from captured bytes, for pairing.
func request(cmd: UInt8, args a: [UInt8]) -> Request? {
    switch cmd {
    case Cmd.info: .info
    case Cmd.track: a.isEmpty ? .track : .selectTrack(Int(a[0]))
    case Cmd.names: .names(engine: Int(a[0]))
    case Cmd.trackStep: .trackStep(track: Int(a[0]), index: Int(a[1]))
    case Cmd.drumStep: .drumStep(index: Int(a[0]))
    case Cmd.trackParam: .trackParam(track: Int(a[0]), id: Int(a[1]))
    case Cmd.get: .global(id: Int(a[1]))
    case Cmd.desc: .desc(scope: Int(a[0]), id: Int(a[1]))
    case Cmd.watch: .watch(Int(a[0]))
    case Cmd.ping: .ping
    case Cmd.live: a.first == 1 ? .transport(play: a[1] != 0) : .live
    default: nil
    }
}

@Suite struct ChordTests {
    @Test func chordsAreBuiltOnTheScaleAsSLOOPDoes() {
        // C minor (root C, scale MIN)
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 1) == [60, 63, 67])          // TRIAD on C: C Eb G
        #expect(Music.chordNotes(on: 67, root: 0, scale: 2, type: 2) == [67, 70, 74, 77])      // 7TH on G: G Bb D F
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 3) == [60, 63, 70, 74])      // 9TH: 1 3 7 9
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 4) == [60, 65, 67])          // SUS4: C F G
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 5) == [60, 67, 72])          // POWER
        // C major: TRIAD on D is D F A; chromatic builds on minor
        #expect(Music.chordNotes(on: 62, root: 0, scale: 1, type: 1) == [62, 65, 69])
        #expect(Music.chordNotes(on: 60, root: 0, scale: 0, type: 1) == [60, 63, 67])
    }

    @Test func blackKeysAreChordModifiers() {
        // key 0 is F3; F# is key 1, G# key 3, A# key 5, C# key 8, D# key 10
        #expect(Music.chordModifier(ofKey: 1) == "maj/min")
        #expect(Music.chordModifier(ofKey: 3) == "+7")
        #expect(Music.chordModifier(ofKey: 5) == "sus4")
        #expect(Music.chordModifier(ofKey: 8) == "+9")
        #expect(Music.chordModifier(ofKey: 10) == "inv")
        #expect(Music.chordModifier(ofKey: 0) == nil)
    }
}
