package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.edit.Roll
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Edit tab's step grid: which rows show, what a tap does, and how the steps scroll under a docked panel (decisions 31 and 35). */
class RollModelTest {
    @Test fun theWindowOpensOnThePatternsNotes() {
        assertEquals(Roll.DEFAULT_TOP, Roll.topFor(emptyList()))            // nothing yet: C4 to B4
        val top = Roll.topFor(listOf(48, 52, 55))                            // C3 E3 G3: 8 pitches, 4 rows spare, 2 above
        assertTrue(55 <= top && 48 >= top - Roll.ROWS + 1); assertEquals(57, top)
        assertEquals(84, Roll.topFor(listOf(36, 84)))                        // wider than an octave: from the highest down
        assertEquals(Roll.ROWS - 1, Roll.topFor(listOf(0)))                  // never above the lowest twelve
    }

    @Test fun blackAndWhiteKeys() {
        assertTrue(Roll.isBlack(61)); assertTrue(Roll.isBlack(70)); assertFalse(Roll.isBlack(60)); assertFalse(Roll.isBlack(71)); assertTrue(Roll.isC(48))
    }

    @Test fun aTouchFindsItsStepAndPitch() {
        val row = 24f; val step = 50f
        val sy = Roll.scrollYFor(71, row)                                    // B4 in the first row
        assertEquals(71, Roll.pitchAt(3f, sy, row)); assertEquals(60, Roll.pitchAt(11 * row + 1f, sy, row))
        assertEquals(0, Roll.stepAt(10f, 0f, step)); assertEquals(15, Roll.stepAt(799f, 0f, step)); assertEquals(6, Roll.stepAt(10f, 300f, step))
        assertEquals(15, Roll.stepAt(5000f, 0f, step))                       // past the end: the last step
    }

    @Test fun whatATapDoes() {
        // an empty cell, Chord off: the step plays that note (replacing its own); Chord on: it is added, up to four
        assertEquals(Roll.Tap.Set, Roll.tap(listOf(60), 64, picked = false, chord = false, maxNotes = 4))
        assertEquals(Roll.Tap.Add, Roll.tap(listOf(60), 64, picked = true, chord = true, maxNotes = 4))
        assertEquals(Roll.Tap.Full, Roll.tap(listOf(60, 64, 67, 70), 72, picked = true, chord = true, maxNotes = 4))
        // a note: the first tap only picks its step; on the picked step it takes the note off
        assertEquals(Roll.Tap.Pick, Roll.tap(listOf(60), 60, picked = false, chord = false, maxNotes = 4))
        assertEquals(Roll.Tap.Remove, Roll.tap(listOf(60), 60, picked = true, chord = true, maxNotes = 4))
    }

    @Test fun theStepsKeepTheirWidthAndScrollUnderADockedPanel() {
        val step = 50f; val view = 800f; val dock = 360f                     // 16 steps of 50; the panel covers the right 360
        assertEquals(0f, Roll.clampScrollX(120f, 0f), 0f)                    // no panel: nothing to scroll
        assertEquals(360f, Roll.clampScrollX(999f, dock), 0f)                // with it: by its width, so step 16 comes clear
        assertEquals(0f, Roll.reveal(3, 0f, step, view, dock), 0f)           // step 4 is in view beside it: nothing moves
        assertEquals(210f, Roll.reveal(12, 0f, step, view, dock), 0f)        // step 13 is under it: it comes just clear (650 − 440)
        assertEquals(360f, Roll.reveal(15, 0f, step, view, dock), 0f)
        assertEquals(100f, Roll.reveal(2, 360f, step, view, dock), 0f)       // scrolled right, step 3 off the left: back to it
        val (a, b) = Roll.indicator(0f, step, view, dock)
        assertEquals(0f, a, 0f); assertEquals(0.55f, b, 0.001f)              // 440 of 800 in view: 8.8 steps of 16
    }

    @Test fun theRowsInViewForAScroll() {
        val r = Roll.visiblePitches(Roll.scrollYFor(71, 24f), 24f, 288f)
        assertTrue(71 in r && 60 in r); assertTrue(r.first >= 59 && r.last <= 72)
    }
}
