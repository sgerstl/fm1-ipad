package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.timeline.BARS_MAX
import com.scottgerstl.lupe.ui.timeline.BARS_MIN
import com.scottgerstl.lupe.ui.timeline.BARS_START
import com.scottgerstl.lupe.ui.timeline.BlockUi
import com.scottgerstl.lupe.ui.timeline.TrackDrag
import com.scottgerstl.lupe.ui.timeline.clampBarPx
import com.scottgerstl.lupe.ui.timeline.clampScroll
import com.scottgerstl.lupe.ui.timeline.contentBars
import com.scottgerstl.lupe.ui.timeline.edgePan
import com.scottgerstl.lupe.ui.timeline.followScroll
import com.scottgerstl.lupe.ui.timeline.placesFor
import com.scottgerstl.lupe.ui.timeline.repsFor
import com.scottgerstl.lupe.ui.timeline.rulerStep
import com.scottgerstl.lupe.ui.timeline.zoomAbout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The landscape Timeline's view: zoom limits, the pan's ends, the ruler's numbering, following the playhead, and a drag read at its end. */
class TimelineViewTest {
    private val lane = 839f          // the Pixel 10 Pro's lanes: 915 − 72 − 4 dp, at 1 px a dp

    @Test fun twelveBarsToBeginWithAndEightToSixteenByZoom() {
        assertEquals(lane / BARS_START, clampBarPx(0f, lane), 0.001f)
        assertEquals(lane / BARS_MIN, clampBarPx(10_000f, lane), 0.001f)       // zoomed in: 8 bars across
        assertEquals(lane / BARS_MAX, clampBarPx(1f, lane), 0.001f)            // zoomed out: 16
    }

    @Test fun theSongEndsWithRoomToAddAndNeverLeavesTheViewEmpty() {
        val bar = lane / 12
        assertEquals(24, contentBars(20, bar, lane))                           // four empty bars after the song
        assertEquals(12, contentBars(2, bar, lane))                            // a short song still fills the lanes
        assertEquals(0f, clampScroll(-50f, 24 * bar, lane), 0.001f)
        assertEquals(24 * bar - lane, clampScroll(99_999f, 24 * bar, lane), 0.01f)
        assertEquals(0f, clampScroll(300f, 10 * bar, lane), 0.001f)            // nothing to pan when it all fits
    }

    @Test fun aPinchKeepsTheBarUnderTheFingers() {
        val bar = lane / 12; val scroll = 3 * bar; val focus = 2 * bar          // the fingers are over bar 5's start
        val wider = lane / 8
        val s2 = zoomAbout(scroll, bar, wider, focus)
        assertEquals(5.0f, (s2 + focus) / wider, 0.001f)
    }

    @Test fun theRulerNumbersEveryBarWhileTheyFit() {
        assertEquals(1, rulerStep(104f)); assertEquals(1, rulerStep(52f)); assertEquals(2, rulerStep(30f)); assertEquals(4, rulerStep(18f))
    }

    @Test fun theViewPagesWhenThePlayheadLeaves() {
        val bar = lane / 12
        assertNull(followScroll(3.0, 0f, bar, lane))                           // in view: nothing moves
        val s = followScroll(11.5, 0f, bar, lane)!!                             // past nine tenths: a page turn
        assertEquals(11.5f * bar - lane * 0.1f, s, 0.01f)
        assertEquals(0f, followScroll(0.0, 400f, bar, lane)!!, 0.001f)         // the song starts again: back to the start
    }

    @Test fun aBlockDraggedToAnEndPansTheSong() {
        assertEquals(10f, edgePan(830f, lane, 36f, 10f), 0f); assertEquals(-10f, edgePan(5f, lane, 36f, 10f), 0f); assertEquals(0f, edgePan(400f, lane, 36f, 10f), 0f)
    }

    /** The fault portrait had: a drag's end must send what the finger did by then. The drag is state, read when it ends. */
    @Test fun aDragIsReadAtItsEnd() {
        val t = listOf(BlockUi(1, 0, 1, 0f, 1f, 1f, 1, 5, false, false), BlockUi(1, 1, 1, 1f, 4f, 1f, 4, 7, false, false), BlockUi(1, 2, 1, 5f, 2f, 1f, 2, 9, false, false))
        val bar = 70f
        val d = TrackDrag()
        d.start(t[1], false, bar)                                            // the body, held
        assertEquals(0, placesFor(t, 1, d.offsetBars))                        // (what an end handler that captured the start would send: nothing)
        d.accPx += 2.2f * bar                                                // the finger moves right, two bars and a bit
        assertEquals(1, placesFor(t, 1, d.offsetBars))                        // read at the end: one place later
        d.end()
        d.start(t[1], true, bar)                                             // the grip at its right end
        d.accPx += 2.4f * bar
        assertEquals(6, repsFor(t[1], d.offsetBars))                          // 4 passes and two more
        d.accPx -= 6f * bar
        assertEquals(1, repsFor(t[1], d.offsetBars))                          // dragged left past its start: one pass, never none
    }
}
