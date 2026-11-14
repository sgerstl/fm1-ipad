package com.scottgerstl.lupe

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import com.scottgerstl.lupe.core.GraphKind
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.core.PageRef
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.ui.page.hasPicture
import com.scottgerstl.lupe.ui.page.pictureOf
import com.scottgerstl.lupe.ui.shell.PANEL_TINT
import com.scottgerstl.lupe.ui.theme.Tok
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SoundPanelContrastTest {
    private fun ratio(a: Color, b: Color): Float { val la = a.luminance(); val lb = b.luminance(); return (maxOf(la, lb) + 0.05f) / (minOf(la, lb) + 0.05f) }

    /** The pop-up's surface is the track's colour muted over the page: text and labels keep 4.5:1 and the dials' arcs 3:1 on it, in every track colour. */
    @Test fun textAndDialsReadOnThePopUpInEveryTrackColour() {
        Tok.track.forEachIndexed { i, c ->
            val surface = lerp(Tok.page, c, PANEL_TINT)
            assertTrue("track ${i + 1}: text ${ratio(Tok.text, surface)}", ratio(Tok.text, surface) >= 4.5f)
            assertTrue("track ${i + 1}: labels ${ratio(Tok.text2Raised, surface)}", ratio(Tok.text2Raised, surface) >= 4.5f)
            assertTrue("track ${i + 1}: arc ${ratio(c, surface)}", ratio(c, surface) >= 3f)
        }
    }

    private fun fx(title: String, vararg raws: Int) = PageState(family = "FX", pages = listOf(PageRef(7, title)), page = 7,
        controls = raws.map { PageControl("K", "$it", it) } + List(4 - raws.size) { null })

    /** Every FX page gets its own picture: the core's when it sends one, else one made from the page's four knobs. */
    @Test fun everyFxPageHasItsOwnPicture() {
        assertEquals(GraphKind.FxDelay, pictureOf(fx("DELAY", 30, 1, 40, 64)).kind)
        assertEquals(30, pictureOf(fx("DELAY", 30, 1, 40, 64)).send)
        assertEquals(listOf(1, 40, 64, 127), pictureOf(fx("DELAY", 30, 1, 40, 64)).values)
        assertEquals(GraphKind.FxReverb, pictureOf(fx("REVERB", 40, 2, 70, 30)).kind)
        assertEquals(GraphKind.Insert, pictureOf(fx("INSERT", 9, 64, 40, 0)).kind)
        assertEquals(GraphKind.Slicer, pictureOf(fx("SLICER", 1, 3, 3, 80)).kind)
        assertEquals(GraphKind.Duck, pictureOf(fx("DUCK", 1, 60, 40)).kind)
        listOf("DELAY", "REVERB", "INSERT", "SLICER", "DUCK").forEach { assertTrue(it, hasPicture(pictureOf(fx(it, 1, 2, 3, 4)))) }
        // the core's own picture wins when it sends one, and a page with none stays without
        val drive = fx("DRIVE", 72, 0, 40).copy(graph = com.scottgerstl.lupe.core.PageGraph(GraphKind.Drive, values = listOf(72, 0, 40)))
        assertEquals(GraphKind.Drive, pictureOf(drive).kind)
        assertFalse(hasPicture(pictureOf(PageState(family = "SEL", pages = listOf(PageRef(12, "CHORD")), page = 12))))
    }
}
