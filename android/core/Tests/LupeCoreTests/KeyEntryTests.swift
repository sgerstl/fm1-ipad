import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Decision 5 (phone decisions): note entry is the FM-1's keys only, into the selected step; Chord adds up to four.
/// And Scott's answer of 2026-11-14 on scenes: a kept scene is replaced only when the screen confirmed.
@Suite(.serialized) @MainActor struct KeyEntryTests {
    /// FakeSkiff with a notes stream the test plays into, as the FM-1's keys arrive on the transport.
    final class Keys: SysExTransport, @unchecked Sendable {
        let fake: FakeSkiff
        let notes: AsyncStream<NoteEvent>
        let sink: AsyncStream<NoteEvent>.Continuation
        init(_ fake: FakeSkiff) { self.fake = fake; (notes, sink) = AsyncStream.makeStream(of: NoteEvent.self) }
        var frames: AsyncStream<[UInt8]> { fake.frames }
        var clock: AsyncStream<ClockEvent> { fake.clock }
        func send(_ frame: [UInt8]) { fake.send(frame) }
        func key(_ n: Int, channel: Int) { sink.yield(NoteEvent(on: true, channel: UInt8(channel), note: UInt8(n), velocity: 90)); sink.yield(NoteEvent(on: false, channel: UInt8(channel), note: UInt8(n), velocity: 0)) }
    }
    final class Box { var writes = true; var log: [String] = [] }

    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff, Keys) {
        let fake = try #require(FakeSkiff(demo: true))
        let keys = Keys(fake)
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return keys }),
                             publish: { _, _ in }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil) { try await Task.sleep(for: .milliseconds(20)) }
        if fake.playing {
            let w = box.writes; box.writes = true
            core.handle(json: #"{"intent":"stop"}"#); box.writes = w
            let stop = Date().addingTimeInterval(3)
            while Date() < stop, fake.playing || core.session.playing { try await Task.sleep(for: .milliseconds(20)) }
        }
        box.log.removeAll()
        return (core, fake, keys)
    }

    func settle(_ cond: () -> Bool, _ what: String) async throws {
        let end = Date().addingTimeInterval(3)
        while !cond() { if Date() > end { Issue.record("timed out: \(what)"); return }; try await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func chordOffReplacesAndMovesOn() async throws {
        let box = Box()
        let (core, fake, keys) = try await connected(box)
        defer { core.stop() }
        let t = core.editorTrack()
        core.handle(json: #"{"intent":"stepSelect","step":4}"#)
        keys.key(64, channel: t)
        try await settle({ fake.steps[t][4][0] == 1 && fake.steps[t][4][1] == 64 }, "E4 into step 5")
        #expect(core.selectedStep == 5)
        keys.key(67, channel: t)                                                        // the next key, the next step
        try await settle({ fake.steps[t][5][1] == 67 }, "G4 into step 6")
        #expect(fake.unansweredCommands.isEmpty)
    }

    @Test func chordOnAddsUpToFour() async throws {
        let box = Box()
        let (core, fake, keys) = try await connected(box)
        defer { core.stop() }
        let t = core.editorTrack()
        core.handle(json: #"{"intent":"stepSelect","step":3}"#)
        keys.key(60, channel: t)                                                        // a note in, chord off
        try await settle({ fake.steps[t][3][1] == 60 }, "C4")
        core.handle(json: #"{"intent":"stepSelect","step":3}"#)
        core.handle(json: #"{"intent":"chordToggle"}"#)
        for n in [64, 67, 71, 74] { keys.key(n, channel: t); try await Task.sleep(for: .milliseconds(120)) }
        try await settle({ fake.steps[t][3][0] == 4 }, "four notes")
        #expect(Array(fake.steps[t][3][1...4]) == [60, 64, 67, 71])                   // the fifth (74) refused
        #expect(core.selectedStep == 3)                                                 // the cursor stays
        #expect(box.log.contains { $0.contains("four notes") })
    }

    @Test func notWrittenReadOnlyPlayingOrOnAnotherTrack() async throws {
        let box = Box()
        let (core, fake, keys) = try await connected(box)
        defer { core.stop() }
        let t = core.editorTrack()
        core.handle(json: #"{"intent":"stepSelect","step":7}"#)
        let before = fake.steps[t][7]
        keys.key(72, channel: (t + 1) % 6)                                              // another track's channel
        box.writes = false
        keys.key(72, channel: t)                                                        // read-only
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.steps[t][7] == before)
        #expect(box.log.contains { $0.hasPrefix("read-only: key") })
        box.writes = true
        core.handle(json: #"{"intent":"play"}"#)
        try await settle({ core.session.playing }, "playing")
        keys.key(72, channel: t)                                                        // playing: the sequencer's notes look the same
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.steps[t][7] == before)
    }

    @Test func aKeptSceneNeedsTheScreensConfirmation() async throws {
        let box = Box()
        let (core, fake, _) = try await connected(box)
        defer { core.stop() }
        core.handle(json: #"{"intent":"sceneStore","scene":5}"#)                      // empty: stores at once
        try await settle({ fake.scenes[5] != nil }, "stored")
        let kept = try #require(fake.scenes[5]).map(\.mute)
        try await settle({ (core.session.skiffSong?.perform?.kept.dropFirst(5).first ?? false) && !(core.session.skiffSong?.busy ?? true) }, "kept read")
        core.handle(json: #"{"intent":"trackMute","track":1}"#)                        // change what a store would take
        try await settle({ fake.muted[0] != kept[0] }, "muted")
        try await settle({ !(core.session.skiffSong?.busy ?? true) }, "idle")
        core.handle(json: #"{"intent":"sceneStore","scene":5}"#)                      // kept, unconfirmed: refused
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.scenes[5]?.map(\.mute) == kept)
        #expect(box.log.contains { $0.contains("must confirm") })
        core.handle(json: #"{"intent":"sceneStore","scene":5,"confirmed":true}"#)    // confirmed: replaced
        try await settle({ fake.scenes[5]?.map(\.mute) != kept }, "replaced")
        #expect(fake.unansweredCommands.isEmpty)
    }
}
