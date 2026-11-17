package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.bandRadii
import org.junit.Assert.assertEquals
import org.junit.Test

/** The selected track's band nests round the head pill (outer = inner + padding; Scott, 2026-11-18). */
class BandCornersTest {
    @Test fun aRoundLeftEndIsHalfTheHeightAndTheRightIsThePadsPlusTheInset() {
        // a 44-tall row plus 2 + 2: the head pill's radius 22 + 2 = 24, half the band's 48
        assertEquals(24f to 12f, bandRadii(48f, -1f, 12f))
        assertEquals(10f to 10f, bandRadii(48f, 10f, 10f))
        assertEquals(24f to 24f, bandRadii(48f, 40f, 40f))    // never more than half the height
    }
}
