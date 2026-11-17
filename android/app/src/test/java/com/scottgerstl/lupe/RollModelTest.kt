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
        assertEquals(0f, Roll.clampScrollX(120f, Roll.maxScroll(16, view, 0f)), 0f)     // no panel, one chunk: nothing to scroll
        assertEquals(360f, Roll.clampScrollX(999f, Roll.maxScroll(16, view, dock)), 0f) // with it: by its width, so step 16 comes clear
        assertEquals(0f, Roll.reveal(3, 0f, step, view, dock, 16), 0f)       // step 4 is in view beside it: nothing moves
        assertEquals(360f, Roll.reveal(12, 0f, step, view, dock, 16), 0f)    // step 13 is under it: the grid settles where the last steps come clear
        assertEquals(360f, Roll.reveal(15, 0f, step, view, dock, 16), 0f)
        assertEquals(0f, Roll.reveal(2, 360f, step, view, dock, 16), 0f)     // scrolled right, step 3 off the left: back to the chunk's start
        val (a, b) = Roll.indicator(0f, step, view, dock, 16)
        assertEquals(0f, a, 0f); assertEquals(0.55f, b, 0.001f)              // 440 of 800 in view: 8.8 steps of 16
    }

    @Test fun aLongPatternIsChunksOfSixteenAndTheGridSnapsToThem() {
        val step = 50f; val view = 800f                                      // a chunk is 800 px
        assertEquals(1, Roll.chunks(16)); assertEquals(2, Roll.chunks(17)); assertEquals(4, Roll.chunks(64)); assertEquals(1, Roll.chunks(0))
        assertEquals(2400f, Roll.maxScroll(64, view, 0f), 0f)                // to the fourth chunk's start
        assertEquals(800f, Roll.maxScroll(20, view, 0f), 0f)                 // 20 steps: the second chunk holds four
        assertEquals(800f, Roll.snap(500f, 64, view, 0f), 0f)                // let go past the middle: the next chunk
        assertEquals(0f, Roll.snap(300f, 64, view, 0f), 0f)                  // before it: back
        assertEquals(2400f, Roll.snap(9999f, 64, view, 0f), 0f)              // never past the last chunk
        // with a panel docked a chunk has two places: its start and its start plus the dock
        assertEquals(1160f, Roll.snap(1100f, 64, view, 360f), 0f)
        assertEquals(800f, Roll.snap(900f, 64, view, 360f), 0f)
        // a step in another chunk: its chunk's start, else (under the panel) that plus the dock
        assertEquals(800f, Roll.reveal(17, 0f, step, view, 0f, 64), 0f)
        assertEquals(1160f, Roll.reveal(28, 0f, step, view, 360f, 64), 0f)
        assertEquals(2400f, Roll.reveal(48, 0f, step, view, 0f, 64), 0f)
        assertEquals(16, Roll.stepAt(10f, 800f, step, 64)); assertEquals(63, Roll.stepAt(5000f, 2400f, step, 64)); assertEquals(19, Roll.stepAt(5000f, 800f, step, 20))
    }

    @Test fun whilePlayingTheViewPagesToThePlayheadsChunk() {
        val step = 50f; val view = 800f
        assertEquals(null, Roll.follow(5, 0f, step, view, 0f, 64))           // in view: nothing moves
        assertEquals(800f, Roll.follow(17, 0f, step, view, 0f, 64)!!, 0f)    // the second chunk
        assertEquals(0f, Roll.follow(0, 2400f, step, view, 0f, 64)!!, 0f)    // the song starts again: back to the first
        assertEquals(null, Roll.follow(-1, 0f, step, view, 0f, 64))          // stopped
        assertEquals(1160f, Roll.follow(28, 800f, step, view, 360f, 64)!!, 0f)   // under a docked panel: where its last steps come clear
    }

    @Test fun theIndicatorSpansTheWholePattern() {
        val (a, b) = Roll.indicator(800f, 50f, 800f, 0f, 64)
        assertEquals(0.25f, a, 0.001f); assertEquals(0.5f, b, 0.001f)       // the second of four chunks
    }

    @Test fun theRowsInViewForAScroll() {
        val r = Roll.visiblePitches(Roll.scrollYFor(71, 24f), 24f, 288f)
        assertTrue(71 in r && 60 in r); assertTrue(r.first >= 59 && r.last <= 72)
    }

    /** Hybrid UI (Scott, 2026-11-17): with a panel docked a melodic grid pages by 8, and follows the playhead only with Follow on. */
    @Test fun eightStepPagesBesideADockedPanel() {
        val view = 480f; val step = view / Roll.PAGE_DOCKED
        assertEquals(2, Roll.chunks(16, Roll.PAGE_DOCKED)); assertEquals(8, Roll.chunks(64, Roll.PAGE_DOCKED))
        assertEquals(480f, Roll.maxScroll(16, view, 0f, Roll.PAGE_DOCKED), 0f)        // one page to the right
        assertEquals(0f, Roll.snap(200f, 16, view, 0f, Roll.PAGE_DOCKED), 0f)          // under half a page: back
        assertEquals(480f, Roll.snap(260f, 16, view, 0f, Roll.PAGE_DOCKED), 0f)        // over: on to 9–16
        assertEquals(480f, Roll.follow(8, 0f, step, view, 0f, 16, Roll.PAGE_DOCKED)!!, 0f)   // step 9 plays: page 2
        assertEquals(null, Roll.follow(3, 0f, step, view, 0f, 16, Roll.PAGE_DOCKED))  // step 4 is in view: nothing moves
        assertEquals(1, Roll.pageOf(9, Roll.PAGE_DOCKED))
        // Follow gates 8-step pages; 16-step chunks follow unless a finger moved them a moment ago (as built)
        assertTrue(Roll.pagesFollow(8, follow = true, recentlyTouched = true))
        assertFalse(Roll.pagesFollow(8, follow = false, recentlyTouched = false))
        assertTrue(Roll.pagesFollow(16, follow = false, recentlyTouched = false))
        assertFalse(Roll.pagesFollow(16, follow = true, recentlyTouched = true))
        // the minimap shows the bar of 16 holding the page, and its label
        assertEquals(0, Roll.minimapStart(1, 8)); assertEquals(16, Roll.minimapStart(2, 8)); assertEquals(16, Roll.minimapStart(3, 8))
        assertEquals("1\u20138", Roll.pageLabel(0, 8, 16)); assertEquals("9\u201312", Roll.pageLabel(1, 8, 12))
    }

    /** Round 7 (Scott: "you really have to drag it all the way over"): a fling or a fifth of the page turns it. */
    @Test fun aShortDragOrAFlingTurnsThePage() {
        val page = 480f; val fling = 1000f
        assertEquals(0f, Roll.pageTarget(0f, 80f, 0f, page, 16, 8, fling), 0f)            // a sixth: back
        assertEquals(480f, Roll.pageTarget(0f, 100f, 0f, page, 16, 8, fling), 0f)         // past a fifth: on
        assertEquals(480f, Roll.pageTarget(0f, 20f, -1200f, page, 16, 8, fling), 0f)      // a quick fling leftward: on, however short
        assertEquals(0f, Roll.pageTarget(480f, 470f, 1500f, page, 16, 8, fling), 0f)      // flung rightward from page 2: back to 1
        assertEquals(480f, Roll.pageTarget(480f, 700f, -2000f, page, 16, 8, fling), 0f)   // never past the last page
        assertEquals(0f, Roll.pageTarget(0f, -150f, 2000f, page, 16, 8, fling), 0f)       // nor before the first
    }
}
