package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import com.scottgerstl.lupe.ui.shell.HoldItem
import com.scottgerstl.lupe.ui.shell.HoldMenuState
import com.scottgerstl.lupe.ui.shell.HoldWheel
import com.scottgerstl.lupe.ui.shell.hubScale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

/** The hold menu (design/boards/radial-menu.html): where the choices sit, how the circle grows, how a choice is picked. */
class HoldMenuTest {
    private fun wheel(n: Int, x: Float = 500f, y: Float = 200f, leftHanded: Boolean = true) = HoldWheel(x, y, n, 915f, 412f, leftHanded)

    /** The iPhone's final numbers (ios/FM1/RadialMenu.swift at 4386982): a 400 curve whose middle is 76 from the finger, a 22 stalk in to a rim at 378. */
    @Test fun theChoicesNearEdgesAreOnTheShallowCurveAndEveryStalkIs22() {
        val w = wheel(5)                                                    // left-handed here: it opens to the right
        assertFalse(w.left); assertEquals(200f, w.mid, 0.01f)
        assertEquals(500f + 76f - 400f, w.centreX, 0.01f)
        val spots = (0 until 5).map { w.spot(it, 0f) }
        spots.zipWithNext().forEach { (a, b) -> assertEquals(56f, b.rowY - a.rowY, 0.01f) }           // centres 56 apart
        assertEquals(200f - 24f, spots[2].rowY, 0.01f)                                                // the middle one level with the curve's middle
        spots.forEach { s ->
            assertEquals(400f, hypot(s.nodeX - w.centreX, s.nodeY - 200f), 0.01f)                     // its node on the 400 curve
            assertEquals(22f, hypot(s.nodeX - s.stalkX, s.nodeY - s.stalkY), 0.01f)                   // its stalk exactly 22
            assertEquals(378f, hypot(s.stalkX - w.centreX, s.stalkY - 200f), 0.01f)                   // starting on the rim
            assertEquals(s.nodeX, s.rowX, 0.01f); assertEquals(1f, s.alpha, 0f)
        }
        assertEquals(76f, spots[2].nodeX - 500f, 0.01f)                                               // the middle one 76 from the finger
        assertEquals(16f, spots[2].nodeX - spots[0].nodeX, 0.5f)                                      // the ends come in about 16: nearly a column
    }

    @Test fun theRimRunsFromTheTopChoiceToTheBottomOneAndTheTrianglesSayThereIsMore() {
        val w = wheel(9, y = 220f)        // (a height where the column fits without moving)
        assertEquals(220f, w.mid, 0.01f)
        assertEquals(136f, w.reachY, 0.01f)                                 // 2 × 56 + 24
        assertEquals(Math.toDegrees(kotlin.math.asin(136.0 / 378.0)), w.rimHalfSweep.toDouble(), 0.01)
        // the triangles: on the rim's curve, 8 past its ends
        val (ux, uy) = w.triangle(up = true); val (dx, dy) = w.triangle(up = false)
        assertEquals(220f - 144f, uy, 0.01f); assertEquals(220f + 144f, dy, 0.01f); assertEquals(ux, dx, 0.01f)
        assertEquals(378f, hypot(ux - w.centreX, uy - 220f), 0.01f)
        // opened on the first choice: nothing above, more below; at the end the other way round; each blends over half a choice
        assertEquals(0f, w.moreAbove(0f), 0f); assertEquals(1f, w.moreBelow(0f), 0f)
        assertEquals(0.5f, w.moreAbove(0.25f), 0.001f)
        assertEquals(1f, w.moreAbove(4f), 0f); assertEquals(0f, w.moreBelow(4f), 0f); assertEquals(0.5f, w.moreBelow(3.75f), 0.001f)
        // five or fewer: none
        assertEquals(0f, wheel(5).moreBelow(0f), 0f); assertEquals(0f, wheel(5).moreAbove(0f), 0f)
    }

