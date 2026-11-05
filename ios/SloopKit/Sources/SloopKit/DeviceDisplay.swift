import Foundation

// What the FM-1's own screen shows that the editor protocol doesn't send (2026-11-03). SLOOP's DESC
// reply is the static descriptor (editor.c ed_tdesc): INS A / B / C whatever the INSERT's TYPE, raw
// ATK DEC REL with ENV SYNC on, and no curves for TIME, LFOHZ, CUTOFF and DB. The device draws with
// params.c track_desc and param_format, ported here from SLOOP 2.8.4 so both screens agree.

public enum DeviceDisplay {
    // MARK: Names that depend on the track (params.c track_desc)

    static let insertTypes = ["OFF", "SOFT", "HARD", "FOLD", "FUZZ", "CRUSH", "PHASR", "FLANG", "CHOR"]
    static let crushBits = (1...16).map(String.init)
    static let crushRate = ["689", "919", "1.1k", "1.4k", "1.8k", "2.2k", "2.8k", "3.7k", "4.4k", "5.5k",
                            "7.4k", "8.8k", "11k", "15k", "22k", "44k"]
    static let envSyncNames = ["0", "1/64T", "1/64", "1/32T", "1/64D", "1/32", "1/16T", "1/32D", "1/16", "1/8T", "1/16D",
                               "1/8", "1/4T", "1/8D", "1/4", "1/2T", "1/4D", "1/2", "1/1T", "1/2D", "1/1", "1/1D",
                               "2BAR", "3BAR", "4BAR"]

    /// params.c INS_DESC: the INSERT's A B C for the drives (SOFT..FUZZ), CRUSH, and the swept ones.
    static let insertDesc: [[(label: String, format: Int, names: [String], unit: String)]] = [
        [("DRIVE", Format.pct, [], ""), ("TONE", Format.cutoff, [], ""), ("LEVEL", Format.db, [], "")],
        [("BITS", Format.int, crushBits, ""), ("RATE", Format.int, crushRate, "Hz"), ("LPF", Format.cutoff, [], "")],
        [("RATE", Format.lfoHz, [], ""), ("DEPTH", Format.pct, [], ""), ("FDBK", Format.pct, [], "")],
    ]

    /// The descriptor the FM-1's screen uses for track param `id`, given the track's values.
    public static func trackDesc(_ d: ParamDesc?, id: Int, params p: [Int]) -> ParamDesc? {
        guard var d else { return nil }
        let value = { (k: Int) in k < p.count ? p[k] : 0 }
        if (54...56).contains(id), case let type = value(Param.insertType), type > 0, type < insertTypes.count {
            let x = insertDesc[type < 5 ? 0 : type == 5 ? 1 : 2][id - 54]
            d.label = x.label; d.format = x.format; d.names = x.names; d.unit = x.unit
            d.min = 0; d.max = 127
        } else if [1, 2, 4].contains(id), value(Param.envSync) != 0 {
            d.format = Format.int; d.names = envSyncNames; d.unit = ""
        }
        return d
    }

    // MARK: Values (params.c param_format)

    public enum Format {
        public static let int = 0, pct = 1, bipct = 2, time = 3, lfoHz = 4, cutoff = 5, db = 6, semi = 7, enumerated = 8
    }

    // tools/gen_tables.py, rounded as Python's round() does
    static let timeMsX10: [Int] = (0..<128).map { Int((1.0 * pow(10000, Double($0) / 127) * 10).rounded(.toNearestOrEven)) }
    static let lfoHzX100: [Int] = (0..<128).map { Int((0.05 * pow(800, Double($0) / 127) * 100).rounded(.toNearestOrEven)) }
    static let cutoffHz: [Int] = (0..<128).map { Int((30.0 * pow(16000.0 / 30, Double($0) / 127)).rounded(.toNearestOrEven)) }
    static let levelDbX10: [Int] = [-999] + (1..<128).map { Int((Double($0 - 112) / 2 * 10).rounded(.toNearestOrEven)) }

