import Foundation
import Testing
@testable import SloopKit

/// Whole workflows against the demo FM-1, which holds section content as SLOOP does (a stored section
/// is a copy of the four tracks; a section that starts playing copies them back over the tracks).
@MainActor @Suite(.serialized) struct WorkflowTests {

    /// A connected session on a quiet demo FM-1 (no random edits), stopped.
    private func connected() async throws -> (SloopSession, FakeSloop, Task<Void, Never>) {
        let fake = FakeSloop(autoEdits: false)
        fake.manualClock = true
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        try await waitFor { session.songOrder != nil }
        session.setPlaying(false)
        try await waitFor { !fake.playing && !session.playing }
        return (session, fake, run)
    }

    private func has(_ s: SloopSession, track t: Int, step i: Int, note n: Int) -> Bool {
        let st = s.tracks[t].steps[i]
        return st.time == .note && st.notes.contains(n)
    }

    @Test func aLoopSavedToASectionComesBack() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        // make a loop: a note on track 1, step 2
        #expect(s.toggle(track: 0, index: 1, note: 60))
        try await waitFor { fake.steps[0][1].notes.contains(60) }

        // save it to the empty section D
        s.storeLoop(in: 3)
        try await waitFor { fake.sections[3] != nil }
        #expect(fake.sections[3]?.steps[0][1].notes.contains(60) == true)
        try await waitFor { s.song.stored(3) }

        // change the loop, then recall D (stopped: it loads at once) and the note is back
        #expect(s.toggle(track: 0, index: 1, note: 60))
        try await waitFor { !fake.steps[0][1].notes.contains(60) }
        s.playSection(3)
        try await waitFor { self.has(s, track: 0, step: 1, note: 60) }
        #expect(fake.sectionPlaying == 3)
    }

    @Test func unsavedEditsAreReplacedWhenASectionLoads() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        // an edit that is never stored, then section B (track 1 empty) is picked
        #expect(s.toggle(track: 0, index: 2, note: 62))
        try await waitFor { fake.steps[0][2].notes.contains(62) }
        s.playSection(1)
        try await waitFor { s.tracks[0].steps.allSatisfy { !$0.isOn } }
        #expect(!fake.steps[0][2].notes.contains(62))
    }

    @Test func aSongPlaysItsSectionsInOrder() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        // D: the loop with a marker note; then an order D (1 bar), B (2 bars), looping
        #expect(s.toggle(track: 0, index: 40, note: 65))
        try await waitFor { fake.steps[0][40].notes.contains(65) }
        s.storeLoop(in: 3)
        try await waitFor { fake.sections[3] != nil && s.song.stored(3) }
        s.setSongOrder(SongOrder(steps: [.init(section: 3, bars: 1), .init(section: 1, bars: 2)], loop: true))
        try await waitFor { fake.order.steps.map(\.section) == [3, 1] && fake.order.loop }

        // song mode, PLAY: the first step loads D
        s.toggleSongMode()
        try await waitFor { fake.songMode }
        #expect(s.toggle(track: 0, index: 40, note: 65))       // wipe the marker from the working loop
        try await waitFor { !fake.steps[0][40].notes.contains(65) }
        s.setPlaying(true)
        try await waitFor { self.has(s, track: 0, step: 40, note: 65) }
        try await waitFor { s.song.songPlaying }

        // after D's bar, B (track 1 empty)
        fake.advanceBars(1)
        try await waitFor { s.tracks[0].steps.allSatisfy { !$0.isOn } }
        try await waitFor { s.song.songStep == 1 }

        // the order can't change while the song plays
        s.setSongOrder(SongOrder(steps: [.init(section: 0, bars: 4)], loop: false))
        #expect(s.songMessage != nil)
        #expect(fake.order.steps.map(\.section) == [3, 1])

        // B's two bars, then round to D again
        fake.advanceBars(2)
        try await waitFor { self.has(s, track: 0, step: 40, note: 65) }
        s.setPlaying(false)
    }

    @Test func songRecWritesWhatWasPlayed() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        s.toggleSongRec()
        try await waitFor { fake.songRec }
        s.setPlaying(true)
        try await waitFor { fake.playing }
        fake.advanceBars(1)                                     // the first bar ticks the clock in
        s.playSection(1)                                       // B from the next bar
        try await waitFor { fake.sectionQueued == 1 }
        fake.advanceBars(2)                                     // B for 2 bars
        s.playSection(2)
        try await waitFor { fake.sectionQueued == 2 }
        fake.advanceBars(1)                                     // C for 1 bar
        s.toggleSongRec()
        try await waitFor { !fake.songRec }
        let recorded = fake.order.steps.map { [$0.section, $0.bars] }
        #expect(recorded.suffix(2) == [[1, 2], [2, 1]])
        // the iPad re-reads the order once SONG REC ends
        try await waitFor { s.songOrder?.steps.map(\.section) == fake.order.steps.map(\.section) }
        s.setPlaying(false)
    }

    @Test func songModeKeepsTheLoopAndStopBringsItBack() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        // a loop edit that is never stored, then the song plays section B over it
        #expect(s.toggle(track: 0, index: 50, note: 70))
        try await waitFor { fake.steps[0][50].notes.contains(70) }
        s.setSongOrder(SongOrder(steps: [.init(section: 1, bars: 4)], loop: true))
        try await waitFor { fake.order.steps.map(\.section) == [1] }
        s.toggleSongMode()
        try await waitFor { fake.songMode }
        s.setPlaying(true)
        try await waitFor { s.tracks[0].steps.allSatisfy { !$0.isOn } }
        // STOP: SLOOP puts the loop back, and the iPad shows it on every track
        s.setPlaying(false)
        try await waitFor { self.has(s, track: 0, step: 50, note: 70) }
    }

    @Test func editsMarkTheTracksUntilStoredOrReplaced() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }
        #expect(!s.tracksEdited)
        #expect(s.toggle(track: 0, index: 3, note: 61))
        #expect(s.tracksEdited)
        s.storeLoop(in: 3)
        #expect(!s.tracksEdited)
        #expect(s.toggle(track: 0, index: 3, note: 61))
        #expect(s.tracksEdited)
        try await waitFor { fake.sections[3] != nil && s.song.stored(3) }
        s.playSection(0)
        try await waitFor { !s.tracksEdited }
    }

    @Test func aFastDialSendsTheLastValue() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        var st = s.tracks[0].steps[0]
        #expect(st.isOn)
        for v in stride(from: 10, through: 120, by: 2) {
            st.velocity = v
            s.write(track: 0, index: 0, st)
        }
        try await waitFor { fake.steps[0][0].velocity == 120 }
        try await Task.sleep(for: .milliseconds(300))
        #expect(s.tracks[0].steps[0].velocity == 120)          // no older reply snapped it back
    }

    @Test func aSectionClearsOnlyWhenStopped() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }
        #expect(s.song.stored(2))

        // playing: SLOOP refuses, and the app says why without sending
        s.setPlaying(true)
        try await waitFor { s.playing }
        s.clearSection(2)
        #expect(s.songMessage != nil)
        #expect(fake.stored & 0b100 != 0)

        // stopped: C empties on the FM-1 and on the iPad
        s.setPlaying(false)
        try await waitFor { !fake.playing && !s.playing }
        s.clearSection(2)
        try await waitFor { fake.stored & 0b100 == 0 && !s.song.stored(2) }
    }

    @Test func theSpeakerGoesQuietOnlyWithUSBAudioFull() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }
        #expect(s.usbAudioFull == false)

        // quiet: USB AUDIO becomes FULL first (one settings write), then the master goes to 0
        s.setPlaying(true)
        try await waitFor { s.playing }
        s.muteSpeaker(true)
        try await waitFor { fake.settings[85] & 0x08 != 0 && fake.masterLevel == 0 }
        #expect(s.usbAudioFull == true)
        #expect(fake.order.steps.map(\.section) == [0, 1, 0, 2])        // the song order untouched

        // the iPad stops playing the sound: the MASTER knob is the FM-1's again
        s.muteSpeaker(false)
        try await waitFor { fake.masterLevel == 127 }
        s.setPlaying(false)
    }

    @Test func aBadSettingsWriteIsRefusedAndTheOrderRollsBack() async throws {
        let (s, fake, run) = try await connected()
        defer { run.cancel() }

        let before = s.songOrder
        fake.corruptNextPut = true                              // the FM-1 sees a CRC mismatch
        s.setSongOrder(SongOrder(steps: [.init(section: 2, bars: 8)], loop: false))
        try await waitFor { s.songMessage != nil }
        #expect(s.songOrder == before)
        #expect(fake.order.steps.map(\.section) == [0, 1, 0, 2])
    }
}

