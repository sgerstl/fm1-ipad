package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.headerCornerInset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HeaderCornerTest {
    @Test fun playSitsInsideTheCornerWhateverItsRadius() {
        assertEquals(24f, headerCornerInset(0f), 0.01f)      // a square corner: the floor
        assertEquals(24f, headerCornerInset(48f), 0.01f)
        assertTrue(headerCornerInset(80f) > headerCornerInset(64f))   // a rounder corner pushes the key further in
        // the circle's upper right point is inside the corner's curve with the inset applied (radius 80)
        val r = 80f; val e = headerCornerInset(r)
        val px = r - (e + 4f + 20f - 20f * 0.7071f); val py = r - (28f - 20f * 0.7071f)
        assertTrue(px * px + py * py <= (r - 2f) * (r - 2f))
    }
}
