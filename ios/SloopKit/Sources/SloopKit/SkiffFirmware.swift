import Foundation

// Which Skiff-Lupe Lupe is talking to (INFO's version string), and what moves between them. Skiff 2.5 (2026-11-09)
// inserted FX › DELAY and FX › REVERB and took INSERT 2 out of its PAGES, so the screen link's page numbers moved
// (vault skiff-2.5.1-rebase.md, "Page numbers"). Lupe keeps one numbering of its own, Skiff 2.2's, with the two new
// pages past its end, and the driver translates SCREEN and SCREEN_GOTO at the wire: everything above the driver
// (SkiffButtonMap, the Sound pages, the SEQ cursor) stays as it was.

/// A Skiff release Lupe speaks.
public enum SkiffFirmware: String, CaseIterable, Sendable {
    case v2_2 = "FELUCCA v2.2"
    case v2_5_1 = "FELUCCA v2.5.1"

    public init?(version: String) { self.init(rawValue: version) }

    /// The device's undo (ui.c UNDO_N: SAVE held, then OCT− / OCT+): 8 on 2.2, 6 on 2.5 (the take log took the room).
    public var undoLevels: Int { self == .v2_2 ? 8 : 6 }
    /// FX › DELAY and FX › REVERB (2.5): KNOB 1 the track's send, KNOBS 2–4 the bus's globals.
    public var hasSendPages: Bool { self != .v2_2 }
    /// G_DMODE (GSID 27), INSERT's FILTR (type 9), SCL › CHORD's STRUM and DIR, MENU › CONTROL › KEEP SENDS (id 21).
    public var hasDelayMode: Bool { self != .v2_2 }
    /// FREE TAKE (2.5): a take kept on the FM-1 (SHIFT + SAVE after playing while stopped) replaces a track's pattern.
    public var hasFreeTake: Bool { self != .v2_2 }
    public var pageMap: SkiffPageMap { self == .v2_2 ? .identity : .v2_5 }
    /// "2.2", "2.5.1"
    public var short: String { String(rawValue.dropFirst("FELUCCA v".count)) }
}

/// Lupe's page numbers (Skiff 2.2's PAGES, plus FX › DELAY 46 and FX › REVERB 47) ↔ the connected firmware's.
public struct SkiffPageMap: Equatable, Sendable {
    /// Lupe's numbers for the two pages 2.2 doesn't have.
    public static let fxDelay = 46, fxReverb = 47
    /// device page → Lupe's; nil for identity
    let toLupe: [Int]?
    /// Lupe's page → device's (nil: no such page on this firmware)
    let toDevice: [Int?]?

    public static let identity = SkiffPageMap(toLupe: nil, toDevice: nil)

    /// Skiff 2.5.1's PAGES (params.c, NPAGES 47): ENV … FX 0–5 as before, FX › DELAY 6, FX › REVERB 7, DRIVE 8, INSERT 9,
    /// then 2.2's SLICER … SONG (9–45) one later (10–46). INSERT 2 is gone: its MIX is on INSERT's PRESETS card, so
    /// Lupe's INSERT 2 opens INSERT there.
    public static let v2_5: SkiffPageMap = {
        var lupe = [Int](repeating: 0, count: 47)
        for p in 0...5 { lupe[p] = p }
        lupe[6] = fxDelay; lupe[7] = fxReverb; lupe[8] = 6; lupe[9] = 7
        for p in 10...46 { lupe[p] = p - 1 }
        var device = [Int?](repeating: nil, count: 48)
        for (d, l) in lupe.enumerated() { device[l] = d }
        device[8] = 9                                           // INSERT 2 → INSERT
        return SkiffPageMap(toLupe: lupe, toDevice: device)
    }()

    /// The device's page in Lupe's numbers (127, HOME's, as it is; a page past the table as it is).
    public func lupe(_ device: Int) -> Int {
        guard let t = toLupe, device != 127, t.indices.contains(device) else { return device }
        return t[device]
    }
    /// Lupe's page as the device numbers it; nil where this firmware has no such page (FX › DELAY on 2.2).
    public func device(_ lupe: Int) -> Int? {
        if lupe == 127 { return 127 }
        guard let t = toDevice else { return lupe < SkiffPageMap.fxDelay ? lupe : nil }
        return t.indices.contains(lupe) ? t[lupe] : nil
    }
    /// A SCREEN reply or push in Lupe's numbers.
    public func lupe(_ s: UIState) -> UIState {
        var s = s
        s.page = lupe(s.page)
        return s
    }
}
