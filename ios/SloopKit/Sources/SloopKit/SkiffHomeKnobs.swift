import Foundation

/// What KNOB 1…4 turn on Skiff's HOME: the selected track's engine's four main parameters (ui.c home_param:
/// `ENGINES[TSEL->eng_req]->knob[k]`, track scope, each named and shown through track_desc as a page's column is).
/// Each engine's `.knob` line in Skiff 2.5.1's eng_*.c (2.2's are the same). The iPad keeps its own copy of this table
/// (ios/FM1/TrackControls.swift TrackKnobBox.homeKnobs); this one is the phones' (Android's PhoneCore and the iPhone
/// both read `DeviceSession.homeKnobs` below), checked against Skiff's code by android/core's PageParityTests.
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

/// One parameter as the FM-1 shows it: the label (track_desc's), the value text (param_format's), the range, and a
/// held step's lock. A sound page's column and HOME's four are both this.
public struct ShownParam: Equatable, Sendable {
    public var scope: Int
    public var id: Int
    public var label: String
    /// As the FM-1 shows it ("72", "-3", "710 Hz", "SAW"), and as VoiceOver or TalkBack should say it.
    public var text: String
    public var spoken: String
    public var value: Int
    public var min: Int
    public var max: Int
    /// It picks from names, not a number.
    public var isList: Bool
    /// A list's names, indexed by `value` (the DESC's names; nil for a number).
    public var names: [String]?
    /// The held step (Session.lockStep) has its own value for this parameter; `value` is then that value.
    public var locked: Bool
}

/// HOME's four knobs for the selected track, as the FM-1's HOME screen shows them.
public struct HomeKnobs: Equatable, Sendable {
    /// The selected track, from 0.
    public var track: Int
    public var trackName: String
    /// The engine's name as INFO gives it, in capitals ("ANALOG"), and the sound's ("ACID").
    public var engine: String
    public var preset: String
    /// KNOB 1…4, in the FM-1's order.
    public var knobs: [ShownParam]
    /// The knob last turned on the FM-1 (0…3) and when, or nil. The FM-1 lights its card for 40 frames (ui_input.c
    /// ui.hot_t) from the turn. The link says which parameter moved (CHANGED) but not that HOME was the screen it was
    /// turned on, so a knob is hot when its parameter changed on the FM-1, from any page; a sound loading on the FM-1
    /// lights none (Session.lastTouched). It comes 150 ms after the turn.
    public var hot: Int?
    public var hotAt: Date?
    /// The FM-1's screen is on HOME, where its knobs turn these four.
    public var fm1Home: Bool
}

extension DeviceSession {
    /// A parameter of `track` (scope 0) or a global (scope 1) as the FM-1 shows it, in Skiff's number rules.
    @MainActor public func shownParam(track: Int, scope: Int, id: Int) -> ShownParam {
        let d = scope == 0 ? trackDesc(id) : globalDescs[id]
        let lockedValue = scope == 0 ? lockStep.flatMap { step in
            motion[track]?.events.first { $0.lock && $0.step == step && $0.id == id }?.value } : nil
        let v = lockedValue ?? (scope == 0 ? cell(id).value : globalCell(id).value)
        let lo = d?.min ?? 0, hi = Swift.max(d?.max ?? 127, lo)
        let f = formatValue(d, v, skiff: true)
        return ShownParam(scope: scope, id: id, label: d?.label ?? "", text: f.shown, spoken: f.spoken, value: v, min: lo, max: hi,
                          isList: d.map { $0.format == 8 || !$0.names.isEmpty } ?? false,
                          names: d.flatMap { $0.names.isEmpty ? nil : Array(repeating: "", count: Swift.max(0, $0.min)) + $0.names },
                          locked: lockedValue != nil)
    }

    /// HOME's four for the selected track: nil off Skiff, before the FM-1 is read, or for an engine the table doesn't
    /// know. Observed: reading it in a view or withObservationTracking follows the track, its sound, the four values,
    /// the FM-1's own turns and its screen.
    @MainActor public var homeKnobs: HomeKnobs? {
        guard isConnected, let ids = homeKnobIDs else { return nil }
        let t = selectedTrack, tr = tracks[t]
        var hot: Int?, at: Date?
        if let touched = lastTouched, touched.scope == 0, let k = ids.firstIndex(of: touched.id) { hot = k; at = touched.at }
        return HomeKnobs(track: t, trackName: tr.displayName, engine: tr.engineName.uppercased(), preset: tr.presetName,
                         knobs: ids.map { shownParam(track: t, scope: 0, id: $0) }, hot: hot, hotAt: at,
                         fm1Home: screenLinked && (deviceScreen?.home ?? false))
    }

    /// Turns HOME's knob `slot` (0…3) to `value` on the selected track, as a page's column does (clamped by the FM-1).
    /// False when there is no such knob. It writes to the FM-1: the caller keeps its own read-only gate.
    @MainActor @discardableResult public func setHomeKnob(_ slot: Int, to value: Int) -> Bool {
        guard let ids = homeKnobIDs, ids.indices.contains(slot) else { return false }
        set(track: selectedTrack, param: ids[slot], to: value)
        return true
    }
}
