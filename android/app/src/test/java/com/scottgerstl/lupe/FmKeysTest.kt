package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.KeysState
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.ui.edit.offScreen
import org.junit.Assert.assertEquals
import org.junit.Test

/** The FM-1's held keys on Edit (Scott, 2026-11-17). */
class FmKeysTest {
    @Test fun theKeysAreaReadsByTrack() {
        val k = lupeJson.decodeFromString(KeysState.serializer(), """{"tracks":[[],[],[],[],[60,64,67],[]]}""")
        assertEquals(setOf(60, 64, 67), k.on(5))
        assertEquals(emptySet<Int>(), k.on(1))
        assertEquals(emptySet<Int>(), KeysState().on(3))      // before the first frame
    }

    @Test fun aHeldKeyOutOfViewPointsUpOrDown() {
        val vis = 55..72
        assertEquals(1, offScreen(84, vis)); assertEquals(-1, offScreen(40, vis)); assertEquals(0, offScreen(60, vis))
    }
}
