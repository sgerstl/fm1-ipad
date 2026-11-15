package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.ClearedPad
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.UndoClear
import com.scottgerstl.lupe.core.clearedWords
import com.scottgerstl.lupe.core.lupeJson
import org.junit.Assert.assertEquals
import org.junit.Test

/** Batch item 13: clear a pad without confirming, with Undo (P1's 2ea3f0c shapes). */
class UndoClearTest {
    private fun enc(i: Intent) = lupeJson.encodeToString(Intent.serializer(), i)

    @Test fun theIntentIsTheCoresJson() {
        assertEquals("""{"intent":"undoClear"}""", enc(UndoClear()))                                    // the last clear
        assertEquals("""{"intent":"undoClear","track":2,"entry":5}""", enc(UndoClear(2, 5)))              // that pad's
    }

    @Test fun thePadsAreaCarriesTheListOfClearsThatCanComeBack() {
        val p = lupeJson.decodeFromString<PadsState>("""{"rows":[],"scenes":[],"selected":{"track":1,"entry":0},"clearUndo":[{"track":2,"entry":5,"pattern":7},{"track":3,"entry":0}]}""")
        assertEquals(listOf(ClearedPad(2, 5, 7), ClearedPad(3, 0, null)), p.clearUndo)
        assertEquals(emptyList<ClearedPad>(), lupeJson.decodeFromString<PadsState>("""{"rows":[],"scenes":[],"selected":{"track":1,"entry":0}}""").clearUndo)
    }

    @Test fun theStripSaysWhichPadAndWhatComesBack() {
        assertEquals("Cleared T2 pad F · pattern 07", clearedWords(ClearedPad(2, 5, 7)))
        assertEquals("Cleared T3 pad A · REST", clearedWords(ClearedPad(3, 0)))
    }
}

class BlockUndoTest {
    @Test fun aBlocksUndoCarriesItsFlagAndItsWords() {
        val p = lupeJson.decodeFromString<PadsState>("""{"rows":[],"scenes":[],"selected":{"track":1,"entry":0},"clearUndo":[{"track":2,"entry":4,"pattern":7,"block":true},{"track":2,"entry":5,"block":false}]}""")
        assertEquals(listOf(ClearedPad(2, 4, 7, true), ClearedPad(2, 5, null, false)), p.clearUndo)
        assertEquals("Deleted T2 block E · pattern 07", clearedWords(p.clearUndo[0]))
        assertEquals("Cleared T2 pad F · REST", clearedWords(p.clearUndo[1]))
        assertEquals("Cleared T2 pad D's notes · pattern 07", clearedWords(ClearedPad(2, 3, 7, kind = "steps")))
    }

    @Test fun theUndoForABlockIsTheSameIntent() {
        assertEquals("""{"intent":"undoClear","track":2,"entry":4}""", lupeJson.encodeToString(Intent.serializer(), UndoClear(2, 4)))
        assertEquals("""{"intent":"blockDelete","track":2,"block":4}""", lupeJson.encodeToString(Intent.serializer(), com.scottgerstl.lupe.core.BlockDelete(2, 4)))
    }
}