/// Out-of-range values from the device must never index past an array (the review of 2026-11-01).
@MainActor @Suite(.serialized) struct BadInputTests {
    @Test func pushesWithImpossibleValuesAreIgnoredOrClamped() async throws {
        let fake = FakeSloop(autoEdits: false)
        fake.manualClock = true
        var once = false
        let s = SloopSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { run.cancel() }
        try await waitFor { if case .connected = s.status { true } else { false } }

        fake.inject(Cmd.reload, [1, 1, 9])                       // track 9
        fake.inject(Cmd.stepChanged, [70, 0])                    // step 71
        fake.inject(Cmd.stepChanged, [3, 7])                     // track 8
        fake.inject(Cmd.trackChanged, [0, UInt8(Param.root)] + Frame.v14(-5))
        fake.inject(Cmd.trackChanged, [0, UInt8(Param.scale)] + Frame.v14(99))
        fake.inject(Cmd.trackChanged, [0, UInt8(Param.division)] + Frame.v14(-1))
        try await Task.sleep(for: .milliseconds(300))

        #expect((0..<4).contains(s.selectedTrack))
        #expect((0...11).contains(s.tracks[0].root))
        #expect(Music.scales.indices.contains(s.tracks[0].scale))
        #expect(s.stepDuration(0) > 0)
        if case .connected = s.status {} else { Issue.record("the session dropped the connection") }
    }

    @Test func aFrameThatNeverEndsIsDropped() {
        var a = SysExAssembler()
        let out = a.feed([0xF0, 0x7D] + [UInt8](repeating: 0x10, count: 10_000))
        #expect(out.isEmpty)
        // the next good frame still comes through
        #expect(a.feed([0xF0, 0x7D, 0x46, 0x4C, 0x01, 0xF7]).count == 1)
    }
}
