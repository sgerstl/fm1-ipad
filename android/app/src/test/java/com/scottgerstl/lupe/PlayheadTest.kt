package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.PlayheadState
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.core.withPlayhead
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The `playhead` area (P1, 2026-11-15) and how the editor gets its playing step from it. */
class PlayheadTest {
    @Test fun p1sFrameDecodes() {
        val p = lupeJson.decodeFromString(PlayheadState.serializer(), """{"track":2,"step":35,"steps":40,"direction":0,"startTick":840.0,"nextTick":846.0}""")
        assertEquals(2, p.track); assertEquals(35, p.step); assertEquals(40, p.steps); assertEquals(840.0, p.startTick!!, 0.0); assertEquals(846.0, p.nextTick!!, 0.0)
        assertEquals(35 / 16, 2)                                                    // step 35 is in the third chunk
    }

    @Test fun aRandFrameHasNoTicks() {
        val p = lupeJson.decodeFromString(PlayheadState.serializer(), """{"track":1,"step":-1,"steps":16,"direction":3}""")
        assertEquals(-1, p.step); assertNull(p.startTick); assertNull(p.nextTick)
    }

    @Test fun theEditorTakesItsPlayingStepFromTheAreaForItsOwnTrack() {
        val ed = EditorState(track = 2)
        assertEquals(35, ed.withPlayhead(PlayheadState(track = 2, step = 35, steps = 40)).playhead)
        assertEquals(-1, ed.withPlayhead(PlayheadState(track = 3, step = 5)).playhead)       // another track's frame
        assertEquals(-1, ed.withPlayhead(PlayheadState(track = 2, step = -1)).playhead)      // stopped
        assertEquals(7, ed.copy(playhead = 7).withPlayhead(PlayheadState()).playhead)       // no frame yet: a recorded scenario's own stands
        assertEquals(-1, ed.copy(playhead = 7).withPlayhead(PlayheadState(track = 2, step = -1)).playhead)
    }
}
