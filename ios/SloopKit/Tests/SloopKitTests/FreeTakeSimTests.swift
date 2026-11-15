#if canImport(CoreMIDI)
// Apple-only: not built for Android (android/BRIDGE.md §3).
import Foundation
import Testing
@testable import SloopKit

/// FREE TAKE levels 2 and 3 against skiff-sim built from Skiff-Lupe's firmware branch lupe-skiff-2.5.1-freetake (the
/// screen link's v7: TAKE 94, UNDO 95): what FakeSkiff's v7 was taught, checked against the firmware itself. Skipped
/// unless SKIFF_SIM=1; run the sim first (with several sims running, a --name and FELUCCA_PORT=<that name>).
///   SKIFF_SIM=1 swift test --filter FreeTakeSimTests
/// It plays eight quarter notes into T1 at 120 BPM with the transport stopped, as a hand would, then takes them from
/// here; the take is put back, then taken and kept, then undone and redone (the sim's T1 ends as it began).
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct FreeTakeSimTests {
    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return s
    }

    /// Eight quarter notes at 120 BPM on track t's channel, then Skiff's 2.5 s pause (ui_take.c FR_GAP) and a little.
    private func play(_ d: SkiffDriver, track t: Int) async throws {
        let ch = DeviceSession.keyChannel(track: t)
        let clock = ContinuousClock(), start = clock.now
        for i in 0..<8 {                                  // (on absolute times: sleeps one after another drift late)
            let n = UInt8(60 + [0, 3, 7, 10][i % 4])
            try await clock.sleep(until: start + .milliseconds(500 * i), tolerance: .zero)
            d.sendMIDI([0x90 | ch, n, 100])
            try await clock.sleep(until: start + .milliseconds(500 * i + 100), tolerance: .zero)
            d.sendMIDI([0x80 | ch, n, 0])
        }
        try await Task.sleep(for: .seconds(2.8))
    }

    @Test func pickerFromTheIPad() async throws {
        let d = try await driver()
        #expect(d.skiff.hasTakeLink)
        _ = try await d.transport(play: false)
        let sel = try await d.tracks().selected
        try await d.watch(screenLink: true, scope: false)
        let len0 = try await d.trackParam(track: sel, id: d.params.length)
        let shut = try await d.take()
        print("TAKE (closed):", shut)
        #expect(shut.rc == 0 && !shut.picker.open)
        #expect(try await d.take(.bars(1)).rc == 1)                        // an op with it shut: refused

        try await play(d, track: sel)
        let r = try await d.take(.start)
        print("TAKE op 8:", r)
        #expect(r.rc == 0 && r.picker.open && r.picker.track == sel)
        #expect(r.picker.firstBeats == 8 && r.picker.guesses.contains { abs($0 - 120) <= 2 })
        #expect(try await d.screen().flags.map { $0 & 8 != 0 } == true)   // SCREEN's flags bit 3
        #expect(try await d.undo().rc == 1)                               // undo refused while it's open

        let b = try await d.take(.bars(0))
        #expect(b.rc == 0 && b.picker.bars == 1)
        #expect(try await d.trackParam(track: sel, id: d.params.length) == 16)
        let f = try await d.take(.firstBeat(2))
        #expect(f.picker.firstBeat == 2)
        let first = try await d.synthStep(track: sel, index: 0)
        print("step 1 with the first beat on the third note:", first.notes)
        #expect(first.notes == [67])
        let k = try await d.take(.setTempo(false))
        let bpmNow = try await d.global(id: d.params.bpm)
        #expect(!k.picker.setsTempo && bpmNow == k.picker.tempoBefore)

        let back = try await d.take(.putBack)
        print("TAKE op 7:", back)
        #expect(!back.picker.open && back.picker.lastClose == .putBack)
        #expect(try await d.trackParam(track: sel, id: d.params.length) == len0)

        // the phrase is still there after a put-back: taken again and kept, then undone and redone
        let again = try await d.take(.start)
        #expect(again.picker.open)
        let kept = try await d.take(.keep)
        #expect(!kept.picker.open && kept.picker.lastClose == .kept)
        let u = try await d.undo()
        print("UNDO:", u)
        #expect(u.rc == 0 && u.back == 1 && u.copies >= 1)
        #expect(try await d.trackParam(track: sel, id: d.params.length) == len0)
        let redo = try await d.undo(redo: true)
        #expect(redo.rc == 0 && redo.back == 0)
        let u2 = try await d.undo()                                         // (T1 as it began)
        #expect(u2.rc == 0)
        // kept: the phrase is gone, a take finds nothing
        #expect(try await d.take(.start).picker.open == false)
        await d.close()
    }
}

#endif
