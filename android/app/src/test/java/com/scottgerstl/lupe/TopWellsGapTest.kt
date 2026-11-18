package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.EdgeAction
import com.scottgerstl.lupe.ui.shell.EdgeWellsGeometry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The top pair (Scott, 2026-11-18: "need some space between them"). */
class TopWellsGapTest {
    private val d = 2.625f
    @Test fun thePairSits24Apart() {
        for (w in listOf(2499f, 1200f)) {        // the Pixel's landscape width in px, and a narrow one where the 0.6 cap bites
            val c = EdgeWellsGeometry.rect(EdgeAction.ClearSteps, w, 1120f, d); val del = EdgeWellsGeometry.rect(EdgeAction.Delete, w, 1120f, d)
            assertEquals(24f * d, del.left - c.right, 0.01f)
            assertTrue(del.right - c.left <= w * 0.6f + 0.01f)
        }
    }
    @Test fun growingNeverClosesTheGapBelow16() {
        val fullyHot = 8f * d
        assertEquals(24f * d - 2 * EdgeWellsGeometry.innerAlong(fullyHot, d), 16f * d, 0.01f)
        assertEquals(1f * d, EdgeWellsGeometry.innerAlong(1f * d, d), 0.001f)     // a little growth passes through unchanged
    }
}
