import Foundation
import Testing
@testable import SloopKit

/// The Swift slot builder against SLOOP's own (tools/sampleio.py). Expected values from:
///   x = [0.8 * exp(-3.0 * t) * sin(2 * pi * 220 * t) + 0.1 * sin(2 * pi * 1000 * t) for t = i / sr, i < sr // 2]
///   s = to_int16(resample(x, sr, 22050)); h, d = user_slot("Tape 1", [(s, 60, None, None)])
/// printing len and zlib.crc32 of h and d (python3, 2026-11-03).
@Suite struct UserSampleTests {
    static func signal(_ sr: Int) -> [Double] {
        (0..<(sr / 2)).map { i in
            let t = Double(i) / Double(sr)
            return 0.8 * exp(-3.0 * t) * sin(2 * Double.pi * 220 * t) + 0.1 * sin(2 * Double.pi * 1000 * t)
        }
    }

    @Test(arguments: [
        // rate, resampled count, first samples, header CRC, data length, data CRC
        (48000, 11025, [609, 3233, 5755, 8101, 10211], UInt32(0x34356464), 5513, UInt32(0x969c0385)),   // k == 2 (2.18 rounds to 2)
        (44100, 11025, [662, 3287, 5808, 8151, 10256], 0x6915a0b3, 5513, 0x0e6b8132),                   // k == 2
        (55125, 11025, [530, 3156, 5687, 8036, 10159], 0x3413018e, 5513, 0x32b0dce9),                   // 2.5: Python rounds to even, 2
        (96000, 11025, [913, 3532, 6041, 8366, 10445], 0x03dda3de, 5513, 0xcdc10c5c),                   // k == 4: moving average
        (16000, 11024, [0, 2631, 5166, 7571, 9757], 0x83d1afc8, 5512, 0x25bed67e),                      // up: interpolation only
    ])
    func matchesSampleio(sr: Int, count: Int, first: [Int], headerCRC: UInt32, dataLength: Int, dataCRC: UInt32) throws {
        let x = UserSample.resample(Self.signal(sr), from: sr, to: UserSample.rate)
        #expect(x.count == count)
        let s = UserSample.toInt16(x)
        #expect(s.prefix(5).map(Int.init) == first)
        let (h, d) = try UserSample.slot(name: "Tape 1", samples: s, root: 60)
        #expect(h.count == UserSample.headerLength && CRC32.of(h) == headerCRC)
        #expect(d.count == dataLength && CRC32.of(d) == dataCRC)
        #expect(Array(h.prefix(16)) == Array("FSMP".utf8) + [1, 0, 1, 0] + Array("TAPE 1".utf8) + [0, 0])
    }

    @Test func limits() throws {
        #expect(UserSample.maxData == 81408 && UserSample.maxSamples == 162_816)
        #expect(abs(UserSample.maxSeconds - 7.384) < 0.001)
        #expect(throws: DeviceSession.SampleError.tooLong) {
            try UserSample.slot(name: "LONG", samples: Array(repeating: 0, count: UserSample.maxSamples + 1))
        }
        #expect(throws: DeviceSession.SampleError.empty) { try UserSample.slot(name: "NONE", samples: []) }
        _ = try UserSample.slot(name: "FULL", samples: Array(repeating: 0, count: UserSample.maxSamples))
    }
}

@Suite(.serialized) @MainActor struct SampleSessionTests {
    @Test func uploadEraseAndUseOnTheDemo() async throws {
        let fake = FakeSloop(autoEdits: false)
        fake.manualClock = true
        fake.sampleWriteDelay = 0.002
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }

        // read on connect: USR1 holds the demo's sample, the rest are empty
        #expect(session.sampleSlots.count == 4)
        #expect(session.sampleSlots[0] == SampleSlot(zones: 1, name: "GUITAR", kib: 41))
        #expect(session.sampleSlots[1].isEmpty)

