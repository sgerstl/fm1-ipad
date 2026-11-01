import Foundation
import Testing
@testable import SloopKit

@Suite struct SongFormatTests {
    @Test func pack7RoundTrip() {
        let data: [UInt8] = (0..<300).map { UInt8(($0 * 37) & 0xFF) }
        let packed = Pack7.encode(data)
        #expect(packed.allSatisfy { $0 < 0x80 })
        #expect(Pack7.decode(packed) == data)
        #expect(Pack7.encode([0x80, 0x01]) == [0x01, 0x00, 0x01])
        #expect(Pack7.readU35(Pack7.u35(0x1234_5678)[...]) == 0x1234_5678)
    }

    @Test func crc32IsZlibs() {
        #expect(CRC32.of(Array("123456789".utf8)) == 0xCBF4_3926)       // the standard check value
    }

    @Test func songOrderInTheSettingsObject() {
        var s = [UInt8](repeating: 0, count: 96)
        s[0] = 0x33; s[1] = 0x52; s[2] = 0x45; s[3] = 0x50                // "PER3" little-endian
        let o = SongOrder(steps: [.init(section: 2, bars: 8), .init(section: 0, bars: 1)], loop: true)
        let w = o.written(into: s)
        #expect(w[48] == 2 && w[49] == 1 && w[52] == 2 && w[53] == 8 && w[54] == 0 && w[55] == 1)
        #expect(SongOrder(settings: w) == o)
        #expect(Array(w[84...]) == Array(s[84...]) && Array(w[..<48]) == Array(s[..<48]))   // nothing else touched
        #expect(SongOrder(settings: [UInt8](repeating: 0, count: 96)) == nil)              // not SLOOP's settings
    }

    @Test func liveSongFieldsFromTheFM1() throws {
        // the real LIVE reply (snapshot-0): section A playing, A B C stored, a song of 4 steps
        let cap = try Capture("snapshot-0")
        let l = try LiveState(cap.replies(Cmd.live)[0])
        #expect(l.song.sectionPlaying == 0 && l.song.sectionQueued == nil)
        #expect(l.song.sectionsStored == 0b0111 && l.song.songSteps == 4)
        #expect(!l.song.songMode && !l.song.songPlaying && !l.song.songRecording)
    }

    @Test func songRequestsEncode() {
        #expect(Request.layerKey(layer: 7, key: 4, down: true).bytes == Frame.encode(Cmd.live, [2, 7, 4, 1]))
        #expect(Request.chain([0, 1, 1, 2]).bytes == Frame.encode(Cmd.live, [9, 4, 0, 1, 1, 2]))
        #expect(Request.bkGet(id: 1, offset: 0, count: 96).args == [1, 0, 0, 0, 0, 0, 96, 0])
    }
}

@Suite(.serialized) @MainActor struct SongSessionTests {
    @Test func sectionsChainsOrderAndSongRec() async throws {
        let fake = FakeSloop(autoEdits: false)
        fake.manualClock = true                                 // no bar ticks mid-test
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }

        // the order, read from the settings object at connect
        #expect(session.songOrder?.steps.map(\.section) == [0, 1, 0, 2])
        try await waitFor { session.song.sectionsStored == 0b0111 }

        // an empty section can't play; storing the loop fills it
        session.playSection(3)
        #expect(session.songMessage != nil)
        session.storeLoop(in: 3)
        try await waitFor { fake.stored == 0b1111 }

        // a used section takes the key twice: stored again, still stored
        session.storeLoop(in: 1)
        try await Task.sleep(for: .milliseconds(100))
        #expect(fake.stored == 0b1111)

        // a new order, written back through the backup commands (CRC checked by the fake)
        var o = session.songOrder!
        o.steps = [.init(section: 3, bars: 2), .init(section: 1, bars: 16)]
        o.loop = true
        session.setSongOrder(o)
        try await waitFor { fake.order.steps.map(\.section) == [3, 1] && fake.order.loop }

        // song mode, then back
        session.toggleSongMode()
        try await waitFor { fake.songMode }
        session.toggleSongMode()
        try await waitFor { !fake.songMode }

        // a chain needs playback, and the session has to have seen it (playChain refuses otherwise)
        session.setPlaying(true)
        try await waitFor { fake.playing && session.playing }
        session.playChain([0, 2])
        #expect(session.songMessage == nil)
        try await waitFor { fake.chain == [0, 2] }
        session.stopChain()
        try await waitFor { fake.chain.isEmpty }
        run.cancel()
    }
}
