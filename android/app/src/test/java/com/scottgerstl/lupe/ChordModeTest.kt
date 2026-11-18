package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.ui.edit.Roll
import com.scottgerstl.lupe.ui.shell.withChord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Chord works with the real core (Scott, 2026-11-17: "the chord key doesn't work"). */
class ChordModeTest {
    // layer 1: the real core always sends chord = false; the phone's own mode wins
    @Test fun thePhonesChordModeOverridesTheCoresFlag() {
        val real = EditorState(chord = false)
        assertTrue(withChord(real, true).chord)
        assertEquals(false, withChord(real, false).chord)
    }

    // layer 2: with Chord on, a tap on another pitch adds, picked step or not, up to the most; a tap on one of its notes still picks or removes
    @Test fun chordTapsAdd() {
        val f5 = listOf(77)
        assertEquals(Roll.Tap.Add, Roll.tap(f5, 72, picked = true, chord = true, maxNotes = 4))
        assertEquals(Roll.Tap.Add, Roll.tap(f5, 72, picked = false, chord = true, maxNotes = 4))
        assertEquals(Roll.Tap.Set, Roll.tap(f5, 72, picked = true, chord = false, maxNotes = 4))
        assertEquals(Roll.Tap.Full, Roll.tap(listOf(60, 64, 67, 71), 72, picked = true, chord = true, maxNotes = 4))
        assertEquals(Roll.Tap.Remove, Roll.tap(f5, 77, picked = true, chord = true, maxNotes = 4))
    }
}
