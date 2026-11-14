package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.CoreNotice
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.core.refusalWords
import com.scottgerstl.lupe.ui.shell.RefusalModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Every refusal reaches the screen as what happened and what to do (Scott, 2026-11-14: New pattern "did nothing"). */
class RefusalTest {
    @Test fun theFullPoolSaysWhatToDo() {
        assertEquals("All 64 patterns are taken. Pick a pattern, or clear the unused ones (hold an empty slot, or the song's menu).",
            refusalWords("All 64 patterns are taken. Clear unused ones to free a number"))
        assertEquals("Stop to change this: Skiff does it only while stopped. Press Stop, then try again.", refusalWords("Stop to change this: Skiff does it only while stopped"))
        assertEquals("Something still uses that pattern: an entry, a track or a saved project. Clear those first.", refusalWords("Something still uses that pattern: an entry, a track or a saved project"))
    }

    /** P1's notices (0851007) pass through as written: the read-only one, Clear unused's answers. */
    @Test fun theCoresOwnNoticesKeepTheirWords() {
        for (t in listOf(
            "Lupe is read-only, so nothing was sent to the FM-1. Turn on Allow writes to change it.",
            "Cleared 5 unused patterns. 5 pattern numbers are free.",
            "No pattern is unused, so there is nothing to clear.",
            "Stop playback to clear unused patterns. The FM-1 only clears them while stopped.",
        )) assertEquals(t, refusalWords(t))
    }

    @Test fun aNoticeAreaDecodes() {
        val n = lupeJson.decodeFromString<CoreNotice>("""{"seq":3,"text":"All 64 patterns are taken","track":2,"entry":3}""")
        assertEquals(2, n.track); assertEquals(3, n.entry)
    }

    @Test fun itShowsUntilDismissedAndTheSameWordsShowAgain() {
        val m = RefusalModel().also { it.dismissed = 0 }
        assertFalse(m.shows(0, ""))
        assertTrue(m.shows(1, "No"))
        m.dismissed = 1
        assertFalse(m.shows(1, "No"))
        assertTrue(m.shows(2, "No"))      // refused again: it comes back
    }
}

class ClearUnusedTest {
    @org.junit.Test fun theConfirmNamesTheNumbers() {
        org.junit.Assert.assertEquals("Clears 03, 17, 22 · can't be undone", com.scottgerstl.lupe.core.clearUnusedWords(listOf(17, 3, 22)))
        org.junit.Assert.assertEquals("Clears 01, 02, 03, 04, 05, 06 and 2 more · can't be undone", com.scottgerstl.lupe.core.clearUnusedWords((1..8).toList()))
        org.junit.Assert.assertEquals("Clear 1 unused pattern…", com.scottgerstl.lupe.core.clearUnusedTitle(listOf(9)))
        org.junit.Assert.assertEquals("Clear 7 unused patterns…", com.scottgerstl.lupe.core.clearUnusedTitle((1..7).toList()))
    }

    @org.junit.Test fun theIntentIsTheCoresJson() {
        org.junit.Assert.assertEquals("""{"intent":"clearUnusedPatterns","confirmed":true}""",
            com.scottgerstl.lupe.core.lupeJson.encodeToString(com.scottgerstl.lupe.core.Intent.serializer(), com.scottgerstl.lupe.core.ClearUnusedPatterns(confirmed = true)))
    }

    @org.junit.Test fun thePadsAreaCarriesTheFreeCountAndTheUnusedOnes() {
        val p = com.scottgerstl.lupe.core.lupeJson.decodeFromString<com.scottgerstl.lupe.core.PadsState>("""{"rows":[],"scenes":[],"selected":{"track":1,"entry":0},"patternsFree":0,"unused":[3,17]}""")
        org.junit.Assert.assertEquals(0, p.patternsFree); org.junit.Assert.assertEquals(listOf(3, 17), p.unused)
    }
}
