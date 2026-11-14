package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import com.scottgerstl.lupe.ui.shell.HoldItem
import com.scottgerstl.lupe.ui.shell.HoldMenuState
import com.scottgerstl.lupe.ui.shell.HoldWheel
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
    private fun wheel(n: Int, x: Float = 300f, y: Float = 200f) = HoldWheel(x, y, n, 915f, 412f)

    @Test fun everyStalkIsTheSameShortLength() {
        val w = wheel(5)
        assertEquals(22f, STALK, 0f)
        (0 until 5).forEach { k -> val s = w.spot(k, 0f); assertEquals(HUB_R + STALK, hypot(s.tipX - 300f, s.tipY - 200f), 0.01f); assertEquals(1f, s.alpha, 0f) }
        // …and while the wheel turns, too
        listOf(-1.6f, -0.3f, 0.5f, 1.25f, 2.4f).forEach { u -> val s = w.spot(u); assertEquals(HUB_R + STALK, hypot(s.tipX - 300f, s.tipY - 200f), 0.01f) }
    }

    @Test fun fiveRowsSitRoundTheCircleEachMeetingItsStalk() {
        val w = wheel(5)
        val rows = (0 until 5).map { w.spot(it, 0f) }
        rows.zipWithNext().forEach { (a, b) -> assertEquals(36f, b.rowY - a.rowY, 0.01f) }      // stacked, touching
        assertEquals(200f - 18f, rows[2].rowY, 0.01f)                                            // the middle one level with the finger
        rows.forEach { s ->
            // the stalk's end is on the row's edge (within a pixel or so)
            val dx = maxOf(s.rowX - s.tipX, 0f, s.tipX - (s.rowX + 200f)); val dy = maxOf(s.rowY - s.tipY, 0f, s.tipY - (s.rowY + 36f))
            assertTrue("stalk end off its row by $dx, $dy", hypot(dx, dy) <= 1.5f)
            // no row touches the circle
            val nx = (300f).coerceIn(s.rowX, s.rowX + 200f); val ny = (200f).coerceIn(s.rowY, s.rowY + 36f)
            assertTrue(hypot(nx - 300f, ny - 200f) >= HUB_R)
        }
    }

    @Test fun itOpensWithTheFirstChoiceAtTheTopAndTurnsToTheRest() {
        val w = wheel(9)
        assertEquals(5, w.count); assertEquals(4f, w.maxTurn, 0f)
        assertEquals(-2f, w.slot(0), 0f)                         // the first choice at the arc's top
        assertEquals(1f, w.spot(4, 0f).alpha, 0f); assertEquals(0f, w.spot(5, 0f).alpha, 0f)
        // turned all the way, the last five are on the arc and the first has rolled off
        assertEquals(2f, w.slot(8, w.maxTurn), 0f); assertEquals(0f, w.spot(0, w.maxTurn).alpha, 0f)
        // half way between two choices, the ones at the ends are fading
        val half = w.spot(0, 0.5f).alpha
        assertTrue(half > 0f && half < 1f)
    }

    @Test fun fiveOrFewerIsJustTheArc() {
        assertEquals(0f, wheel(5).maxTurn, 0f)
        val three = wheel(3)
        assertEquals(0f, three.maxTurn, 0f)
        assertEquals(listOf(-1f, 0f, 1f), (0 until 3).map { three.slot(it) })      // centred on the finger
    }

    @Test fun itStaysBelowTheHeaderAndOnTheScreen() {
        val high = HoldWheel(300f, 90f, 9, 915f, 412f)                               // a finger just under the header
        assertTrue(high.firstSlot > -2); assertTrue(high.count < 5); assertTrue(high.maxTurn > 4f)
        (0 until 9).map { high.spot(it, 0f) }.filter { it.alpha > 0f }.forEach { assertTrue(it.rowY >= 60f - 36f * 0.75f - 0.01f) }
        assertTrue(high.spot(0, 0f).rowY >= 60f)                                    // what is wholly shown is below the header
        val low = HoldWheel(300f, 370f, 9, 915f, 412f)
        assertTrue(low.lastSlot < 2)
        assertTrue(low.spot(low.count - 1, 0f).rowY + 36f <= 412f - 16f + 0.01f)
    }

    @Test fun itFlipsSideNearTheRightEdgeAndForARightHandedHold() {
        assertFalse(wheel(5).left)
        assertTrue(HoldWheel(880f, 200f, 5, 915f, 412f).left)
        val l = HoldWheel(600f, 200f, 5, 915f, 412f, preferLeft = true)
        assertTrue(l.left); assertTrue(l.spot(2, 0f).rowX + 200f <= 600f - 54f + 0.01f)
        assertFalse(HoldWheel(100f, 200f, 5, 915f, 412f, preferLeft = true).left)   // no room on the left: it opens right
    }

    @Test fun aHeldFingerPastTheArcsEndTurnsTheWheel() {
        val w = wheel(9)
        assertTrue(w.pull(200f + 3.2f * 36f, 0f) > 0f)                // below the last choice, more to come
        assertEquals(0f, w.pull(200f + 3.2f * 36f, w.maxTurn), 0f)     // nothing more that way
        assertEquals(0f, w.pull(200f - 3.2f * 36f, 0f), 0f)            // above the first with nothing before it
        assertTrue(w.pull(200f - 3.2f * 36f, 2f) < 0f)
        assertEquals(0f, w.pull(200f, 2f), 0f)                         // on the arc: no pull
        assertEquals(0f, wheel(4).pull(400f, 0f), 0f)                  // nothing to turn
    }

    @Test fun theCircleGoesPastItsSizeUndershootsOnceAndSettles() {
        assertEquals(0f, hubScale(0f, 0.6f), 0.001f)
        assertEquals(1f + 0.35f * 0.6f, hubScale(0.45f, 0.6f), 0.001f)        // past its size
        assertEquals(1f - 0.1f * 0.6f, hubScale(0.75f, 0.6f), 0.001f)         // one undershoot
        assertEquals(1f, hubScale(1f, 0.6f), 0.001f)
        assertTrue((1..99).all { hubScale(it / 100f, 0f) <= 1f })              // Spring 0: a plain ease-out, never past
    }

    @Test fun aDragThatEndsOffAChoicePicksNothing() {
        // the iPhone's fault (a drag that began on Clear and ended elsewhere cleared the pad): only the choice under the finger at the lift is picked
        var cleared = false
        val m = HoldMenuState()
        m.open(Offset(100f, 100f), Color.Red, listOf(HoldItem("Edit steps"), HoldItem("Clear") { cleared = true }))
        m.rects = listOf(Rect(200f, 50f, 400f, 98f), Rect(200f, 106f, 400f, 154f))
        m.drag(Offset(250f, 120f)); assertEquals(1, m.hot)          // on Clear…
        m.drag(Offset(600f, 300f)); assertEquals(-1, m.hot)         // …then off every choice
        m.release()
        assertFalse(cleared); assertTrue(m.menu != null)
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
