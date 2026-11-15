// Facts about Felucca's music model (as Skiff keeps it; first ported from SLOOP) that the protocol doesn't carry: scale intervals (firmware seq.c
// SCALE_MASK, names in DESC of P_SCALE), drum lanes (EDITOR_PROTOCOL.md v5) and step divisions
// (params.c N_SDIV).

public enum Music {
    public static let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    public static let spokenNoteNames = ["C", "C sharp", "D", "D sharp", "E", "F", "F sharp", "G", "G sharp", "A", "A sharp", "B"]

    public static func noteName(_ n: Int) -> String { "\(noteNames[n % 12])\(n / 12 - 1)" }
    public static func spokenNoteName(_ n: Int) -> String { "\(spokenNoteNames[n % 12]) \(n / 12 - 1)" }

    /// Scale index (P_SCALE) to its pitch classes relative to the root.
    public static let scales: [(name: String, spoken: String, intervals: [Int])] = [
        ("CHR", "chromatic", Array(0...11)),
        ("MAJ", "major", [0, 2, 4, 5, 7, 9, 11]),
        ("MIN", "minor", [0, 2, 3, 5, 7, 8, 10]),
        ("DOR", "dorian", [0, 2, 3, 5, 7, 9, 10]),
        ("MIX", "mixolydian", [0, 2, 4, 5, 7, 9, 10]),
        ("PEN", "pentatonic", [0, 2, 4, 7, 9]),
        ("MPEN", "minor pentatonic", [0, 3, 5, 7, 10]),
        ("HARM", "harmonic minor", [0, 2, 3, 5, 7, 8, 11]),
        ("PHRY", "phrygian", [0, 1, 3, 5, 7, 8, 10]),
        ("LYD", "lydian", [0, 2, 4, 6, 7, 9, 11]),
        ("LOC", "locrian", [0, 1, 3, 5, 6, 8, 10]),
        ("MEL", "melodic minor", [0, 2, 3, 5, 7, 9, 11]),
        ("BLUES", "blues", [0, 3, 5, 6, 7, 10]),
        ("WHOLE", "whole tone", [0, 2, 4, 6, 8, 10]),
        ("DIMHW", "diminished half-whole", [0, 1, 3, 4, 6, 7, 9, 10]),
        ("DIMWH", "diminished whole-half", [0, 2, 3, 5, 6, 8, 9, 11]),
    ]

    public static func inScale(_ note: Int, root: Int, scale: Int) -> Bool {
        let s = scales[max(0, min(scales.count - 1, scale))]
        return s.intervals.contains(((note - root) % 12 + 12) % 12)
    }

    /// Piano-roll rows, high to low: every scale note from the lowest to the highest note used, plus
    /// any used note outside the scale, widened around the middle to at least `minRows`.
    /// A chromatic track has no scale to fold to, so it folds to the notes it uses.
    public static func foldedRows(used: Set<Int>, root: Int, scale: Int, minRows: Int) -> [Int] {
        var lo = used.min() ?? 60, hi = used.max() ?? 72
        let chromatic = scale == 0 && !used.isEmpty
        func rows() -> [Int] {
            (lo...hi).filter { used.contains($0) || (!chromatic && inScale($0, root: root, scale: scale))
                || (chromatic && ($0 < used.min()! || $0 > used.max()!)) }
        }
        var r = rows()
        var up = true
        while r.count < minRows, lo > 0 || hi < 127 {
            if up, hi < 127 { hi += 1 } else if lo > 0 { lo -= 1 } else { hi += 1 }
            up.toggle()
            r = rows()
        }
        return r.reversed()
    }

    /// ARP's modes (params.c N_AMODE: append-only), as the FM-1's screen shows them.
    public static let arpModes = ["OFF", "UP", "DN", "UPDN", "RND", "ORD", "REPEAT", "DNUP", "UP+8", "CONV", "DIVG",
                                  "PINKY", "THUMB", "WALK", "CHORD"]

    public static let drumLanes = ["Kick", "Kick 2", "Snare", "Clap", "Hat", "Open hat", "Pedal", "Rim",
                                   "Snare 2", "Low tom", "Hi tom", "Crash", "Ride", "Shaker", "Conga", "Cowbell"]
    /// The GM note SLOOP plays each drum lane from (drums.c LANE_NOTE).
    public static let laneNotes = [36, 35, 38, 39, 42, 46, 44, 37, 40, 43, 48, 49, 51, 70, 63, 56]
    /// Skiff's drum grid: 8 lanes and the GM note each plays (EDITOR_PROTOCOL.md "v5: the drum grid").
    public static let skiffDrumLanes = ["Kick", "Snare", "Clap", "Hat", "Open hat", "Tom", "Rim", "Bell"]
    public static let skiffLaneNotes = [36, 38, 39, 42, 46, 45, 37, 56]

    /// P_SDIV: a step's length in beats.
    public static let divisionBeats: [Double] = [1, 0.5, 0.25, 0.125, 1.0 / 3, 1.0 / 6, 2, 4, 8]
    public static let divisionNames = ["1/4", "1/8", "1/16", "1/32", "8T", "16T", "1/2", "1 bar", "2 bars"]
}

extension Array {
    /// nil past the ends: for tables indexed by a value from the device.
    public subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
