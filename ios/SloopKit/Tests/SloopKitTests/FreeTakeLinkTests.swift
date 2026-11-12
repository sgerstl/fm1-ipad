import Foundation
import Testing
@testable import SloopKit

/// FREE TAKE levels 2 and 3 (Skiff-Lupe 2.5.1's screen link v7, `56 01 07`; vault batch-list.md item 4): the FM-1's
/// picker reported and driven from the iPad (TAKE, 94), a take started from here, and the FM-1's undo (UNDO, 95).
/// Against FakeSkiff's v7, taught from the firmware branch lupe-skiff-2.5.1-freetake (editor.c, ui_take.c) and checked
/// against skiff-sim built from it (FreeTakeSimTests). Older builds keep level 1 (Skiff251Tests).
@Suite(.serialized) @MainActor struct FreeTakeLinkTests {
    private func connect(version: Int = 7) async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load(.v2_5_1))
        fake.screenLink = true
        fake.screenLinkVersion = version
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        try await waitFor(5) { s.screenLinked && fake.screenWatched }
        return (s, fake, run)
    }

    @Test func v7IsSpokenOnlyWhenTheTagSaysSo() async throws {
        let (s, fake, run) = try await connect()
        #expect(s.takeLinked && fake.takeWatched)
        run.cancel()
        let (o, old, run6) = try await connect(version: 6)
        #expect(!o.takeLinked && !old.takeWatched)
        #expect(!old.requests.contains(94) && !old.requests.contains(95))
        run6.cancel()
    }

    /// The new build is its own pin: a new name and hash, the same identity, and the installer's default untouched.
    @Test func theTakeBuildIsPinned() throws {
        let f = LupeFirmware.skiff251Take
        let p = try f.load()
        #expect(p.product == "FM-1_725" && f.size == 610_429 && f.fileName == "Skiff-Lupe-2.5.1-take.fwsc")
        #expect(f.release != LupeFirmware.skiff251.release && f.release != LupeFirmware.releaseTag)
        #expect(LupeFirmware.matching(identity: "FM-1_725") == .skiff251)   // (identity: the family, as before)
        #expect(LupeFirmware.skiff251.sha256 == "80b21b33d05ccaa384636261e229eb94efdac847c93cc1f534d69082ff71302c")
    }

    @Test func pickerBytesDecode() throws {
        let b: [UInt8] = [1, 2, 3, 7, 3, 1, 96, 0, 48, 0, 64, 1, 0, 0, 2, 4, 8, 1, 120, 0, 1]
        let p = try TakePicker(b)
        #expect(p.open && p.lastClose == .putBack && p.track == 3 && p.pattern == 7)
        #expect(p.guesses == [96, 48, 192] && p.guess == 1 && p.bpm == 48 && p.relation(1) == "half" && p.relation(2) == "double")
        #expect(p.bars == 4 && p.firstBeat == 4 && p.firstBeats == 8 && p.setsTempo && p.tempoBefore == 120 && p.externalClock)
        var none = b; none[3] = 127
        #expect(try TakePicker(none).pattern == nil)
        #expect(throws: DecodeError.self) { try TakePicker(Array(b.prefix(20))) }
    }

    /// Played while stopped: offered after Skiff's 2.5 s pause, Keep that opens the picker, every choice re-writes the
    /// track on the FM-1 and Lupe follows it; Put back leaves nothing landed.
    @Test func offeredStartedChosenAndPutBack() async throws {
        let (s, fake, run) = try await connect()
        let t = s.selectedTrack, len0 = s.tracks[t].length, bpm0 = s.globalCell(s.ids.bpm).value
        fake.playOnDevice(track: t, notes: [60, 63, 67, 70, 72, 70, 67, 63])
        try await Task.sleep(for: .seconds(1))
        #expect(s.takeOffer == nil)                                   // (still within the pause)
        try await waitFor(4) { s.takeOffer != nil }
        let o = try #require(s.takeOffer)
        #expect(o.track == t && o.notes == 8 && o.canStart)

        s.startTake()
        try await waitFor(3) { s.takePicker != nil }
        let p = try #require(s.takePicker)
        #expect(s.takeOffer == nil && p.track == t && p.guesses == [90, 60, 120, 150] && p.bars == 1 && p.firstBeats == 8 && p.setsTempo)
        try await waitFor(3) { s.tracks[t].length == 16 && s.tracks[t].steps[0].notes == [60] && s.tracks[t].steps[2].notes == [63] }
        try await waitFor(3) { s.globalCell(s.ids.bpm).value == 90 && (s.deviceScreen?.flags ?? 0) & 8 != 0 }

        s.takeOp(.bars(1))
        try await waitFor(3) { s.tracks[t].length == 32 && s.tracks[t].steps[4].notes == [63] }
        s.takeOp(.firstBeat(2))
        try await waitFor(3) { s.takePicker?.firstBeat == 2 && s.tracks[t].steps[0].notes == [67] }
        s.takeOp(.guess(2))
        try await waitFor(3) { s.globalCell(s.ids.bpm).value == 120 }
        s.takeOp(.setTempo(false))
        try await waitFor(3) { s.takePicker?.setsTempo == false && s.globalCell(s.ids.bpm).value == bpm0 }

        // the FM-1's own knob: the picker here follows it
        fake.turnTakeKnobOnDevice(1, by: -1)
        try await waitFor(3) { s.takePicker?.bars == 1 && s.tracks[t].length == 16 }

        s.takeOp(.putBack)
        try await waitFor(3) { s.takePicker == nil }
        try await waitFor(3) { s.tracks[t].length == len0 && s.tracks[t].steps[0].notes.isEmpty }
        try await Task.sleep(for: .milliseconds(600))
        #expect(s.freeTake == nil && s.globalCell(s.ids.bpm).value == bpm0)
        #expect(fake.take.end == 2)
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    /// Kept: it lands as level 1's does, the strip offering Undo; Undo and Redo go to the FM-1's own undo.
    @Test func keptLandsAndUndoes() async throws {
        let (s, fake, run) = try await connect()
        let t = s.selectedTrack
        fake.playOnDevice(track: t, notes: [62, 65, 69])
        fake.shiftSaveOnDevice()                                      // (SHIFT + SAVE on the FM-1 this time)
        try await waitFor(3) { s.takePicker != nil }
        s.takeOp(.keep)
        try await waitFor(3) { s.freeTake != nil }
        let k = try #require(s.freeTake)
        #expect(s.takePicker == nil && k.track == t && k.undoFromHere && !k.undone && k.length == 16)
        #expect(s.tracks[t].steps[0].notes == [62])
        s.undoFreeTake()
        try await waitFor(3) { s.freeTake?.undone == true && s.tracks[t].steps[0].notes.isEmpty }
        s.undoFreeTake()
        try await waitFor(3) { s.freeTake?.undone == false && s.tracks[t].steps[0].notes == [62] }
        #expect(fake.undoBack == 0 && fake.undoCopies.count == 1)
        // the phrase was kept: SHIFT + SAVE again finds nothing new
        s.startTake()
        try await Task.sleep(for: .milliseconds(300))
        #expect(s.takePicker == nil)
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    /// The FM-1 keeps it with OCT+: Lupe learns how it closed (a keep, not a put-back) and lands it.
    @Test func keptOnTheFM1() async throws {
        let (s, fake, run) = try await connect()
        fake.playOnDevice(track: s.selectedTrack, notes: [60, 62])
        fake.shiftSaveOnDevice()
        try await waitFor(3) { s.takePicker != nil }
        fake.takeKeyOnDevice(keep: true)
        try await waitFor(3) { s.takePicker == nil && s.freeTake != nil }
        run.cancel()
    }

    /// Refusals copied from the firmware: an op with the picker shut, a take under the FM-1's MENU, undo while it's open.
    @Test func refusals() async throws {
        let (s, fake, run) = try await connect()
        let k = try #require(s.driver as? SkiffDriver)
        #expect(try await k.take(.bars(2)).rc == 1)
        fake.playOnDevice(track: s.selectedTrack, notes: [60, 64, 67])
        fake.screen.menu = 1
        #expect(try await k.take(.start).rc == 1)
        #expect(try await k.take().picker.open == false)
        fake.screen.menu = 0
        let r = try await k.take(.start)
        #expect(r.rc == 0 && r.picker.open)
        #expect(try await k.undo().rc == 1)
        // an external clock: TEMPO can't be set
        fake.globals[2] = 1
        #expect(try await k.take(.setTempo(true)).picker.setsTempo == false)
        _ = try await k.take(.putBack)
        #expect(try await k.undo().rc == 0)
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    /// Before v7 (a 2.5.1 build with `56 01 06`): the offer names SHIFT + SAVE, and nothing is asked of the FM-1.
    @Test func olderBuildOffersSHIFTSAVE() async throws {
        let (s, fake, run) = try await connect(version: 6)
        fake.playOnDevice(track: s.selectedTrack, notes: [60, 64])
        try await waitFor(4) { s.takeOffer != nil }
        #expect(s.takeOffer?.canStart == false)
        s.startTake()
        try await Task.sleep(for: .milliseconds(200))
        #expect(!fake.requests.contains(94) && fake.unansweredCommands.isEmpty)
        run.cancel()
    }
}