        var edits = 0
        session.onEdit = { edits += 1 }
        let x = UserSample.resample(UserSampleTests.signal(48000), from: 48000, to: UserSample.rate)
        var steps: [Double] = []
        try await session.uploadSample(slot: 1, name: "Tape 1", samples: UserSample.toInt16(x)) { steps.append($0) }
        #expect(steps.first == 0 && steps.last == 1 && steps.count == 1 + 22)     // 5513 bytes: 22 writes
        #expect(session.sampleSlots[1] == SampleSlot(zones: 1, name: "TAPE 1", kib: 6))
        #expect(fake.sampleSlots[1].data == UserSample.imaEncode(UserSample.toInt16(x)))
        #expect(edits == 0)                                  // samples are the FM-1's, not the project's

        await #expect(throws: DeviceSession.SampleError.tooLong) {
            try await session.uploadSample(slot: 2, name: "LONG", samples: Array(repeating: 1, count: UserSample.maxSamples + 2)) { _ in }
        }
        #expect(session.sampleSlots[2].isEmpty)

        try await session.eraseSample(slot: 1)
        #expect(session.sampleSlots[1].isEmpty)

        // USR3 on track 0, which the demo has on DIGITAL (track 1 is already SAMPLE)
        let info = try #require(session.info)
        await session.useSample(slot: 2, onTrack: 0)
        let e = try #require(info.engines.firstIndex(of: "SAMPLE"))
        #expect(session.tracks[0].engine == e && session.tracks[0].presetName == "SMPL3")
        #expect(edits >= 1)
        try await waitFor { fake.engine[0] == e && fake.params[0][info.firstEngineParam] == 10 && fake.params[0][info.firstEngineParam + 3] == 0 }
        // the RELOAD the preset pushed re-reads the track: the name holds, from SET
        try await Task.sleep(for: .milliseconds(300))
        #expect(session.tracks[0].presetName == "SMPL3")
        #expect(session.params[info.firstEngineParam] == 10)
        #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught")
        run.cancel()
    }

    @Test func skiffTakesSamplesInItsThreeSlots() async throws {
        // Skiff 2.2: the same cmds 11–15 as SLOOP, three slots, and SET's USR1 found from SET's own names
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        defer { #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught"); run.cancel() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        #expect(session.dialect == .skiff && session.capabilities.contains(.samples))
        try await waitFor { session.sampleSlots.count == 3 }
        #expect(session.sampleSlots[0] == SampleSlot(zones: 1, name: "KALIMBA", kib: (FakeSkiff.kalimba.state.dataLength + 1023) / 1024))
        #expect(session.sampleSlotName(2) == "USR3")

        let x = UserSample.resample(UserSampleTests.signal(48000), from: 48000, to: UserSample.rate)
        try await session.uploadSample(slot: 2, name: "Tape 2", samples: UserSample.toInt16(x)) { _ in }
        #expect(session.sampleSlots[2] == SampleSlot(zones: 1, name: "TAPE 2", kib: 6))
        #expect(fake.sampleSlots[2].data == UserSample.imaEncode(UserSample.toInt16(x)))
        // no fourth slot on Skiff
        await #expect(throws: DeviceSession.SampleError.refused(stage: "begin", rc: 1)) {
            try await session.uploadSample(slot: 3, name: "NOPE", samples: UserSample.toInt16(x)) { _ in }
        }

        // what a slot holds, read back to hear it: the demo's tone in USR1, the take just sent in USR3
        let held = try #require(try await session.storedSample(slot: 0))
        #expect(held.samples.count == UserSample.rate && abs(held.rate - Double(UserSample.rate)) < 1)
        let back = try #require(try await session.storedSample(slot: 2))
        let sent = UserSample.toInt16(x)
        #expect(back.samples == UserSample.imaDecode(UserSample.imaEncode(sent), count: sent.count))
        #expect(try await session.storedSample(slot: 1) == nil)          // empty

        // USR3 on track 0: SAMPLE, SET at USR3 as SET's names place it, LOOP off
        let info = try #require(session.info)
        let e = try #require(info.engines.firstIndex(of: "SAMPLE"))
        await session.useSample(slot: 2, onTrack: 0)
        #expect(session.tracks[0].engine == e && session.tracks[0].presetName == "USR3")
        let base = try #require(session.userSetBase)
        try await waitFor { fake.params[0][info.firstEngineParam] == base + 2 && fake.params[0][info.firstEngineParam + 3] == 0 }
    }

    @Test func skiffStopsTheSongForSampleWorkAndLupeStartsItAgain() async throws {
        // Skiff stops the transport for every sample write and for the read-back (ed_flash_stop; BACKUP_LIST): the
        // song playing before starts again after, through a read, an upload and an erase
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        defer { #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught"); run.cancel() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        #expect(session.sampleWorkStopsSong)
        session.setPlaying(true)
        try await waitFor { fake.playing }

        func stoppedThenResumed(_ what: String, _ work: () async throws -> Void) async throws {
            let before = fake.starts
            try await work()
            // stopped by the work, started again by Lupe after it: one more start, and playing
            try await waitFor { fake.starts == before + 1 && fake.playing }
            #expect(session.playing, "\(what)")
        }
        try await stoppedThenResumed("read back") { _ = try await session.storedSample(slot: 0) }
        let x = UserSample.toInt16(UserSample.resample(UserSampleTests.signal(48000), from: 48000, to: UserSample.rate))
        var sawStop = false
        try await stoppedThenResumed("upload") {
            try await session.uploadSample(slot: 1, name: "LIVE", samples: x) { _ in if !fake.playing { sawStop = true } }
        }
        #expect(sawStop, "the fake stopped for the writes, as the firmware does")
        try await stoppedThenResumed("erase") { try await session.eraseSample(slot: 1) }
        #expect(session.sampleSlots[1].isEmpty)
    }

    @Test func skiffRefusesShortSampleFormsWithoutAReply() async throws {
        // ed_args_ok: BEGIN and ERASE take exactly one byte, INFO none; past the last slot there's no reply either
        let fake = FakeSkiff(try SkiffFixture.load())
        fake.send(Frame.encode(Cmd.smpBegin, []))
        try await Task.sleep(for: .milliseconds(50))
        fake.send(Frame.encode(Cmd.smpErase, [0, 0]))
        try await Task.sleep(for: .milliseconds(50))
        fake.send(Frame.encode(Cmd.smpInfo, [0]))
        try await Task.sleep(for: .milliseconds(50))
        fake.send(Frame.encode(Cmd.smpBegin, [3]))
        try await Task.sleep(for: .milliseconds(50))
        #expect(fake.unansweredCommands == [Cmd.smpBegin, Cmd.smpErase, Cmd.smpInfo, Cmd.smpBegin])
    }

    @Test func adpcmDecodesWhatItEncodes() {
        // the round trip stays close to the signal (4-bit ADPCM: within a few percent of full scale once settled)
        let x = UserSample.toInt16(UserSample.resample(UserSampleTests.signal(48000), from: 48000, to: UserSample.rate))
        let y = UserSample.imaDecode(UserSample.imaEncode(x), count: x.count)
        #expect(y.count == x.count)
        let err = zip(x.dropFirst(200), y.dropFirst(200)).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(err < 3000)
    }

    @Test func endRefusesBadData() async throws {
        // the firmware's checks, on the demo: END without BEGIN, writes out of order, a CRC that doesn't match
        let fake = FakeSloop(autoEdits: false)
        let c = SloopClient(transport: fake)
        await c.start()
        let (h, d) = try UserSample.slot(name: "X", samples: (0..<1000).map { Int16($0 % 200 * 100) })
        #expect(try await c.sampleEnd(slot: 2, header: h) == 6)
        #expect(try await c.sampleBegin(slot: 2) == 0)
        #expect(try await c.sampleWrite(slot: 2, offset: 768, Array(d.prefix(256))) == 1)
        #expect(try await c.sampleWrite(slot: 2, offset: 512, Array(d.prefix(256))) == 0)
        #expect(try await c.sampleEnd(slot: 2, header: h) == 3)     // the rest of the data never came
        #expect(try await c.sampleSlots()[2].isEmpty)
        await c.close()
    }
}
