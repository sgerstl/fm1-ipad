package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.timeline.BlockUi
import com.scottgerstl.lupe.ui.timeline.TrackDrag
import com.scottgerstl.lupe.ui.timeline.placesFor
import com.scottgerstl.lupe.ui.timeline.repsFor
import com.scottgerstl.lupe.ui.timeline.siblingShift
import org.junit.Assert.assertEquals
import org.junit.Test

/** The Timeline's drag maths: where a dragged block lands, what its foot sets, and how its neighbours make room. */
class TimelineDragTest {
    // one track: block 0 (1 bar, from 0), block 1 (4 bars, from 1), block 2 (2 bars, from 5)
    private val t = listOf(
        BlockUi(1, 0, 1, 0f, 1f, 1f, 1, 5, false, false), BlockUi(1, 1, 1, 1f, 4f, 1f, 4, 7, false, false), BlockUi(1, 2, 1, 5f, 2f, 1f, 2, 9, false, false),
    )

    @Test fun aBlockLandsInTheNearestSlot() {
        assertEquals(0, placesFor(t, 1, 0.5f))          // a little: it stays
        assertEquals(1, placesFor(t, 1, 2.0f))          // past the next one's middle: one place later
        assertEquals(-1, placesFor(t, 1, -1.5f))        // up past the first: one place earlier
        assertEquals(2, placesFor(t, 0, 7f))            // all the way down
    }

    @Test fun theFootSetsWholePasses() {
        assertEquals(6, repsFor(t[1], 2.2f)); assertEquals(1, repsFor(t[1], -10f)); assertEquals(16, repsFor(t[1], 40f))
        assertEquals(4, repsFor(t[1], 0.4f))
    }

    @Test fun stretchingMakesTheBlocksBelowMakeRoom() {
        // block 1 stretched from 4 to 6 passes: block 2 (after it) moves down 2 bars, block 0 (before it) not at all
        assertEquals(2f, siblingShift(t[2], t, t[1], true, 2f), 0.001f)
        assertEquals(0f, siblingShift(t[0], t, t[1], true, 2f), 0.001f)
        assertEquals(-2f, siblingShift(t[2], t, t[1], true, -2f), 0.001f)     // shortened: it moves up
    }

    @Test fun movingOpensAGapAtTheLandingSlot() {
        // block 1 dragged a place later: block 2 slides up by block 1's length (4); block 0 doesn't move
        assertEquals(-4f, siblingShift(t[2], t, t[1], false, 3.5f), 0.001f)
        assertEquals(0f, siblingShift(t[0], t, t[1], false, 3.5f), 0.001f)
        // dragged a place earlier: block 0 slides down by 4
        assertEquals(4f, siblingShift(t[0], t, t[1], false, -1.5f), 0.001f)
        assertEquals(0f, siblingShift(t[2], t, t[1], false, -1.5f), 0.001f)
    }

    @Test fun theEndOfADragReadsWhatTheFingerDidThen() {
        // the fault: an end handler that captured the numbers when the gesture began saw no movement. Reading the drag's state at the end sees it.
        val d = TrackDrag()
        d.start(t[1], resize = true, px = 36f)
        val seenAtStart = repsFor(t[1], d.offsetBars)                 // 4: nothing moved yet
        d.accPx += 72f                                                // the finger moved two bars
        assertEquals(4, seenAtStart); assertEquals(6, repsFor(t[1], d.offsetBars))
        d.end(); assertEquals(false, d.active)
    }
}
