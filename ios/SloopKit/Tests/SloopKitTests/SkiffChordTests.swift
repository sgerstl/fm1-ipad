import Testing
@testable import SloopKit

/// Skiff's chord keys (chord.c): what a key plays and what the FM-1 calls it.
@Suite struct SkiffChordTests {
    @Test func diatonicChordsInTheKey() {
        // C major: DIA3 on D is D minor; DIA7 on G is G7; a key outside the scale (C#) builds on the note below (C)
        let d = SkiffChord.make(note: 62, mode: 1, voicing: 0, root: 0, scale: 1)!
        #expect(d.notes == [62, 65, 69] && SkiffChord.name(root: d.root, mask: d.mask) == "Dm")
        let g = SkiffChord.make(note: 67, mode: 2, voicing: 0, root: 0, scale: 1)!
        #expect(g.notes == [67, 71, 74, 77] && SkiffChord.name(root: g.root, mask: g.mask) == "G7")
        let cs = SkiffChord.make(note: 61, mode: 1, voicing: 0, root: 0, scale: 1)!
        #expect(cs.root == 60 && cs.notes == [60, 64, 67])
        // B in C major: the diminished triad; CHR builds on the major scale of ROOT
        let b = SkiffChord.make(note: 71, mode: 1, voicing: 0, root: 0, scale: 1)!
        #expect(SkiffChord.name(root: b.root, mask: b.mask) == "Bdim")
        #expect(SkiffChord.make(note: 62, mode: 1, voicing: 0, root: 0, scale: 0)!.notes == [62, 65, 69])
    }

    @Test func shapesAndVoicings() {
        #expect(SkiffChord.make(note: 60, mode: 0, voicing: 0, root: 0, scale: 1) == nil)
        let maj7 = SkiffChord.make(note: 60, mode: 6, voicing: 0, root: 0, scale: 1)!
        #expect(maj7.notes == [60, 64, 67, 71] && SkiffChord.name(root: 60, mask: maj7.mask) == "Cmaj7")
        #expect(SkiffChord.make(note: 60, mode: 3, voicing: 1, root: 0, scale: 1)!.notes == [60, 67, 76])       // OPEN 1-5-3
        #expect(SkiffChord.make(note: 60, mode: 3, voicing: 2, root: 0, scale: 1)!.notes == [64, 67, 72])       // INV1
        #expect(SkiffChord.make(note: 60, mode: 3, voicing: 3, root: 0, scale: 1)!.notes == [67, 72, 76])       // INV2
        #expect(SkiffChord.make(note: 60, mode: 5, voicing: 4, root: 0, scale: 1)!.notes == [48, 60, 64, 70])   // +OCT drops the 5th
        #expect(SkiffChord.name(root: 67, mask: SkiffChord.make(note: 67, mode: 8, voicing: 0, root: 0, scale: 1)!.mask) == "Gsus4")
        #expect(SkiffChord.name(root: 69, mask: SkiffChord.make(note: 69, mode: 9, voicing: 0, root: 0, scale: 1)!.mask) == "A5")
        #expect(SkiffChord.make(note: 60, mode: 3, voicing: 0, root: 0, scale: 1, oneVoice: true)!.notes == [60])
    }
}
