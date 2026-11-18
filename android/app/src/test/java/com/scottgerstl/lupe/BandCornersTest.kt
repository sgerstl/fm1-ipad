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

    // the selected head squares to 12; the band nests on it: 12 + the 2 dp inset
    @Test fun theHeadSquaresAndTheBandNests() {
        assertEquals(22f, com.scottgerstl.lupe.ui.shell.headRadius(44f, 12f, 0f), 0f)   // unselected: a pill
        assertEquals(12f, com.scottgerstl.lupe.ui.shell.headRadius(44f, 12f, 1f), 0f)   // selected
        assertEquals(17f, com.scottgerstl.lupe.ui.shell.headRadius(44f, 12f, 0.5f), 0f)
        assertEquals(14f to 12f, bandRadii(48f, 12f + 2f, 10f + 2f))
    }

    // the selected head's badge squares too, nested inside the 12 dp outline (Scott, 2026-11-18)
    @Test fun theBadgeNestsInsideTheSquaredHead() {
        val r = com.scottgerstl.lupe.ui.mix.nestedBadgeRadius(12f, (42.7f - 30f) / 2f)!!   // a Pads head on the Pixel 10 Pro: about 5.7 dp
        assertEquals(5.65f, r, 0.01f)
        assertEquals(6f, com.scottgerstl.lupe.ui.mix.nestedBadgeRadius(12f, 6f)!!, 0f)       // the Timeline's head (6 dp padding)
        assertEquals(8f, com.scottgerstl.lupe.ui.mix.nestedBadgeRadius(12f, 4f)!!, 0f)       // a short row (the spacer's 4 dp floor)
        assertEquals(null, com.scottgerstl.lupe.ui.mix.nestedBadgeRadius(12f, 9f))           // under 4 dp: it stays round
    }
}
