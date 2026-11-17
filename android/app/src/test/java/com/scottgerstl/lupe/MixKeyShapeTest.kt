package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.mix.segmentCorners
import org.junit.Assert.assertEquals
import org.junit.Test

/** The Mute · Solo key and its launch trace draw from one set of corners (Scott, 2026-11-17: the trace was an oval round a square-cornered key). */
class MixKeyShapeTest {
    @Test fun offKeyHasPillOutsideAndSquarerInside() {
        val (l, r) = segmentCorners(pill = 36f, inner = 16f, s = 0f, first = true, last = false)   // Mute, off
        assertEquals(36f, l, 0f); assertEquals(16f, r, 0f)
        val (l2, r2) = segmentCorners(pill = 36f, inner = 16f, s = 0f, first = false, last = true) // Solo, off
        assertEquals(16f, l2, 0f); assertEquals(36f, r2, 0f)
    }

    @Test fun onKeyRoundsToAPillAndNeverPast() {
        assertEquals(36f, segmentCorners(36f, 16f, 1f, first = true, last = false).second, 0f)
        assertEquals(26f, segmentCorners(36f, 16f, 0.5f, first = true, last = false).second, 0f)
        assertEquals(36f, segmentCorners(36f, 16f, 1.2f, first = true, last = false).second, 0f)    // the spring's overshoot stays a pill
    }
}
