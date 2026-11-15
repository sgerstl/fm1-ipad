package com.scottgerstl.lupe

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.scottgerstl.lupe.core.GraphKind
import com.scottgerstl.lupe.core.PageGraph
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.ui.page.chordKeys
import com.scottgerstl.lupe.ui.page.chordSpoken
import com.scottgerstl.lupe.ui.page.hasPicture
import com.scottgerstl.lupe.ui.page.strumStart
import com.scottgerstl.lupe.ui.theme.Tok
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordFollowPictureTest {
    /** P1's shapes (10793da), as sent. */
    @Test fun theCoresChordAndFollowDecode() {
        val c = lupeJson.decodeFromString<PageGraph>("""{"kind":"chord","title":"Cm7","caption":"ON ROOT","notes":[60,63,67,70],"root":0,"values":[]}""")
        assertEquals(GraphKind.Chord, c.kind); assertEquals(listOf(60, 63, 67, 70), c.notes); assertTrue(hasPicture(c))
        val f = lupeJson.decodeFromString<PageGraph>("""{"kind":"follow","title":"FOLLOWS T3 · SCALE BY ITS HIGH","caption":"ITS LIVE CHORD SHOWS ON THE FM-1","follow":{"track":2,"trackName":"T3","mode":"SCALE","by":"HIGH","kit":false}}""")
        assertEquals(GraphKind.Follow, f.kind); assertEquals(2, f.follow?.track); assertEquals(false, f.follow?.kit)
        assertNull(lupeJson.decodeFromString<PageGraph>("""{"kind":"follow","title":"FOLLOW OFF","caption":"K1 A TRACK TO FOLLOW"}""").follow)
    }

    @Test fun theKeysStartAtTheCBelowAndWidenForAWideChord() {
        assertEquals(60 to 24, chordKeys(listOf(60, 63, 67, 70)))
        assertEquals(48 to 36, chordKeys(listOf(50, 67, 70, 75)))
        assertEquals(60 to 24, chordKeys(listOf(62, 83)))
        assertEquals(60 to 36, chordKeys(listOf(62, 84)))
    }

    @Test fun theStrumPlaysLowFirstGoingDownAndHighFirstGoingUp() {
        assertEquals(listOf(0, 10, 20, 30), (0..3).map { strumStart(it, 4, 30, 0) })
        assertEquals(listOf(30, 20, 10, 0), (0..3).map { strumStart(it, 4, 30, 1) })
        assertEquals(listOf(0, 10, 20, 30), (0..3).map { strumStart(it, 4, 30, 2) })
        assertEquals(0, strumStart(0, 1, 30, 0))
    }

    @Test fun itSaysTheChordOrWhyThereIsNone() {
        assertEquals("Cm7, C4, D sharp 4, G4, A sharp 4", chordSpoken(PageGraph(GraphKind.Chord, title = "Cm7", notes = listOf(60, 63, 67, 70))))
        assertEquals("Cm7, strummed up over 30 milliseconds, C4, G4", chordSpoken(PageGraph(GraphKind.Chord, title = "Cm7", notes = listOf(60, 67), values = listOf(30, 1))))
        assertEquals("No chords on kits", chordSpoken(PageGraph(GraphKind.Chord, title = "NO CHORDS ON KITS")))
    }

    /** FOLLOW's first line is written in the followed track's colour on the picture's well: every track colour keeps 4.5:1 there. */
    @Test fun everyTrackColourReadsAsWordsOnTheWell() {
        fun ratio(a: Color, b: Color): Float { val la = a.luminance(); val lb = b.luminance(); return (maxOf(la, lb) + 0.05f) / (minOf(la, lb) + 0.05f) }
        Tok.track.forEachIndexed { i, c -> assertTrue("track ${i + 1}: ${ratio(c, Tok.well)}", ratio(c, Tok.well) >= 4.5f) }
    }
}
