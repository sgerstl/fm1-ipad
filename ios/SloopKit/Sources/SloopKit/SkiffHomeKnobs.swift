import Foundation

/// What KNOB 1…4 turn on Skiff's HOME: the selected track's engine's four main parameters (ui.c home_param:
/// `ENGINES[TSEL->eng_req]->knob[k]`, track scope, each named and shown through track_desc as a page's column is).
/// Each engine's `.knob` line in Skiff 2.5.1's eng_*.c (2.2's are the same). The iPad keeps its own copy of this table
/// (ios/FM1/TrackControls.swift TrackKnobBox.homeKnobs); this one is the phone's, checked against Skiff's code by
/// android/core's PageParityTests.
public enum SkiffHomeKnobs {
    public enum Param: Equatable, Sendable { case e(Int), atk, rel }

    /// Indexed by engine (INFO's order: 0 ANALOG … 14 DRUM-X).
    public static let table: [[Param]] = [
        [.e(4), .e(5), .atk, .rel],          // 0 ANALOG     eng_analog.c
        [.e(4), .e(5), .e(6), .rel],         // 1 DIGITAL (retired) eng_digital.c
        [.e(2), .e(3), .e(4), .rel],         // 2 PHASE      eng_phase.c
        [.e(1), .e(2), .e(3), .rel],         // 3 LOFI       eng_lofi.c
        [.e(0), .e(4), .atk, .rel],          // 4 SAMPLE     eng_sample.c
        [.e(0), .e(4), .e(5), .e(2)],        // 5 VOICE      eng_formant.c
        [.e(5), .e(6), .e(7), .e(1)],        // 6 TRIO       eng_trio.c
        [.e(0), .e(4), .e(6), .e(7)],        // 7 WHEEL      eng_wheel.c
        [.e(1), .e(2), .e(3), .e(5)],        // 8 GRAIN      eng_grain.c
        [.e(1), .e(2), .e(3), .e(4)],        // 9 PHYS       eng_phys.c
        [.e(1), .e(2), .e(3), .e(4)],        // 10 DRUM      eng_drum.c
        [.e(2), .e(3), .e(1), .rel],         // 11 NOISE     eng_noise.c
        [.e(2), .e(3), .e(4), .e(7)],        // 12 FM6       eng_fm6.c
        [.e(0), .e(1), .e(3), .e(6)],        // 13 SLICE     eng_slice.c
        [.e(0), .e(1), .e(2), .e(3)],        // 14 DRUM-X    eng_drumx.c
    ]

    /// Skiff's ids for ATTACK and RELEASE (params.c TP: P_ATK 1, P_REL 4).
    static let attackID = 1, releaseID = 4

    /// The track parameter ids HOME's four knobs turn for `engine`, given INFO's first engine parameter (P_E0).
    public static func ids(engine: Int, firstEngineParam e0: Int) -> [Int]? {
        guard table.indices.contains(engine) else { return nil }
        return table[engine].map { switch $0 { case .e(let n): e0 + n; case .atk: attackID; case .rel: releaseID } }
    }
}

extension DeviceSession {
    /// HOME's four for the selected track (nil off Skiff, or before INFO).
    @MainActor public var homeKnobIDs: [Int]? {
        guard dialect == .skiff, let e0 = info?.firstEngineParam, tracks.indices.contains(selectedTrack) else { return nil }
        return SkiffHomeKnobs.ids(engine: tracks[selectedTrack].engine, firstEngineParam: e0)
    }
}