    /// fmt_fix: v with `d` decimals ("-9.5" for -95, 1).
    static func fix(_ v: Int, _ d: Int) -> String {
        let p = d == 1 ? 10 : 100, a = abs(v)
        let frac = String(a % p)
        return (v < 0 ? "-" : "") + "\(a / p)." + String(repeating: "0", count: d - frac.count) + frac
    }

    /// A value as the FM-1 shows it: the number and its unit (TIME, LFOHZ, CUTOFF, DB and name lists).
    /// nil for the formats the app shows its own way.
    public static func value(_ d: ParamDesc, _ v: Int) -> (text: String, unit: String)? {
        switch d.format {
        case Format.pct: return ("\(d.max > 0 ? (v * 100 + d.max / 2) / d.max : v)", "%")
        case Format.time:
            let ms10 = timeMsX10[v & 127]
            if ms10 < 100 { return (fix(ms10, 1), "ms") }
            if ms10 < 10000 { return ("\((ms10 + 5) / 10)", "ms") }
            return (ms10 >= 100_000 ? fix(ms10 / 1000, 1) : fix(ms10 / 100, 2), "s")
        case Format.lfoHz:
            let h = lfoHzX100[v & 127]
            return (h < 1000 ? fix(h, 2) : fix(h / 10, 1), "Hz")
        case Format.cutoff:
            let h = cutoffHz[v & 127]
            if h < 1000 { return ("\(h)", "Hz") }
            if h < 10000 { return (fix(h / 100, 1), "kHz") }
            return ("\((h + 500) / 1000)", "kHz")
        case Format.db:
            guard v > 0, v < 128 else { return ("OFF", "") }
            let x = levelDbX10[v]
            return x > -100 ? (fix(x, 1), "dB") : ("\((x - 5) / 10)", "dB")
        case Format.int where !d.names.isEmpty:
            // a name list on an INT: the range split evenly over the names
            let k = d.names.count, span = max(1, d.max - d.min + 1)
            let i = (min(max(v, d.min), d.max) - d.min) * k / span
            return (d.names[min(k - 1, max(0, i))], d.unit)
        default: return nil
        }
    }
}

extension DeviceSession {
    /// The selected track's param `id` as the FM-1's screen names it (DeviceDisplay.trackDesc).
    public func trackDesc(_ id: Int) -> ParamDesc? {
        guard dialect != .skiff else { return skiffTrackDesc(id) }   // Skiff's own rules (SkiffDisplay)
        return DeviceDisplay.trackDesc(trackDescs[id], id: id, params: params)
    }
}

// MARK: - Skiff's (params.c track_desc and the engines' desc hooks, Skiff 2.2)

/// What Skiff's screen calls a parameter that DESC names generically: DESC answers with `param_desc_of` (editor.c
/// ed_tdesc), which skips `track_desc`'s rules. Ported: the INSERT's A B C as its TYPE means them (ins_desc), ATTACK
/// DECAY RELEASE as note values with ENV SYNC on (ESYNC_DESC), and the engines' mode-dependent EDIT labels and name
/// lists (analog_desc, phys_desc, lofi_desc, noise_desc). The rest of Skiff's engines have no hook.
public enum SkiffDisplay {
    static let analogSyncWave = 5, analogSubWave = 6                        // eng_analog.c AW_SYNC, AW_SUB
    static let physChords = ["OCT", "5TH", "4TH", "MAJ", "MIN", "SUS", "7TH", "ROOT"]
    static let lofiWaves = ["SQ50", "SQ25", "SQ12", "SINE", "TRI", "SAW", "SAW2", "BAS1",
                            "BAS2", "ORGN", "HOLW", "VOXA", "VOXO", "VOXE", "BUZZ", "STAIR"]
    static let lofiDecays = ["CONST"] + (0...15).map { "D\($0)" } + (1...15).map { "L\($0)" }
    static let noiseLong = ["L23", "L20", "L17", "L15", "L13", "L11", "L9", "L7"]
    static let noiseMeta = ["127", "127B", "93", "63", "63B", "31", "15", "7"]

