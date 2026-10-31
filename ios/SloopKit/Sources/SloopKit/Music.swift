// Facts about SLOOP's music model that the protocol doesn't carry: scale intervals (firmware seq.c
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

    /// What the FM-1's key k plays (firmware seq.c kb_pitch): k = 0 is F3 (53), chromatic up to G5.
    /// quant 1 SNAP rounds down into the scale; quant 2 WHITE (or chord mode) walks the scale on the
    /// white keys, C4 the root, and silences the black keys. Then the OCT buttons and TRN. nil: silent.
    public static func keyPitch(_ k: Int, root: Int, scale: Int, quant: Int, chord: Int, transpose: Int, octave: Int) -> Int? {
        let masks = scales.map { $0.intervals.reduce(0) { $0 | 1 << $1 } }
        let mask = masks[max(0, min(masks.count - 1, scale))]
        var n = 53 + k
        if quant == 1 && chord == 0 {
            n += 12 * octave + transpose
            var guardCount = 12
            while guardCount > 0, (mask >> ((n - root + 120) % 12)) & 1 == 0 { n -= 1; guardCount -= 1 }
            return max(0, min(127, n))
        }
        if quant == 2 || chord != 0 {
            let m = chord != 0 && scale == 0 ? masks[2] : mask
            let degreeOf = [0, -1, 1, -1, 2, 3, -1, 4, -1, 5, -1, 6]
            var degree = degreeOf[n % 12]
            guard degree >= 0 else { return nil }
            degree += (n / 12 - 5) * 7
            let count = (0..<12).filter { (m >> $0) & 1 == 1 }.count
            var wo = degree / count
            degree %= count
            if degree < 0 { degree += count; wo -= 1 }
            var i = 0
            while i < 12 {
                if (m >> i) & 1 == 1 { if degree == 0 { break }; degree -= 1 }
                i += 1
            }
            n = 60 + root + 12 * wo + i
        }
        return max(0, min(127, n + 12 * octave + transpose))
    }

    public static let drumLanes = ["Kick", "Kick 2", "Snare", "Clap", "Hat", "Open hat", "Pedal", "Rim",
                                   "Snare 2", "Low tom", "Hi tom", "Crash", "Ride", "Shaker", "Conga", "Cowbell"]
    /// The GM note SLOOP plays each drum lane from (drums.c LANE_NOTE).
    public static let laneNotes = [36, 35, 38, 39, 42, 46, 44, 37, 40, 43, 48, 49, 51, 70, 63, 56]
    public static let levelNames = ["Normal", "Ghost", "Soft", "Hard"]

    /// P_SDIV: a step's length in beats.
    public static let divisionBeats: [Double] = [1, 0.5, 0.25, 0.125, 1.0 / 3, 1.0 / 6, 2, 4, 8]
    public static let divisionNames = ["1/4", "1/8", "1/16", "1/32", "8T", "16T", "1/2", "1 bar", "2 bars"]
}