    @Test fun moreThanFiveIsAWheelThatOpensWithTheFirstAtTheTop() {
        val w = wheel(9)
        assertEquals(5, w.shown); assertEquals(4f, w.maxTurn, 0f)
        assertEquals(-2f, w.position(0), 0f)                                // the first choice at the arc's top
        assertEquals(1f, w.spot(4, 0f).alpha, 0f)
        assertEquals(0f, w.spot(5, 0f).alpha, 0.001f)                       // p = 3: a whole place past the end, gone (0.8 fades it out)
        // half a choice past the end: 1 − 0.5/0.8
        assertEquals(1f - 0.5f / 0.8f, w.spot(-2.5f).alpha, 0.001f)
        // turned all the way, the last is at the foot
        assertEquals(2f, w.position(8, w.maxTurn), 0f)
    }

    @Test fun fiveOrFewerIsJustTheArcWithNoFade() {
        assertEquals(0f, wheel(5).maxTurn, 0f)
        val three = wheel(3)
        assertEquals(listOf(-1f, 0f, 1f), (0 until 3).map { three.position(it) })
        assertEquals(1f, three.spot(-3f).alpha, 0f)                         // no fade when nothing turns
    }

    @Test fun aDragGivesPastTheEndsAndSettlesOnAWholeChoiceInside() {
        val w = wheel(9)
        assertEquals(-0.35f, w.give(-1f), 0.001f)
        assertEquals(4f + 0.7f, w.give(6f), 0.001f)
        assertEquals(2.4f, w.give(2.4f), 0f)
        assertEquals(2f, w.settle(2.4f), 0f); assertEquals(3f, w.settle(2.6f), 0f)
        assertEquals(0f, w.settle(-3f), 0f); assertEquals(4f, w.settle(9f), 0f)
    }

    @Test fun theMiddleMovesOnlyAsFarAsKeepsTheColumnOnTheScreen() {
        // a wheel: half = 2 × 56 + 24 + 15 (the triangle and its gap) = 151; the header's line is at 56, the foot's margin 16
        assertEquals(56f + 151f, HoldWheel(500f, 70f, 9, 915f, 412f).mid, 0.01f)
        assertEquals(412f - 16f - 151f, HoldWheel(500f, 400f, 9, 915f, 412f).mid, 0.01f)
        assertEquals(220f, HoldWheel(500f, 220f, 9, 915f, 412f).mid, 0.01f)
        // five choices, no triangles: 136
        assertEquals(56f + 136f, HoldWheel(500f, 70f, 5, 915f, 412f).mid, 0.01f)
        // one choice: only its own half height
        assertEquals(56f + 24f, HoldWheel(500f, 60f, 1, 915f, 412f).mid, 0.01f)
        val top = HoldWheel(500f, 70f, 9, 915f, 412f)
        assertTrue((0 until 5).all { top.spot(it, 0f).rowY >= 56f - 0.01f })
        assertTrue(top.triangle(up = true).second - 7f >= 56f - 0.01f)      // the upper triangle's tip is under the header too
    }

    /** The iPhone's side rule (b565310): away from the playing hand wherever the press is; flip only when there is no room there. */
    @Test fun theSideIsAwayFromTheHandUnlessThereIsNoRoom() {
        // room(left) = x − 208, room(right) = W − 208 − x; minimum 54
        assertTrue(HoldWheel(300f, 200f, 5, 915f, 412f).left)                         // right-handed: left, even with the right roomier
        assertTrue(HoldWheel(700f, 200f, 5, 915f, 412f).left)                         // …and near the right edge too
        assertFalse(HoldWheel(200f, 200f, 5, 915f, 412f).left)                        // room(left) = −8 < 54: the other side
        assertFalse(HoldWheel(500f, 200f, 5, 915f, 412f, leftHanded = true).left)     // left-handed: right
        assertFalse(HoldWheel(100f, 200f, 5, 915f, 412f, leftHanded = true).left)
        assertTrue(HoldWheel(700f, 200f, 5, 915f, 412f, leftHanded = true).left)      // room(right) = 915 − 208 − 700 = 7 < 54: the other side
        // neither side has 54: the roomier one
        assertTrue(HoldWheel(250f, 200f, 5, 460f, 412f).left)                         // left −? room(left)=42, room(right)=2: left
        assertFalse(HoldWheel(220f, 200f, 5, 460f, 412f).left)                        // room(left)=12, room(right)=32: right
    }