    /// The engine's own label (and format, names, unit) for its EDIT knob k (0…7), given its values E0, E1; nil:
    /// DESC's is right.
    static func engineDesc(_ engine: String, k: Int, e0: Int, e1: Int) -> (label: String, format: Int, names: [String], unit: String)? {
        typealias F = DeviceDisplay.Format
        switch engine {
        case "ANALOG":
            if k == 1, e0 == analogSyncWave { return ("SYNC", F.int, [], "") }
            if k == 2, e0 == analogSubWave { return ("SUB", F.pct, [], "") }
        case "PHYS":
            switch (e0 % 4, k) {                                            // PM_MODAL PM_STRING PM_MEMB PM_SYMP
            case (2, 1): return ("HARM", F.pct, [], "")
            case (2, 6): return ("BEND", F.pct, [], "")
            case (3, 1): return ("CHRD", F.int, physChords, "")
            case (3, 4): return ("SYMP", F.pct, [], "")
            case (3, 6): return ("BUZZ", F.pct, [], "")
            default: break
            }
        case "LOFI":
            if k == 2, e1 == 4 { return ("WAV#", F.int, lofiWaves, "") }    // RW_WRAM
            if k == 3, e0 == 4 { return ("DCY", F.int, lofiDecays, "") }    // CHIP_STEP
        case "NOISE":
            if k == 5, e0 >= 2 { return ("LEN", F.int, e0 == 2 ? noiseLong : noiseMeta, "") }   // NZ_LFSR, NZ_META
            if k == 7, e0 >= 2 { return ("CLK", F.int, [], "st") }
        default: break
        }
        return nil
    }
}

extension DeviceSession {
    /// Skiff: DESC's descriptor with track_desc's rules. Reads only the values it depends on, each from its own cell,
    /// so a knob relabels when TYPE, ENV SYNC or its engine's mode changes, and redraws for nothing else.
    func skiffTrackDesc(_ id: Int) -> ParamDesc? {
        guard var d = trackDescs[id] else { return nil }
        let pages = pageLayout ?? []
        func page(_ t: String) -> [Int?] { pages.first { $0.title == t }?.ids ?? [] }
        let ins = page("INSERT"), env = page("ENV"), lfo2 = page("LFO 2")
        if let k = ins.dropFirst().firstIndex(of: id), let typeID = ins.first ?? nil {
            let type = cell(typeID).value
            if type > 0, type < DeviceDisplay.insertTypes.count {
                let x = DeviceDisplay.insertDesc[type < 5 ? 0 : type == 5 ? 1 : 2][k - 1]
                d.label = x.label; d.format = x.format; d.names = x.names; d.unit = x.unit
                d.min = 0; d.max = 127
            }
        } else if [env[safe: 0] ?? nil, env[safe: 1] ?? nil, env[safe: 3] ?? nil].contains(id),
                  let sync = lfo2[safe: 3] ?? nil, cell(sync).value != 0 {
            d.format = DeviceDisplay.Format.int; d.names = DeviceDisplay.envSyncNames; d.unit = ""
        } else if d.label.hasPrefix("DEST"), let e0 = info?.firstEngineParam,
                  let first = d.names.firstIndex(of: "E1"), d.names.count >= first + 8 {
            // the matrix's destinations E1…E8 by the engine's own labels, as mod.c mod_dst_name writes them
            for k in 0..<8 {
                if let l = skiffTrackDesc(e0 + k)?.label, !l.isEmpty, !l.hasPrefix("-") { d.names[first + k] = l }
            }
        } else if let e0 = info?.firstEngineParam, (e0..<(e0 + 8)).contains(id) {
            let engine = tracks[safe: selectedTrack]?.engineName.uppercased() ?? ""
            if let x = SkiffDisplay.engineDesc(engine, k: id - e0, e0: cell(e0).value, e1: cell(e0 + 1).value) {
                d.label = x.label; d.format = x.format; d.names = x.names; d.unit = x.unit
            }
        }
        return d
    }
}
