package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.PadMove
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.ui.shell.*
import org.junit.Assert.*
import org.junit.Test

class PadDragTest {
    private val feel = WellFeel(glowPx = 200f, hotPx = 64f)
    private val w = 874f; private val h = 402f
    // (grabbed in the middle: the finger is the pad's centre)
    private fun drag(finger: Offset, track: Int = 2, from: Int = 1, pattern: Int? = 7) =
        PadDrag(track, from, pattern == null, pattern, Color.White, Size(80f, 40f), Offset(40f, 20f), finger, "B")
    private fun slot(t: Int, i: Int, empty: Boolean, x: Float, y: Float, landing: Int = i) = DropSlot(t, i, landing, empty, Rect(x, y, x + 80f, y + 40f))

    @Test fun theWellsAreTheBoards() {
        val c = EdgeWellsGeometry.rect(EdgeAction.Cancel, w, h, 1f)
        assertEquals(434f, c.width, 0.01f); assertEquals(52f, c.height, 0.01f); assertEquals(h, c.bottom, 0.01f)
        val e = EdgeWellsGeometry.rect(EdgeAction.Edit, w, h, 1f); val dup = EdgeWellsGeometry.rect(EdgeAction.Duplicate, w, h, 1f)
        assertEquals(64f, e.width, 0.01f); assertEquals(w, e.right, 0.01f); assertEquals(238f, e.height, 0.01f)
        assertEquals(0f, dup.left, 0.01f); assertEquals(64f, dup.width, 0.01f); assertEquals((h - 238f) / 2, dup.top, 0.01f)
    }

    @Test fun theTopHoldsClearStepsAndDeletePatternSideBySide() {
        val a = EdgeWellsGeometry.rect(EdgeAction.ClearSteps, w, h, 1f); val b = EdgeWellsGeometry.rect(EdgeAction.Delete, w, h, 1f)
        assertEquals(0f, a.top, 0.01f); assertEquals(52f, a.height, 0.01f); assertEquals(8f, b.left - a.right, 0.01f)
        assertEquals(a.width, b.width, 0.01f); assertEquals(w / 2, (a.left + b.right) / 2, 0.01f)
        assertEquals(EdgeAction.ClearSteps, EdgeWellsGeometry.hot(Offset(a.center.x, 60f), w, h, 1f, feel))
        assertEquals(EdgeAction.Delete, EdgeWellsGeometry.hot(Offset(b.center.x, 60f), w, h, 1f, feel))
    }

    @Test fun deleteIsNeverHotWhilePlayingAndDoesNotGlow() {
        val playing = feel.copy(off = setOf(EdgeAction.Delete))
        val b = EdgeWellsGeometry.rect(EdgeAction.Delete, w, h, 1f)
        assertNull(EdgeWellsGeometry.hot(Offset(b.center.x, 20f), w, h, 1f, playing))
        assertEquals(0f, EdgeWellsGeometry.closeness(EdgeAction.Delete, Offset(b.center.x, 20f), w, h, 1f, playing), 0.001f)
        // Clear steps works playing
        assertEquals(EdgeAction.ClearSteps, EdgeWellsGeometry.hot(Offset(EdgeWellsGeometry.rect(EdgeAction.ClearSteps, w, h, 1f).center.x, 20f), w, h, 1f, playing))
    }

    @Test fun hotWithinTheHotDistanceGlowFromTheGlowDistance() {
        assertNull(EdgeWellsGeometry.hot(Offset(400f, 200f), w, h, 1f, feel))
        assertEquals(EdgeAction.Cancel, EdgeWellsGeometry.hot(Offset(437f, h - 52f - 60f), w, h, 1f, feel))
        assertNull(EdgeWellsGeometry.hot(Offset(437f, h - 52f - 80f), w, h, 1f, feel))
        assertEquals(EdgeAction.Edit, EdgeWellsGeometry.hot(Offset(w - 64f - 10f, 200f), w, h, 1f, feel))
        assertEquals(EdgeAction.Duplicate, EdgeWellsGeometry.hot(Offset(60f, 200f), w, h, 1f, feel))
        // 0 at the glow distance (200), rising steadily to 1 at the hot distance (64)
        assertEquals(0f, EdgeWellsGeometry.closeness(EdgeAction.Cancel, Offset(437f, h - 52f - 200f), w, h, 1f, feel), 0.001f)
        assertEquals(0.5f, EdgeWellsGeometry.closeness(EdgeAction.Cancel, Offset(437f, h - 52f - 132f), w, h, 1f, feel), 0.001f)
        assertEquals(1f, EdgeWellsGeometry.closeness(EdgeAction.Cancel, Offset(437f, h - 52f - 64f), w, h, 1f, feel), 0.001f)
        assertEquals(1f, EdgeWellsGeometry.closeness(EdgeAction.Cancel, Offset(437f, h - 10f), w, h, 1f, feel), 0.001f)
    }