    @Test fun theMiddleChoiceComesInNearAnEdgeInsteadOfFlipping() {
        // plenty of room: 76 out
        val a = HoldWheel(500f, 200f, 5, 915f, 412f)
        assertTrue(a.left); assertEquals(76f, a.near, 0f); assertEquals(500f - 76f, a.spot(2, 0f).nodeX, 0.01f)
        // room(left) = 270 − 208 = 62: 62 out, not 76 and not flipped
        val b = HoldWheel(270f, 200f, 5, 915f, 412f)
        assertTrue(b.left); assertEquals(62f, b.near, 0.01f); assertEquals(270f - 62f, b.spot(2, 0f).nodeX, 0.01f)
        // never less than 54
        assertEquals(54f, HoldWheel(262f, 200f, 5, 915f, 412f).near, 0.01f)
        assertEquals(54f, HoldWheel(250f, 200f, 5, 460f, 412f).near, 0.01f)             // neither side has 54: the roomier one, at 54
        // the curve's centre follows: C = (x ± (near − 400))
        assertEquals(270f - (62f - 400f), b.centreX, 0.01f)
    }

    /** The black backing (iPhone d0797f9): an annular sector from 366 to 612 round the curve's centre, ±(reach + 14) tall, 88 % black, feathered 8. */
    @Test fun theBlackFieldIsAnAnnularSectorBehindTheArc() {
        assertEquals(366f, HoldWheel.FIELD_INNER, 0f); assertEquals(612f, HoldWheel.FIELD_OUTER, 0f)
        assertEquals(0.88f, HoldWheel.FIELD_ALPHA, 0f); assertEquals(8f, HoldWheel.FIELD_FEATHER, 0f)
        val five = HoldWheel(500f, 200f, 5, 915f, 412f)
        assertEquals(136f + 14f, five.fieldHalf, 0.01f)                                // reach 136, no triangles
        assertEquals(Math.toDegrees(kotlin.math.asin(150.0 / 366.0)), five.fieldInnerSweep.toDouble(), 0.01)
        assertEquals(Math.toDegrees(kotlin.math.asin(150.0 / 612.0)), five.fieldOuterSweep.toDouble(), 0.01)
        val nine = HoldWheel(500f, 220f, 9, 915f, 412f)
        assertEquals(136f + 15f + 14f, nine.fieldHalf, 0.01f)                          // a wheel adds the triangles' 15
        assertTrue(nine.fieldInnerSweep > five.fieldInnerSweep)
        // it covers the rows: the outer arc reaches past the rows' far edge (the middle row ends at near + 200 from the finger)
        assertTrue(HoldWheel.FIELD_OUTER > HoldWheel.CURVE + HoldWheel.ROW_W)
    }

    @Test fun theCircleGoesPastItsSizeUndershootsOnceAndSettles() {
        assertEquals(0f, hubScale(0f, 0.6f), 0.001f)
        assertEquals(1f + 0.35f * 0.6f, hubScale(0.45f, 0.6f), 0.001f)        // past its size
        assertEquals(1f - 0.1f * 0.6f, hubScale(0.75f, 0.6f), 0.001f)         // one undershoot
        assertEquals(1f, hubScale(1f, 0.6f), 0.001f)
        assertTrue((1..99).all { hubScale(it / 100f, 0f) <= 1f })              // Spring 0: a plain ease-out, never past
    }

    @Test fun aTapPicksAChoice() {
        // decision 36: a tap picks; a drag never does (the menu has no way to pick from a drag any more)
        var picked = ""
        val m = HoldMenuState()
        m.open(Offset(100f, 100f), Color.Red, listOf(HoldItem("Edit steps") { picked = "edit" }, HoldItem("Clear") { picked = "clear" }))
        m.pick(1)
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

    @Test fun aDisabledChoiceDoesNotPick() {
        var done = false
        val m = HoldMenuState()
        m.open(Offset.Zero, Color.Red, listOf(HoldItem("Set pattern…", enabled = false) { done = true }))
        m.pick(0); assertFalse(done); assertTrue(m.menu != null)
    }
}
