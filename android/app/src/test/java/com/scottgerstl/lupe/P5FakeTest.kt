package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.FakeP5
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.MixSectionPick
import com.scottgerstl.lupe.core.PickPreset
import com.scottgerstl.lupe.core.ProjectLoad
import com.scottgerstl.lupe.core.ProjectSave
import com.scottgerstl.lupe.core.SaveSound
import com.scottgerstl.lupe.core.SetLevel
import com.scottgerstl.lupe.core.SetPan
import com.scottgerstl.lupe.core.SoundsTargetPick
import com.scottgerstl.lupe.ui.mix.toUi
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The fake's answers for P5's areas copy P1's core's refusals, and the screens' mapping of them. */
@OptIn(ExperimentalCoroutinesApi::class)
class P5FakeTest {
    private val names = listOf("Acid", "Pad", "Pulse Ld", "Drum Kit", "Piano", "Perc Kit")

    @Test fun mixLevelPanAndSectionsMapToTheScreen() {
        var m = FakeP5.seedMix(names, 5)
        m = FakeP5.mix(m, SetLevel(1, 120)); m = FakeP5.mix(m, SetPan(2, -10)); m = FakeP5.mix(m, Intent.TrackMute(6))
        val ui = m.toUi()
        assertEquals(120, ui.tracks[0].level)
        assertEquals(54, ui.tracks[1].pan); assertEquals("L10", ui.tracks[1].panText)      // the core's −64…63 shifted to 0…127
        assertTrue(ui.tracks[5].muted); assertTrue(ui.tracks[4].selected)
        m = FakeP5.mix(m, MixSectionPick("delay"))
        assertEquals(1, m.toUi().page); assertEquals(4, m.toUi().bus.size); assertNotNull(m.card)
    }

    @Test fun projectsRefuseUnconfirmedLoadOverChangesAndSaveOverItself() {
        var p = FakeP5.seedProjects()                      // changed = true
        p = FakeP5.projects(p, ProjectLoad(1, confirmed = false)); assertTrue(p.slots[0].current)   // refused
        p = FakeP5.projects(p, ProjectSave(confirmed = false)); assertTrue(p.changed)               // refused
        p = FakeP5.projects(p, ProjectSave(confirmed = true)); assertFalse(p.changed)
        p = FakeP5.projects(p, ProjectLoad(1, confirmed = false)); assertTrue(p.slots[1].current)    // nothing to lose now
    }

    @Test fun soundsSaveOverAUsedSlotNeedsConfirmation() {
        var s = FakeP5.seedSounds(5, "Piano")
        s = FakeP5.sounds(s, SaveSound(0, "PIANO"))        // slot 0 is used
        assertEquals("USER 1", s.user[0].name); assertNotNull(s.refusal)
        s = FakeP5.sounds(s, SaveSound(0, "PIANO", confirmed = true))
        assertEquals("PIANO", s.user[0].name)
        s = FakeP5.sounds(s, SaveSound(9, "PIANO"))        // an empty slot stores at once
        assertTrue(s.user[9].used)
    }

    @Test fun aPadsOwnSoundIsSeparateFromTheTracks() {
        var s = FakeP5.seedSounds(4, "Drum Kit")
        s = FakeP5.sounds(s, SoundsTargetPick(4, 1)); s = FakeP5.sounds(s, PickPreset(10, 2))
        assertEquals("preset", s.entrySound?.kind); assertEquals(0, s.engine)                     // the track's own sound is untouched
    }

    @Test fun mixCardSettingsChange() {
        var m = FakeP5.seedMix(names, 1)
        m = FakeP5.mix(m, MixSectionPick("delay"))
        assertEquals("STEREO", m.toUi().settings.single().value)
        m = FakeP5.mix(m, com.scottgerstl.lupe.core.SetMixSetting(0, 1))
        assertEquals("PING-PONG", m.toUi().settings.single().value); assertEquals(1, m.card!!.settings.single().raw)
        assertTrue(FakeP5.mix(FakeP5.mix(m, MixSectionPick("chorus")), Intent.TrackSelect(1)).toUi().settings.isEmpty())   // chorus has none
    }

    @Test fun saveAsOverAUsedProjectSlotNeedsConfirmation() {
        var p = FakeP5.seedProjects()
        p = FakeP5.projects(p, com.scottgerstl.lupe.core.ProjectSaveAs(1, "NIGHT DRIVE"))              // slot 2 holds KOTO: refused
        assertEquals("KOTO", p.slots[1].name)
        p = FakeP5.projects(p, com.scottgerstl.lupe.core.ProjectSaveAs(1, "NIGHT DRIVE", confirmed = true))
        assertEquals("NIGHT DRIVE", p.slots[1].name); assertTrue(p.slots[1].current)
        p = FakeP5.projects(p, com.scottgerstl.lupe.core.ProjectSaveAs(2, "NEW"))                       // an empty slot: one tap
        assertEquals("NEW", p.slots[2].name)
    }

    @Test fun eraseAUserSlotNeedsConfirmation() {
        var s = FakeP5.seedSounds(5, "Piano")
        s = FakeP5.sounds(s, com.scottgerstl.lupe.core.EraseUser(0)); assertTrue(s.user[0].used); assertNotNull(s.refusal)
        s = FakeP5.sounds(s, com.scottgerstl.lupe.core.EraseUser(0, confirmed = true)); assertFalse(s.user[0].used)
    }

    @Test fun aSavedSoundSlotIsNamedForTheSoundNotTheEngine() {
        assertEquals("ACID", com.scottgerstl.lupe.ui.sounds.saveName("Analog · Acid"))
        assertEquals("PULSE LD", com.scottgerstl.lupe.ui.sounds.saveName("Lofi · Pulse Ld"))
        assertEquals("LONGNAME", com.scottgerstl.lupe.ui.sounds.saveName("Sample · Longname here"))   // 8 characters, as the FM-1 keeps
        assertEquals("PIANO", com.scottgerstl.lupe.ui.sounds.saveName("Piano"))
        assertEquals("SOUND", com.scottgerstl.lupe.ui.sounds.saveName(""))
    }

    @org.junit.Test fun theFakeCoreForwardsMixSettings() = kotlinx.coroutines.test.runTest(kotlinx.coroutines.test.StandardTestDispatcher()) {
        val dir = java.io.File("../fixtures/state")
        val scenarios = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to com.scottgerstl.lupe.core.Scenario.parse(it.nameWithoutExtension, it.readText()) }
        val core = com.scottgerstl.lupe.core.FakeLupeCore(this, scenarios, "searching"); testScheduler.advanceTimeBy(10)
        core.send(MixSectionPick("delay")); core.send(com.scottgerstl.lupe.core.SetMixSetting(0, 1))
        assertEquals("PING-PONG", core.mix.value.card!!.settings.single().value)
    }
}
