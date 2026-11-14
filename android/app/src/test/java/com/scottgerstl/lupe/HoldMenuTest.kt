package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import com.scottgerstl.lupe.ui.shell.HoldItem
import com.scottgerstl.lupe.ui.shell.HoldMenuState
import com.scottgerstl.lupe.ui.shell.holdSpots
import com.scottgerstl.lupe.ui.shell.hubScale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.hypot

/** The hold menu (design/boards/radial-menu.html): where the choices sit, how the circle grows, how a choice is picked. */
class HoldMenuTest {
    @Test fun theChoicesSitOnACircleRoundTheFingerOneAboveAnother() {
        val s = holdSpots(300f, 200f, 5, 915f, 412f)
        assertEquals(5, s.size)
        s.zipWithNext().forEach { (a, b) -> assertEquals(56f, b.cy - a.cy, 0.01f) }        // stacked 56 dp apart
        s.forEach { assertFalse(it.left); assertEquals(120f, hypot(it.edgeX - 300f, it.cy - 200f), 0.5f) }   // each where its height meets the 120 dp circle
        assertEquals(200f, s[2].cy, 0.01f)                                                    // centred on the finger's height
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

    @Test fun aSecondSetOfChoicesOpensInPlaceAndALongListGoesBehindMore() {
        val m = HoldMenuState()
        m.open(Offset.Zero, Color.Red, listOf(HoldItem("Set pattern…", children = { (1..9).map { HoldItem("Pattern %02d".format(it)) } })))
        m.pick(0)
        assertEquals(6, m.menu!!.items.size)
        assertEquals("More…", m.menu!!.items.last().title)
        m.pick(5)
        assertEquals(listOf("Pattern 06", "Pattern 07", "Pattern 08", "Pattern 09"), m.menu!!.items.map { it.title })
        assertTrue(abs(1) == 1)
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
