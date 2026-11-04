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
    public func trackDesc(_ id: Int) -> ParamDesc? { DeviceDisplay.trackDesc(trackDescs[id], id: id, params: params) }
}
