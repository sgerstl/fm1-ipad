package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import com.scottgerstl.lupe.ui.shell.HoldItem
import com.scottgerstl.lupe.ui.shell.HoldMenuState
import com.scottgerstl.lupe.ui.shell.holdSpots
import com.scottgerstl.lupe.ui.shell.HoldLayout
import com.scottgerstl.lupe.ui.shell.HUB_R
import com.scottgerstl.lupe.ui.shell.STALK
import com.scottgerstl.lupe.ui.shell.hubScale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

/** The hold menu (design/boards/radial-menu.html): where the choices sit, how the circle grows, how a choice is picked. */
class HoldMenuTest {
    @Test fun theChoicesHugTheCircleOnShortStalks() {
        val s = holdSpots(300f, 200f, 5, 915f, 412f)
        assertEquals(5, s.size)
        s.zipWithNext().forEach { (a, b) -> assertEquals(56f, b.cy - a.cy, 0.01f) }        // stacked 56 dp apart
        assertEquals(200f, s[2].cy, 0.01f)                                                    // centred on the finger's height
        // the one level with the finger sits a stalk (22 dp) past the 32 dp circle's edge; the first stalks were 88
        assertEquals(HUB_R + STALK, s[2].edgeX - 300f, 0.01f); assertEquals(22f, STALK, 0f)
        // its neighbours' stalks are short too, and no choice touches the circle
        listOf(s[1], s[3]).forEach { assertTrue(hypot(it.edgeX - 300f, it.cy - 200f) - HUB_R < 30f) }
        s.forEach { val nearestY = (200f).coerceIn(it.cy - 24f, it.cy + 24f); assertTrue(hypot(it.edgeX - 300f, nearestY - 200f) >= HUB_R) }
    }

    @Test fun aColumnTallerThanTheScreenScrollsInsteadOfPaging() {
        val l = HoldLayout.of(300f, 200f, 12, 915f, 412f)
        assertTrue(l.maxScroll > 0f)
        assertEquals(0f, HoldLayout.of(300f, 200f, 5, 915f, 412f).maxScroll, 0f)              // five fit: nothing scrolls
        // scrolled to the end the last choice is wholly in view, and the first has gone
        val last = l.spot(11, l.maxScroll)
        assertEquals(l.viewBottom, last.cy + 24f, 0.01f)
        assertEquals(1f, l.shown(last.cy, l.maxScroll), 0f)
        assertEquals(0f, l.shown(l.spot(0, l.maxScroll).cy, l.maxScroll), 0f)
        // at the top the choice half past the foot is half faded; with nothing beyond an edge nothing fades there
        assertEquals(0.5f, l.shown(l.viewBottom, 0f), 0.01f)
        assertEquals(1f, l.shown(l.spot(0).cy, 0f), 0f)
        // the choices slide along the arc as they scroll: one level with the finger is the furthest out
        assertTrue(l.spot(3, 0f).edgeX != l.spot(3, 40f).edgeX || l.spot(4, 0f).edgeX != l.spot(4, 40f).edgeX)
    }

    @Test fun aHeldFingerAtAnEdgeWithMoreBeyondPullsTheColumn() {
        val l = HoldLayout.of(300f, 200f, 12, 915f, 412f)
        assertTrue(l.pull(l.viewBottom - 5f, 0f) > 0f)                // at the foot, more below: scrolls on
        assertEquals(0f, l.pull(l.viewBottom - 5f, l.maxScroll), 0f)   // nothing more below
        assertEquals(0f, l.pull(l.viewTop + 5f, 0f), 0f)               // at the top with nothing above
        assertTrue(l.pull(l.viewTop + 5f, 30f) < 0f)
        assertEquals(0f, l.pull(200f, 30f), 0f)                        // in the middle: no pull
    }

    @Test fun nearTheRightEdgeTheyOpenToTheLeftAndTheyStayOnTheScreen() {
        val right = holdSpots(880f, 200f, 3, 915f, 412f)
        assertTrue(right.all { it.left && it.edgeX < 880f })
        val low = holdSpots(300f, 400f, 5, 915f, 412f)                                        // a finger at the foot of the screen
        assertTrue(low.last().cy + 24f <= 412f - 16f + 0.01f)
        val high = holdSpots(300f, 4f, 5, 915f, 412f)
        assertTrue(high.first().cy - 24f >= 8f - 0.01f)
    }

    @Test fun theCircleGoesPastItsSizeUndershootsOnceAndSettles() {
        assertEquals(0f, hubScale(0f, 0.6f), 0.001f)
        assertEquals(1f + 0.35f * 0.6f, hubScale(0.45f, 0.6f), 0.001f)        // past its size
        assertEquals(1f - 0.1f * 0.6f, hubScale(0.75f, 0.6f), 0.001f)         // one undershoot
        assertEquals(1f, hubScale(1f, 0.6f), 0.001f)
        assertTrue((1..99).all { hubScale(it / 100f, 0f) <= 1f })              // Spring 0: a plain ease-out, never past
    }

    @Test fun aLetGoOnALitChoicePicksItAndOnNothingLeavesTheMenuOpen() {
        var picked = ""
        val m = HoldMenuState()
        m.open(Offset(100f, 100f), Color.Red, listOf(HoldItem("Edit steps") { picked = "edit" }, HoldItem("Clear") { picked = "clear" }))
        m.rects = listOf(Rect(200f, 50f, 400f, 98f), Rect(200f, 106f, 400f, 154f))
        m.release(); assertTrue(m.menu != null); assertEquals("", picked)      // let go on nothing: stays for a tap
        m.drag(Offset(250f, 60f)); assertEquals(0, m.hot)
        m.drag(Offset(10f, 10f)); assertEquals(-1, m.hot)
        m.drag(Offset(250f, 120f)); m.release()
        assertEquals("clear", picked); assertNull(m.menu)
    }

    @Test fun aChoiceThatLosesSomethingAsksAgainInPlaceAndIgnoresAQuickSecondTap() {
        var cleared = false
        val m = HoldMenuState()
        m.open(Offset.Zero, Color.Red, listOf(HoldItem("Clear", confirm = "Clear B: erases pattern 62") { cleared = true }))
        m.pick(0); assertEquals(0, m.confirming); assertFalse(cleared)
        m.pick(0); assertFalse(cleared)                                        // inside 0.4 s: ignored
        m.confirmAt -= 500
        m.pick(0); assertTrue(cleared); assertNull(m.menu)
    }

    @Test fun aSecondSetOfChoicesOpensInPlaceAndALongListIsOneMenu() {
        val m = HoldMenuState()
        m.open(Offset.Zero, Color.Red, listOf(HoldItem("Set pattern…", children = { (1..9).map { HoldItem("Pattern %02d".format(it)) } })))
        m.pick(0)
        assertEquals(9, m.menu!!.items.size)                                   // all nine: no "More…" (decision 36)
        assertFalse(m.menu!!.items.any { it.title == "More…" })
        val seven = (1..7).map { HoldItem("Choice $it") }
        m.open(Offset.Zero, Color.Red, seven); assertEquals(7, m.menu!!.items.size)
    }

    @Test fun aDisabledChoiceNeitherLightsNorPicks() {
        var done = false
        val m = HoldMenuState()
        m.open(Offset.Zero, Color.Red, listOf(HoldItem("Set pattern…", enabled = false) { done = true }))
        m.rects = listOf(Rect(0f, 0f, 100f, 48f))
        m.drag(Offset(10f, 10f)); assertEquals(-1, m.hot)
        m.pick(0); assertFalse(done)
    }
}
