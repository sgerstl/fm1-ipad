import Foundation
import Testing
@testable import SloopKit

/// Skiff 2.5.1's own value text (params.c param_format, libc.c fmt_fix), where it differs from SLOOP's, and its
/// engines' descriptors after a PRESET. The whole of every page is checked against Skiff's code by android/core's
/// PageParityTests (android/fixtures/skiff/skiff-2.5.1-pages.json); these pin the rules in SloopKit itself.
@Suite(.serialized) @MainActor struct SkiffDisplayParityTests {
    func desc(_ fmt: Int, _ lo: Int, _ hi: Int, _ label: String = "X", unit: String = "") throws -> ParamDesc {
        try ParamDesc([0, 0, UInt8(fmt)] + Frame.v14(lo) + Frame.v14(hi) + Frame.v14(lo) + Array(label.utf8) + [0] + Array(unit.utf8) + [0])
    }

    @Test func fmtFixWritesNoZeroBeforeThePoint() {
        #expect(DeviceDisplay.skiffFix(5, 2) == ".05")
        #expect(DeviceDisplay.skiffFix(-5, 1) == "-.5")
        #expect(DeviceDisplay.skiffFix(152, 1) == "15.2")
        #expect(DeviceDisplay.skiffFix(0, 1) == ".0")
        #expect(DeviceDisplay.skiffFix(-555, 1) == "-55.5")
    }

    @Test func skiffValuesAreTheFM1s() throws {
        // LFOHZ below 10 Hz (GLO › CHORUS RATE, LFO RATE)
        #expect(formatValue(try desc(4, 0, 127), 0, skiff: true).shown == ".05 Hz")
        // PCT: a share of 127 unless the range is 0..100 (GLO › DELAY FEEDBACK 0..120)
        #expect(formatValue(try desc(1, 0, 120), 60, skiff: true).shown == "47%")
        #expect(formatValue(try desc(1, 0, 100), 60, skiff: true).shown == "60%")
        // CUTOFF in tenths of a kHz to the top
        #expect(formatValue(try desc(5, 0, 127), 126, skiff: true).shown == "15.2 kHz")
        #expect(formatValue(try desc(5, 0, 127), 127, skiff: true).shown == "16.0 kHz")
        // DB always to a tenth (INSERT's LEVEL under a drive)
        #expect(formatValue(try desc(6, 0, 127), 1, skiff: true).shown == "-55.5 dB")
        #expect(formatValue(try desc(6, 0, 127), 0, skiff: true).shown == "OFF")
        // SLOOP's stay as they were
        #expect(formatValue(try desc(4, 0, 127), 0).shown == "0.05 Hz")
        #expect(formatValue(try desc(5, 0, 127), 126).shown == "15 kHz")
    }

    @Test func fm6sAlgoAndPatchAreNamed() {
        #expect(SkiffDisplay.engineDesc("FM6", k: 0, e0: 0, e1: 0)?.names.first == "PAT")
        #expect(SkiffDisplay.engineDesc("FM6", k: 7, e0: 0, e1: 0)?.names == ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "OWN"])
    }

    /// Skiff pushes nothing for a PRESET the editor sent (editor.c ed_load_after), so the session reads the engine's
    /// descriptors and values itself: the EDIT pages name the new engine's knobs at once.
    @Test func aPresetOfAnotherEngineRenamesTheEditKnobs() async throws {
        let fake = FakeSkiff(try SkiffFixture.load(.v2_5_1))
        fake.selected = 0
        fake.engines[0] = (0, 0)
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { run.cancel() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        s.select(track: 0)
        let e0 = try #require(s.info?.firstEngineParam)
        try await waitFor(5) { s.trackDescs[e0]?.label == "WAVE" }                // ANALOG's
        s.loadPreset(engine: 2, index: 0)                                          // PHASE's first: PD BRASS
        // PHASE's own, read after the reply (one DESC at a time, then the values)
        try await waitFor(5) { s.trackDescs[e0 + 1]?.label == "WAVE2" && s.trackDescs[e0 + 2]?.label == "DCW" && s.cell(e0 + 2).value == 30 }
        #expect(s.trackDescs[e0 + 3]?.label == "ENV")
    }
}
