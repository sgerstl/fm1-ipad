package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.GraphKind
import com.scottgerstl.lupe.core.MixCard
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.core.PageGraph
import com.scottgerstl.lupe.ui.mix.busGraph
import com.scottgerstl.lupe.ui.page.chorusResp
import com.scottgerstl.lupe.ui.page.delayBars
import com.scottgerstl.lupe.ui.page.hasPicture
import com.scottgerstl.lupe.ui.page.reverbTail
import com.scottgerstl.lupe.ui.page.swingText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The FM-1's own pictures (decision 34), checked against the numbers in design/boards/fm1-screens/NOTES.md (Skiff 2.5.1 ui_pgraph.c). */
class MixPicturesTest {
    @Test fun theDryHitIsFullHeightAndEchoOneIsTheMix() {
        // TIME 1/8 (index 1), FEEDBACK 60, MIX 90: the FM-1's default. Dry 100 px; echo 1 is 90·1000/127 tenths = 70 px
        val bars = delayBars(time = 1, feedback = 60, mix = 90)
        assertEquals(Triple(14, 13, 100), bars[0])
        assertEquals(70, bars[1].third)
        // each next echo is the last × FEEDBACK·230/32768
        assertEquals(708 * 60 * 230 / 32768 / 10, bars[2].third)
        // 1/8 in a one-bar window: bars 26 px apart
        assertEquals(26, bars[1].first - bars[0].first)
    }

    @Test fun onATracksPageTheSendScalesEchoOne() {
        // FX › DELAY: echo 1 is MIX × SEND, not MIX at 127
        assertEquals(708 * 64 / 127 / 10, delayBars(1, 60, 90, send = 64)[1].third)
        assertTrue(delayBars(1, 60, 90, send = 127)[1].third < delayBars(1, 60, 127, send = 127)[1].third)
    }

    @Test fun barsStopBelowFourPixelsAndInsideThePanel() {
        delayBars(1, 127, 127).forEach { (x, w, h) -> assertTrue(x + w <= 228); assertTrue(h >= 4) }
        assertEquals(2, delayBars(1, 0, 90).size)   // no feedback: the dry hit and one echo
    }

    @Test fun theTailFallsInWholePixelsAndHallIsTwiceAsLong() {
        val room = reverbTail(size = 90, damp = 60, hall = false)
        assertEquals(185, room.size)
        assertEquals(84, room.first().first)
        assertTrue(room.zipWithNext().all { (a, b) -> b.first <= a.first })
        val hall = reverbTail(90, 60, hall = true)
        assertTrue(hall[100].first > room[100].first)
        // DAMP sets how much of each column is the dark band: 20 % at 0, 80 % at 127
        assertEquals(84 * 20 / 100, reverbTail(90, 0, false).first().second)
        assertEquals(84 * 80 / 100, reverbTail(90, 127, false).first().second)
        // FX › REVERB: the send scales it
        assertEquals(84 * 64 / 127, reverbTail(90, 60, false, send = 64).first().first)
    }

    @Test fun theFlangerIsACombAndThePhaserHasTwoNotches() {
        val comb = (0..216).map { chorusResp(1, it, depth = 60, fb = 0) }
        assertTrue(comb.max() <= 1.0001 && comb.min() >= 0.0)
        val ph = (0..216).map { chorusResp(2, it, depth = 60, fb = 0) }
        assertTrue(ph[66] < 0.15 && ph[150] < 0.15 && ph[108] > 0.5)
    }

    @Test fun swingReadsAsTheFm1WritesIt() {
        assertEquals("SWING 50:50", swingText(0)); assertEquals("SWING 60:40", swingText(50)); assertEquals("SWING 70:30", swingText(100))
    }

    @Test fun everyBusPageHasItsPicture() {
        val card = MixCard("DELAY", controls = listOf(PageControl("TIME", "1/8", 1), PageControl("FEEDBK", "47%", 60), PageControl("COLOR", "50%", 64), PageControl("MIX", "71%", 90)),
            settings = listOf(PageControl("DLY MODE", "STEREO", 1)))
        val g = busGraph("delay", card)!!
        assertEquals(GraphKind.Delay, g.kind); assertEquals(listOf(1, 60, 64, 90), g.values); assertEquals("STEREO", g.caption)
        // the core's own graph is kept; DELAY's caption is still the mode
        assertEquals(listOf(3, 2, 1, 0), busGraph("delay", card.copy(graph = PageGraph(GraphKind.Delay, values = listOf(3, 2, 1, 0), caption = "1/16")))!!.values)
        for (k in listOf("delay", "reverb", "chorus", "global")) assertTrue(k, hasPicture(busGraph(k, card)!!))
        assertNull(busGraph("mixer", card)); assertNull(busGraph("delay", null))
    }
}
