import Foundation
import Testing
@testable import SloopKit

/// The EDIT engine pages' data (SkiffEdit.swift): FM6's packed patch, the DRUM-X kit, the user sets' mix.
@Suite(.serialized) @MainActor struct SkiffEditTests {
    /// Packed as eng_fm6.c fm6_pack: operator 6's block first, fields sharing a byte kept apart, clamped to fm6_max.
    @Test func thePatchsFieldsWhereSkiffPacksThem() {
        var p = FM6Patch(bytes: Array(repeating: 0, count: 128))
        p.setOp(1, .output, 99)
        #expect(p.bytes[5 * 17 + 14] == 99)                                // OP1: the last block
        p.setOp(6, .detune, 14); p.setOp(6, .rateScale, 5)
        #expect(p.bytes[12] == 5 | 14 << 3)                                 // RS | DET << 3
        p.setOp(3, .coarse, 31); p.setOp(3, .mode, 1)
        #expect(p.bytes[3 * 17 + 15] == 1 | 31 << 1 && p.op(3, .coarse) == 31 && p.op(3, .mode) == 1)
        p.setOp(2, .leftCurve, 9)                                           // clamped to 3
        #expect(p.op(2, .leftCurve) == 3 && p.op(2, .rightCurve) == 0)
        p[.algorithm] = 40; p[.feedback] = 5; p[.keySync] = 1
        #expect(p[.algorithm] == 31 && p.bytes[111] == 5 | 1 << 3)
        p[.lfoWave] = 4; p[.pitchSens] = 7; p[.lfoKeySync] = 1
        #expect(p.bytes[116] == 1 | 4 << 1 | 7 << 4 && p.bytes.allSatisfy { $0 < 128 })
    }

    private func connect() async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        return (s, fake, run)
    }

    @Test func aPatchKitAndMixRoundTrip() async throws {
        let (s, fake, run) = try await connect()
        let store = try #require(s.skiffEdit)
        // FM6: read, a knob's change sent whole
        await store.readPatch(track: 1)
        #expect(store.patches[1]?.op(1, .output) == 99 && store.patches[1]?.name == "INIT VOICE")
        store.editPatch(track: 1) { $0.setOp(2, .fine, 42) }
        try await waitFor(5) { fake.fm6[1].op(2, .fine) == 42 }
        // a drag: several changes while one write is out end on the last
        for v in 0..<20 { store.editPatch(track: 1) { $0[.lfoSpeed] = v } }
        try await waitFor(5) { fake.fm6[1][.lfoSpeed] == 19 }
        // the kit: SNARE's B COLOR
        await store.readKit(lane: 1)
        #expect(store.kit[1]?.a == [36, 20, 60, 90, 60] && store.kit[1]?.filter == 1)
        store.editKit(lane: 1) { $0.b[4] = 5 }
        try await waitFor(5) { fake.dxKit[1][14] == 5 }
        // USR1's mix: four sounds, the third's REVERB
        await store.readMix(slot: 0)
        #expect(store.mixes[0]?.zones == [36...47, 48...59, 60...71, 72...96] && store.mixes[0]?.level[0] == 127)
        store.editMix(slot: 0) { $0.reverb[2] = 90 }
        try await waitFor(5) { fake.mixValues[0][16 + 2] == 90 }
        await store.readMix(slot: 1)
        #expect(store.mixes[1]?.rc == 1 && store.mixes[1]?.zones.isEmpty == true)
        run.cancel()
    }

    /// A stream of reads (screen pushes while a knob turns on the FM-1) is one read out and one after it, never a queue.
    @Test func readsDontQueueUp() async throws {
        let (s, fake, run) = try await connect()
        let store = try #require(s.skiffEdit)
        let before = fake.requests.filter { $0 == 68 }.count
        await withTaskGroup(of: Void.self) { g in for _ in 0..<20 { g.addTask { await store.readPatch(track: 1) } } }
        #expect(fake.requests.filter { $0 == 68 }.count - before <= 2)
        run.cancel()
    }

    /// SEQ on the FM-1 (NOTES, then PATTERN): Lupe follows and sends nothing back, no SCREEN_GOTO echo.
    @Test func seqOnTheDeviceIsNotEchoed() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        fake.screenLink = true
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { s.screenLinked && fake.screenWatched }
        let before = fake.requests.count
        fake.pressOnDevice(page: 41)
        try await waitFor(5) { s.deviceScreen?.page == 41 }
        fake.pressOnDevice(page: 43)
        try await waitFor(5) { s.deviceScreen?.page == 43 }
        try await Task.sleep(for: .milliseconds(500))
        #expect(!fake.requests[before...].contains(91))
        run.cancel()
    }
}
