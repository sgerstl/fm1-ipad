package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.ClearPatterns
import com.scottgerstl.lupe.core.CopyPattern
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.PatternPicture
import com.scottgerstl.lupe.core.PatternPictures
import com.scottgerstl.lupe.core.PatternUse
import com.scottgerstl.lupe.core.PatternsOpen
import com.scottgerstl.lupe.core.PatternsState
import com.scottgerstl.lupe.core.PoolPattern
import com.scottgerstl.lupe.core.RecyclePattern
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.core.padName
import com.scottgerstl.lupe.core.usesText
import com.scottgerstl.lupe.ui.patterns.PatternFilter
import com.scottgerstl.lupe.ui.patterns.clearNumbers
import com.scottgerstl.lupe.ui.patterns.clearQuestion
import com.scottgerstl.lupe.ui.patterns.countsText
import com.scottgerstl.lupe.ui.patterns.filtered
import com.scottgerstl.lupe.ui.patterns.firstUserTrack
import com.scottgerstl.lupe.ui.patterns.stepMarks
import com.scottgerstl.lupe.ui.patterns.usedWhere
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Patterns sheet's model (board 79, decision 38), and P1's shapes exactly as 3d09937 sends them. */
class PatternsSheetTest {
    private val json = """{"free":12,"kept":52,"unused":3,"recycle":3,"picturesWaitForStop":false,"picturesLoading":false,
        "patterns":[{"number":3,"len":16,"uses":0,"here":[],"on":[],"saved":false,"unused":true},
                    {"number":7,"len":32,"uses":3,"here":[{"track":2,"entry":0},{"track":4,"entry":2}],"on":[2],"saved":true,"unused":false}]}"""

    private fun state() = lupeJson.decodeFromString<PatternsState>(json)

    @Test fun theCoresAreaDecodes() {
        val s = state()
        assertEquals(12, s.free); assertEquals(52, s.kept); assertEquals(3, s.unused); assertEquals(3, s.recycle)
        assertEquals(listOf(3, 7), s.patterns.map { it.number })
        assertEquals(listOf(PatternUse(2, 0), PatternUse(4, 2)), s.patterns[1].here)
        assertTrue(s.patterns[0].unused); assertTrue(s.patterns[1].saved)
        assertEquals("52 kept · 12 free · 3 unused", s.countsText())
        assertNull(lupeJson.decodeFromString<PatternsState>("""{"free":0,"kept":64,"unused":0,"patterns":[]}""").recycle)
    }

    @Test fun thePicturesAreaDecodes() {
        val p = lupeJson.decodeFromString<PatternPictures>("""{"pictures":[{"number":7,"len":4,"drums":false,"notes":[60,-1,-1,67],"hits":[0,0,0,0],"live":true}]}""")
        assertEquals(listOf(60, -1, -1, 67), p.pictures[0].notes); assertTrue(p.pictures[0].live)
    }

    @Test fun theIntentsAreTheCoresJson() {
        fun enc(i: Intent) = lupeJson.encodeToString(Intent.serializer(), i)
        assertEquals("""{"intent":"patternsOpen","open":true}""", enc(PatternsOpen(true)))
        assertEquals("""{"intent":"clearPatterns","numbers":[7,12],"confirmed":true}""", enc(ClearPatterns(listOf(7, 12), confirmed = true)))
        assertEquals("""{"intent":"recyclePattern","track":2,"entry":5}""", enc(RecyclePattern(2, 5)))
        assertEquals("""{"intent":"copyPattern","number":7,"track":3,"entry":4}""", enc(CopyPattern(7, 3, 4)))
    }

    @Test fun theFiltersPickTheRightCards() {
        val s = state()
        assertEquals(listOf(3, 7), s.filtered(PatternFilter.All).map { it.number })
        assertEquals(listOf(3), s.filtered(PatternFilter.Unused).map { it.number })
        assertEquals(listOf(7), s.filtered(PatternFilter.ThisProject).map { it.number })
    }

    @Test fun aUsedCardSaysWhereItIsUsed() {
        val s = state()
        assertEquals("Pattern 07 is used by T2 A · T4 C and a saved project, so it can't be cleared.", usedWhere(s.patterns[1]))
        assertEquals("Pattern 09 is used by a saved project, so it can't be cleared.", usedWhere(PoolPattern(9, 16, 1, emptyList(), emptyList(), true, false)))
        assertEquals("Pattern 10 is used by something on the FM-1, so it can't be cleared.", usedWhere(PoolPattern(10, 16, 2)))
        assertEquals("T2 A · T4 C", usesText(s.patterns[1].here)); assertEquals("1 · E", padName(1, 4))
        assertEquals(2, firstUserTrack(s.patterns[1])); assertNull(firstUserTrack(s.patterns[0]))
    }

    @Test fun theConfirmListsTheNumbersAndSaysItCannotBeUndone() {
        assertEquals("Clear 3 patterns?", clearQuestion(3)); assertEquals("Clear 1 pattern?", clearQuestion(1))
        assertEquals("03, 12, 15 · nothing uses them · can't be undone", clearNumbers(listOf(15, 3, 12)))
        assertEquals("01, 02, 03, 04, 05, 06, 07, 08 and 2 more · nothing uses them · can't be undone", clearNumbers((1..10).toList()))
    }

    @Test fun aPicturesMarksSitByPitchOrByHits() {
        val notes = stepMarks(PatternPicture(1, 4, false, listOf(60, -1, 72, 66)))
        assertEquals(listOf(0, 2, 3), notes.map { it.first })
        assertEquals(1f, notes[0].second, 0f); assertEquals(0f, notes[1].second, 0f)             // the lowest note is at the foot (1), the highest at the top (0)
        assertTrue(stepMarks(PatternPicture(2, 4, false, listOf(-1, -1, -1, -1))).isEmpty())
        val hits = stepMarks(PatternPicture(3, 4, true, emptyList(), listOf(2, 0, 1, 0)))
        assertEquals(listOf(0, 2), hits.map { it.first })
        assertTrue(hits[0].second < hits[1].second)                                                // more hits sit higher
    }
}