    @Test fun aSlideBeforeTheDwellIsASwipeAfterItALift() {
        assertNull(liftsOrSwipes(3f, 8f, 100, 150))
        assertEquals(false, liftsOrSwipes(12f, 8f, 100, 150))
        assertEquals(true, liftsOrSwipes(12f, 8f, 200, 150))
    }

    @Test fun aDropOnAWellActsBeforeAnySlot() {
        val s = listOf(slot(2, 3, true, 0f, 0f))
        assertEquals(DropAction.Well(EdgeAction.Edit), decideDrop(drag(Offset(w - 64f - 10f, 200f)), s, w, h, 1f, feel))
    }

    @Test fun aDropOnASlotOfItsOwnTrackMoves() {
        val s = listOf(slot(2, 0, false, 250f, 160f), slot(2, 4, true, 400f, 160f, landing = 3), slot(3, 2, false, 250f, 240f), slot(3, 5, true, 400f, 240f, landing = 4))
        assertEquals(DropAction.Move(2, 1, 0), decideDrop(drag(Offset(270f, 170f)), s, w, h, 1f, feel))
        assertEquals(DropAction.Move(2, 1, 3), decideDrop(drag(Offset(420f, 170f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(270f, 250f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(600f, 200f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(405f, 165f), from = 0), listOf(slot(2, 0, false, 400f, 160f)), w, h, 1f, feel))
    }

    @Test fun aPatternOnAnotherTracksEmptySlotAsksAndARestDoesNot() {
        val s = listOf(slot(3, 5, true, 400f, 240f, landing = 4))
        assertEquals(DropAction.Offer(3, 4, 7), decideDrop(drag(Offset(420f, 250f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(420f, 250f), pattern = null), s, w, h, 1f, feel))
    }

    @Test fun theMoveTravelsAsPadMove() {
        assertEquals("""{"intent":"padMove","track":2,"from":1,"toTrack":2,"to":3}""", lupeJson.encodeToString(Intent.serializer(), PadMove(2, 1, 2, 3)))
    }
}

class PadMenuIdleTest {
    @Test fun aCurrentEntryDoesNotMeanPlaying() {
        // stopped transport: every track's current entry still reads "playing" in its pad, and the menu's stopped-only items stay enabled
        assertTrue(padMenuIdle(transportPlaying = false, timelinePlaying = false))
        assertFalse(padMenuIdle(transportPlaying = true, timelinePlaying = true))
        assertFalse(padMenuIdle(transportPlaying = true, timelinePlaying = false))
        assertFalse(padMenuIdle(transportPlaying = false, timelinePlaying = true))
    }
}

class SideWellsGlowSoonerTest {
    private val w = 874f; private val h = 402f
    private val feel = WellFeel(glowPx = 180f, hotPx = 64f, sideGlowPx = 390f, sideHotPx = 96f)
    @Test fun aSideWellGlowsFromFarAndIsHotEarlier() {
        val e = EdgeWellsGeometry.rect(EdgeAction.Edit, w, h, 1f)
        // 300 out: the side well already glows, the bottom would not at that distance
        val at = Offset(e.left - 300f, 200f)
        assertTrue(EdgeWellsGeometry.closeness(EdgeAction.Edit, at, w, h, 1f, feel) in 0.1f..0.5f)
        assertNull(EdgeWellsGeometry.hot(at, w, h, 1f, feel))
        assertEquals(EdgeAction.Edit, EdgeWellsGeometry.hot(Offset(e.left - 90f, 200f), w, h, 1f, feel))   // hot at 96
        assertNull(EdgeWellsGeometry.hot(Offset(e.left - 100f, 200f), w, h, 1f, feel))
        val c = EdgeWellsGeometry.rect(EdgeAction.Cancel, w, h, 1f)
        assertEquals(0f, EdgeWellsGeometry.closeness(EdgeAction.Cancel, Offset(437f, c.top - 200f), w, h, 1f, feel), 0.001f)   // beyond its 180
    }
}
