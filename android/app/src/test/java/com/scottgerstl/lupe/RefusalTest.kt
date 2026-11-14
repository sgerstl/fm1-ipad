package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.CoreNotice
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.core.refusalFromLog
import com.scottgerstl.lupe.core.refusalWords
import com.scottgerstl.lupe.ui.shell.RefusalModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Every refusal reaches the screen as what happened and what to do (Scott, 2026-11-14: New pattern "did nothing"). */
class RefusalTest {
    @Test fun theFullPoolSaysWhatToDo() {
        // the line the Pixel 10 logged
        assertEquals("All 64 patterns are taken. Pick a pattern, or clear unused ones on the FM-1.",
            refusalFromLog("FM-1 refused: All 64 patterns are taken. Clear unused ones to free a number"))
    }

    @Test fun theCoresOtherRefusalsShowToo() {
        assertEquals("Stop to change this: Skiff does it only while stopped. Press Stop, then try again.", refusalFromLog("FM-1 refused: Stop to change this: Skiff does it only while stopped"))
        assertEquals("FM-1 refused the save (rc 2).", refusalFromLog("FM-1 refused the save (rc 2)"))
        assertEquals("The FM-1 refused the stroke while the song plays.", refusalFromLog("the FM-1 refused the stroke while the song plays"))
        assertTrue(refusalFromLog("read-only: padNew(track: 1, entry: 3) not sent (allow writes to send it)")!!.startsWith("Lupe is read-only on this phone"))
        assertEquals("Something still uses that pattern: an entry, a track or a saved project. Clear those first.", refusalWords("Something still uses that pattern: an entry, a track or a saved project"))
    }

    @Test fun ordinaryLogLinesAreNotRefusals() {
        assertNull(refusalFromLog("Swift loaded; main actor hooked to the UI thread's Looper"))
        assertNull(refusalFromLog("lag kotlin tap +12 ms: sent"))
        assertNull(refusalFromLog("clock: atMs 1, uptimeMillis 2, apart 1 ms"))
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
