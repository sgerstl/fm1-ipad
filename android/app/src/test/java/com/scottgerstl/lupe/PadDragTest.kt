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
    private val feel = WellFeel(glowPx = 96f, hotPx = 48f)
    private val w = 874f; private val h = 402f
    // (grabbed in the middle: the finger is the pad's centre)
    private fun drag(finger: Offset, track: Int = 2, from: Int = 1, pattern: Int? = 7) =
        PadDrag(track, from, pattern == null, pattern, Color.White, Size(80f, 40f), Offset(40f, 20f), finger, "B")
    private fun slot(t: Int, i: Int, empty: Boolean, x: Float, y: Float, landing: Int = i) = DropSlot(t, i, landing, empty, Rect(x, y, x + 80f, y + 40f))

    @Test fun theWellsAreTheBoards() {
        val c = EdgeWellsGeometry.rect(EdgeAction.Clear, w, h, 1f)
        assertEquals(434f, c.width, 0.01f); assertEquals(52f, c.height, 0.01f); assertEquals(h, c.bottom, 0.01f)
        val e = EdgeWellsGeometry.rect(EdgeAction.Edit, w, h, 1f); val dup = EdgeWellsGeometry.rect(EdgeAction.Duplicate, w, h, 1f)
        assertEquals(64f, e.width, 0.01f); assertEquals(w, e.right, 0.01f); assertEquals(238f, e.height, 0.01f)
        assertEquals(0f, dup.left, 0.01f); assertEquals(64f, dup.width, 0.01f); assertEquals((h - 238f) / 2, dup.top, 0.01f)
    }

    @Test fun hotWithinTheHotDistanceGlowFromTheGlowDistance() {
        assertNull(EdgeWellsGeometry.hot(Offset(400f, 200f), w, h, 1f, feel))
        assertEquals(EdgeAction.Clear, EdgeWellsGeometry.hot(Offset(437f, h - 52f - 40f), w, h, 1f, feel))
        assertNull(EdgeWellsGeometry.hot(Offset(437f, h - 52f - 60f), w, h, 1f, feel))
        assertEquals(EdgeAction.Edit, EdgeWellsGeometry.hot(Offset(w - 64f - 10f, 200f), w, h, 1f, feel))
        assertEquals(EdgeAction.Duplicate, EdgeWellsGeometry.hot(Offset(60f, 200f), w, h, 1f, feel))
        assertEquals(0f, EdgeWellsGeometry.closeness(EdgeAction.Clear, Offset(437f, h - 52f - 96f), w, h, 1f, feel), 0.001f)
        assertEquals(0.5f, EdgeWellsGeometry.closeness(EdgeAction.Clear, Offset(437f, h - 52f - 48f), w, h, 1f, feel), 0.001f)
        assertEquals(1f, EdgeWellsGeometry.closeness(EdgeAction.Clear, Offset(437f, h - 10f), w, h, 1f, feel), 0.001f)
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
        val s = listOf(slot(2, 0, false, 100f, 100f), slot(2, 4, true, 300f, 100f, landing = 3), slot(3, 2, false, 100f, 200f), slot(3, 5, true, 300f, 200f, landing = 4))
        assertEquals(DropAction.Move(2, 1, 0), decideDrop(drag(Offset(120f, 110f)), s, w, h, 1f, feel))
        assertEquals(DropAction.Move(2, 1, 3), decideDrop(drag(Offset(320f, 110f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(120f, 210f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(500f, 300f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(305f, 105f), from = 0), listOf(slot(2, 0, false, 300f, 100f)), w, h, 1f, feel))
    }

    @Test fun aPatternOnAnotherTracksEmptySlotAsksAndARestDoesNot() {
        val s = listOf(slot(3, 5, true, 300f, 200f, landing = 4))
        assertEquals(DropAction.Offer(3, 4, 7), decideDrop(drag(Offset(320f, 210f)), s, w, h, 1f, feel))
        assertNull(decideDrop(drag(Offset(320f, 210f), pattern = null), s, w, h, 1f, feel))
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
