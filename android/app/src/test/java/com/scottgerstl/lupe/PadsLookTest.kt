package com.scottgerstl.lupe

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.scottgerstl.lupe.ui.shell.ROW_TINT
import com.scottgerstl.lupe.ui.shell.emptyOutline
import com.scottgerstl.lupe.ui.shell.trackBand
import com.scottgerstl.lupe.ui.theme.Tok
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PadsLookTest {
    private fun ratio(a: Color, b: Color): Float { val la = a.luminance(); val lb = b.luminance(); return (maxOf(la, lb) + 0.05f) / (minOf(la, lb) + 0.05f) }

    /** Decision 31, board 76: the band is the track's colour at 28 % over the page. */
    @Test fun theBandIs28PercentOfTheTracksColour() { assertEquals(0.28f, ROW_TINT, 0f) }

    /** On the selected track's band an empty slot's letter keeps 4.5:1 and its outline (the track's colour there) 3:1, in every track colour. */
    @Test fun emptySlotsReadOnEveryBand() {
        Tok.track.forEachIndexed { i, c ->
            val band = trackBand(c)
            assertTrue("track ${i + 1}: letter ${ratio(Tok.text2Raised, band)}", ratio(Tok.text2Raised, band) >= 4.5f)
            assertTrue("track ${i + 1}: outline ${ratio(emptyOutline(c, 1f), band)}", ratio(emptyOutline(c, 1f), band) >= 3f)
        }
        assertTrue(ratio(Tok.text2Raised, Tok.page) >= 4.5f)
        assertTrue("an empty scene's number ${ratio(Tok.text2, Tok.page)}", ratio(Tok.text2, Tok.page) >= 4.5f)
    }
}
