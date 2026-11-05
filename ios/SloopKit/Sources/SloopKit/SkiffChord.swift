import Foundation

/// Skiff's chord keys (chord.c, SCL > CHORD) and scales (seq.c SCALE_MASK), for the SEL pages' graphs: the chord a
/// key plays, built as the FM-1 builds it, and its name as the FM-1 writes it.
public enum SkiffChord {
    /// SCALE's sixteen (seq.c SCALE_MASK): bit i, i semitones above ROOT.
    public static let scaleMasks: [Int] = [
        0xFFF,
        1 | 1 << 2 | 1 << 4 | 1 << 5 | 1 << 7 | 1 << 9 | 1 << 11,             // MAJ
        1 | 1 << 2 | 1 << 3 | 1 << 5 | 1 << 7 | 1 << 8 | 1 << 10,             // MIN
        1 | 1 << 2 | 1 << 3 | 1 << 5 | 1 << 7 | 1 << 9 | 1 << 10,             // DOR
        1 | 1 << 2 | 1 << 4 | 1 << 5 | 1 << 7 | 1 << 9 | 1 << 10,             // MIX
        1 | 1 << 2 | 1 << 4 | 1 << 7 | 1 << 9,                                // PEN
        1 | 1 << 3 | 1 << 5 | 1 << 7 | 1 << 10,                               // MPEN
        1 | 1 << 2 | 1 << 3 | 1 << 5 | 1 << 7 | 1 << 8 | 1 << 11,             // HARM
        1 | 1 << 1 | 1 << 3 | 1 << 5 | 1 << 7 | 1 << 8 | 1 << 10,             // PHRY
        1 | 1 << 2 | 1 << 4 | 1 << 6 | 1 << 7 | 1 << 9 | 1 << 11,             // LYD
        1 | 1 << 1 | 1 << 3 | 1 << 5 | 1 << 6 | 1 << 8 | 1 << 10,             // LOC
        1 | 1 << 2 | 1 << 3 | 1 << 5 | 1 << 7 | 1 << 9 | 1 << 11,             // MEL
        1 | 1 << 3 | 1 << 5 | 1 << 6 | 1 << 7 | 1 << 10,                      // BLUES
        1 | 1 << 2 | 1 << 4 | 1 << 6 | 1 << 8 | 1 << 10,                      // WHOLE
        1 | 1 << 1 | 1 << 3 | 1 << 4 | 1 << 6 | 1 << 7 | 1 << 9 | 1 << 10,    // DIMHW
        1 | 1 << 2 | 1 << 3 | 1 << 5 | 1 << 6 | 1 << 8 | 1 << 9 | 1 << 11,    // DIMWH
    ]
    public static func scaleMask(_ scale: Int) -> Int { scaleMasks[min(max(scale, 0), scaleMasks.count - 1)] }

    /// CHRD's fixed shapes, MAJ to POW (CHORD_SHAPE).
    static let shapes: [[Int]] = [[0, 4, 7], [0, 3, 7], [0, 4, 7, 10], [0, 4, 7, 11], [0, 3, 7, 10], [0, 5, 7], [0, 7, 12]]
    public static let maxNotes = 4

    /// What a chord key plays.
    public struct Chord: Equatable, Sendable {
        public var notes: [Int]          // ascending, 0…127
        public var root: Int             // DIA may move it down onto the scale
        public var mask: Int             // its tones above the root (bit i: i semitones)
    }

    /// The chord on `note` (chord_make): CHRD `mode` (0 OFF, 1 DIA3, 2 DIA7, 3 MAJ … 9 POW), VOICING `voicing` (CLOSE,
    /// OPEN, INV1, INV2, +OCT) in the track's ROOT and SCALE. `oneVoice` (MONO, LEGATO, UNISON with the ARP off) plays
    /// the root alone. nil when CHRD is OFF.
    public static func make(note: Int, mode: Int, voicing: Int, root keyRoot: Int, scale: Int, oneVoice: Bool = false) -> Chord? {
        guard (1...9).contains(mode) else { return nil }
        var r = note
        var iv: [Int] = []
        if mode >= 3 {
            iv = shapes[mode - 3]
        } else {
            var mask = scaleMask(scale)
            if mask == 0xFFF { mask = scaleMasks[1] }          // CHR: the major scale of ROOT
            var guardN = 12
            while guardN > 0, (mask >> (((r - keyRoot) % 12 + 12) % 12)) & 1 == 0 { r -= 1; guardN -= 1 }
            let deg = (0..<12).filter { (mask >> $0) & 1 != 0 }
            let at = deg.firstIndex(of: ((r - keyRoot) % 12 + 12) % 12) ?? 0
            for i in 0..<(mode == 2 ? 4 : 3) {
                let k = at + 2 * i
                iv.append(deg[k % deg.count] + 12 * (k / deg.count) - deg[at])
            }
        }
        let mask = iv.reduce(0) { $0 | 1 << ($1 % 12) }
        if oneVoice { return Chord(notes: [min(max(r, 0), 127)], root: r, mask: mask) }
        switch voicing {
        case 1: if iv.count >= 3 { iv[1] += 12 }               // OPEN: 1-5-3(-7)
        case 2, 3:
            for _ in 0..<(voicing == 3 ? 2 : 1) { iv.append(iv.removeFirst() + 12) }   // INV1, INV2
        case 4:                                                // +OCT: the root an octave down; a seventh drops its fifth
            if iv.count == maxNotes { iv.remove(at: 2) }
            iv.insert(-12, at: 0)
        default: break
        }
        iv.sort()
        var out: [Int] = []
        for v in iv where out.count < maxNotes {
            let x = r + v
            guard (0...127).contains(x), out.last != x else { continue }
            out.append(x)
        }
        if out.isEmpty { out = [min(max(r, 0), 127)] }
        return Chord(notes: out, root: r, mask: mask)
    }

    /// A chord's name as the FM-1 writes it (chord_name): "C", "Cm7", "F#m7b5", "Gsus4", "A5".
    public static func name(root: Int, mask: Int) -> String {
        func bit(_ i: Int) -> Bool { (mask >> i) & 1 != 0 }
        let mi = bit(3), ma = bit(4), b5 = bit(6), p5 = bit(7), s5 = bit(8), d7 = bit(9), m7 = bit(10), M7 = bit(11)
        var q = "", x = ""
        if mi && !ma && b5 && !p5 { q = d7 ? "dim7" : m7 ? "m7b5" : "dim" }
        else if ma && !mi && s5 && !p5 { q = m7 ? "+7" : M7 ? "+M7" : "aug" }
        else if ma && !mi { q = m7 ? "7" : M7 ? "maj7" : d7 ? "6" : "" }
        else if mi { q = m7 ? "m7" : M7 ? "mM7" : d7 ? "m6" : "m" }
        else if bit(5) { q = m7 ? "7" : ""; x = "sus4" }
        else if bit(2) { q = m7 ? "7" : ""; x = "sus2" }
        else { q = "5" }
        return noteNames[((root % 12) + 12) % 12] + q + x
    }
    /// Skiff's note names (N_NOTE): sharps as "#".
    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
}
