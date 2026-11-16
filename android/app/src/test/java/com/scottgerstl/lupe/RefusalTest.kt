package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.CoreNotice
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.core.refusalWords
import com.scottgerstl.lupe.core.NoticeKind
import com.scottgerstl.lupe.ui.shell.MessageKind
import com.scottgerstl.lupe.ui.shell.MessageModel
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
        assertEquals(NoticeKind.Refusal, n.kind)      // absent: a refusal, as before kinds
        assertEquals(NoticeKind.Confirmation, lupeJson.decodeFromString<CoreNotice>("""{"text":"Cleared 5 unused patterns.","kind":"confirmation"}""").kind)
        assertEquals(NoticeKind.Refusal, lupeJson.decodeFromString<CoreNotice>("""{"text":"No.","kind":"refusal"}""").kind)
    }

    @Test fun itShowsUntilDismissedAndTheSameWordsShowAgain() {
        val m = MessageModel(noticeSeen = 0)
        m.onNotice(CoreNotice(0, ""))
        assertEquals(null, m.current)
        m.onNotice(CoreNotice(1, "No."))
        val first = m.current!!
        assertEquals(MessageKind.Refusal, first.kind)
        m.onNotice(CoreNotice(1, "No."))              // the same notice republished: not news
        assertEquals(first, m.current)
        m.dismiss(first.id)
        assertEquals(null, m.current)
        m.onNotice(CoreNotice(2, "No."))              // refused again: it comes back
        assertTrue(m.current != null && m.current!!.id != first.id)
    }

    @Test fun aNoticeFromBeforeTheScreenOpenedIsNotNews() {
        val m = MessageModel(noticeSeen = 4)
        m.onNotice(CoreNotice(4, "Old."))
        assertEquals(null, m.current)
    }
}

/** Scott, 2026-11-17, messages rule: one strip, one message at a time, each kind with its own lifetime. */
class MessageStripTest {
    @Test fun aConfirmationIsItsOwnKind() {
        val m = MessageModel()
        m.onNotice(CoreNotice(1, "Cleared 5 unused patterns. 5 pattern numbers are free.", kind = NoticeKind.Confirmation))
        assertEquals(MessageKind.Confirmation, m.current?.kind)
        assertEquals("Cleared 5 unused patterns.", m.current?.line)
        assertEquals("5 pattern numbers are free.", m.current?.detail)
        assertEquals(4000L, com.scottgerstl.lupe.ui.shell.CONFIRMATION_MS)
    }

    @Test fun aNewMessageReplacesTheOldNeverTwo() {
        val m = MessageModel()
        m.onNotice(CoreNotice(1, "Stop to rearrange: the FM-1 moves pads only while stopped. Press Stop, then try again."))
        val a = m.current!!
        m.refuse("Scene 3 is empty. Tap Store scene, then a scene, to keep what plays now.", fix = "scene:2")
        assertEquals("scene:2", m.current?.fix)
        m.dismiss(a.id)                                // ✕ on the old one, already replaced: the new one stays
        assertEquals("scene:2", m.current?.fix)
    }

    @Test fun aRefusalLeavesWhenFixedAndNotBefore() {
        val m = MessageModel()
        m.refuse("Scene 3 is empty. Tap Store scene, then a scene, to keep what plays now.", fix = "scene:2")
        m.fixed { it == "scene:5" }
        assertTrue(m.current != null)
        m.fixed { it == "scene:2" }
        assertEquals(null, m.current)
        // the full pool: leaves once a number is free, and carries the Patterns key
        m.onNotice(CoreNotice(1, "All 64 patterns are taken. Pick a pattern, or clear the unused ones (hold an empty slot, or the song's menu)."))
        assertTrue(m.current!!.opensPatterns)
        m.onPatternsFree(0)
        assertTrue(m.current != null)
        m.onPatternsFree(3)
        assertEquals(null, m.current)
    }

    @Test fun undoLastsUntilTheNextEditEndsItInTheCore() {
        val a = com.scottgerstl.lupe.core.ClearedPad(2, 5, 7)
        val b = com.scottgerstl.lupe.core.ClearedPad(3, 0)
        val m = MessageModel()
        m.onClearUndo(listOf(a))
        assertEquals(MessageKind.Undo, m.current?.kind)
        assertEquals("Cleared T2 pad F · pattern 07", m.current?.text)
        assertEquals(null, m.current?.detail)
        m.onClearUndo(listOf(a))                       // republished: still the same one, no replacement
        val shown = m.current!!
        // the next clear: the core ended A and offers B
        m.onClearUndo(listOf(b))
        assertEquals(b, m.current?.undo)
        assertTrue(m.current!!.id != shown.id)
        // the next edit ended B in the core: the strip's Undo goes with it
        m.onClearUndo(emptyList())
        assertEquals(null, m.current)
        // the same pad cleared again later is offered again
        m.onClearUndo(listOf(b))
        assertEquals(b, m.current?.undo)
    }

    @Test fun aRefusalAfterAClearReplacesTheUndoAndTheMenuKeepsIt() {
        val a = com.scottgerstl.lupe.core.ClearedPad(2, 5, 7)
        val m = MessageModel()
        m.onClearUndo(listOf(a))
        m.onNotice(CoreNotice(1, "Stop playback to clear a pad that holds a pattern. The FM-1 only clears one while stopped."))
        assertEquals(MessageKind.Refusal, m.current?.kind)
        m.onClearUndo(listOf(a))                       // still open in the core (the pad's menu offers it): not offered again here
        assertEquals(MessageKind.Refusal, m.current?.kind)
    }

    @Test fun theSongEditsMatchTheCore() {
        assertTrue(com.scottgerstl.lupe.core.isSongEdit(com.scottgerstl.lupe.core.Intent.PadClear(1, 0)))
        assertFalse(com.scottgerstl.lupe.core.isSongEdit(com.scottgerstl.lupe.core.UndoClear()))
        assertFalse(com.scottgerstl.lupe.core.isSongEdit(com.scottgerstl.lupe.core.Intent.Play))
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
