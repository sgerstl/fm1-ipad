package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.lupeJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Where a recording goes on Pads (Scott, 2026-11-18): the core says which pad the FM-1 will keep it as, and that the track records. */
class RecordTakePadTest {
    @Test fun theRowCarriesTheTakesPad() {
        val p = lupeJson.decodeFromString(PadsState.serializer(),
            """{"rows":[{"track":5,"name":"Lofi · Piano","entries":[{"kind":"empty"},{"kind":"empty"}],"newAt":0,"recording":true}]}""")
        assertEquals(0, p.rows[0].newAt)
        assertTrue(p.rows[0].recording)
        assertEquals(null, lupeJson.decodeFromString(PadsState.serializer(), """{"rows":[{"track":1,"name":"x"}]}""").rows[0].newAt)
    }
}
