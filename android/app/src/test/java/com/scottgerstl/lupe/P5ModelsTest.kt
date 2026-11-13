package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.mix.MockMix
import com.scottgerstl.lupe.ui.projects.MockProjects
import com.scottgerstl.lupe.ui.sounds.MockSounds
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The stand-in models behind the P5 screens answer their actions, so the screens can be driven by hand. (P1's areas replace them.) */
class P5ModelsTest {
    @Test fun mixLevelPanAndMute() {
        val m = MockMix()
        m.actions.level(1, 120); assertEquals(120, m.ui.tracks[0].level)
        m.actions.pan(2, 10); assertEquals("L54", m.ui.tracks[1].panText)
        m.actions.mute(6); assertFalse(m.ui.tracks[5].muted)   // track 6 starts muted: the tap un-mutes it
        m.actions.select(3); assertTrue(m.ui.tracks[2].selected); assertFalse(m.ui.tracks[4].selected)
    }
    @Test fun projectsLoadClearsTheChanges() {
        val p = MockProjects()
        assertTrue(p.ui.changes != null)
        p.actions.load(2)
        assertNull(p.ui.changes); assertTrue(p.ui.slots[1].current); assertFalse(p.ui.slots[0].current)
        p.actions.saveAs(3, "Fresh"); assertEquals("Fresh", p.ui.slots[2].name); assertFalse(p.ui.slots[2].empty)
    }
    @Test fun soundsPickAndPadOverride() {
        val s = MockSounds()
        s.actions(5).pickPreset(0, 2); assertEquals(0 to 2, s.ui(5, "Piano", null).let { it.engine to it.preset })
        s.actions(4).setPadSound("B", 0, 1)
        assertEquals("ANALOG BASS", s.ui(4, "Drum Kit", "B").padSounds["B"])
        assertEquals(4, s.ui(4, "Drum Kit", null).kits.size)     // kits only on the drum track
        assertTrue(s.ui(5, "Piano", null).kits.isEmpty())
    }
}
