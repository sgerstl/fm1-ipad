package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.Fm1ScreenState
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.shell.PlaceAction
import com.scottgerstl.lupe.ui.shell.PlaceFollower
import com.scottgerstl.lupe.ui.shell.PlaceNow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaceFollowerTest {
    private fun s(key: String, page: Int = -1, title: String = "") = Fm1ScreenState(key = key, page = page, title = title)
    private fun primed() = PlaceFollower().also { it.follow(s("HOME"), PlaceNow(Tab.Pads)) }   // the baseline

    @Test fun theFirstScreenAfterStartOrReconnectOnlySetsTheBaseline() {
        val f = PlaceFollower()
        // a restart with the FM-1 on SAVE's PRESETS, or a reconnect passing through it: nothing opens
        assertTrue(f.follow(s("SAVE", 35, "PRESETS"), PlaceNow(Tab.Pads)).isEmpty())
        assertEquals(listOf(PlaceAction.OpenSounds), f.follow(s("SAVE", 36, "USER"), PlaceNow(Tab.Pads)))   // a real change after that follows
        f.reset()
        assertTrue(f.follow(s("SAVE", 35, "PRESETS"), PlaceNow(Tab.Pads)).isEmpty())
    }

    @Test fun gloOpensTheMixSheetAndHomeClosesIt() {
        val f = primed()
        assertEquals(listOf(PlaceAction.OpenMix), f.follow(s("GLO", 30, "MIXER"), PlaceNow(Tab.Timeline)))
        assertTrue(f.follow(s("GLO", 33, "CHORUS"), PlaceNow(Tab.Timeline, mixOpen = true)).isEmpty())   // within GLO: the section follows the core
        assertEquals(listOf(PlaceAction.CloseMix), f.follow(s("HOME"), PlaceNow(Tab.Timeline, mixOpen = true)))
    }

    @Test fun aMixSheetThePersonOpenedIsLeftOpen() {
        val f = primed()
        assertTrue(f.follow(s("GLO", 30, "MIXER"), PlaceNow(Tab.Pads, mixOpen = true)).isEmpty())
        assertTrue(f.follow(s("HOME"), PlaceNow(Tab.Pads, mixOpen = true)).isEmpty())
    }

    @Test fun saveSwitchesBetweenTheSoundsSheetAndProjects() {
        val f = primed()
        assertEquals(listOf(PlaceAction.OpenSounds), f.follow(s("SAVE", 35, "PRESETS"), PlaceNow(Tab.Pads)))
        assertTrue(f.follow(s("SAVE", 36, "USER"), PlaceNow(Tab.Pads, soundsOpen = true)).isEmpty())
        assertEquals(listOf(PlaceAction.CloseSounds, PlaceAction.ShowProjects), f.follow(s("SAVE", 38, "PROJECT"), PlaceNow(Tab.Pads, soundsOpen = true)))
        assertEquals(listOf(PlaceAction.CloseProjects), f.follow(s("ENV", 0, "ENV"), PlaceNow(Tab.Pads, projectsOpen = true)))
    }

    @Test fun seqSelectsTheEditTabAndHomeGoesBack() {
        val f = primed()
        assertEquals(listOf(PlaceAction.Tab(Tab.Edit)), f.follow(s("SEQ", 41, "NOTES"), PlaceNow(Tab.Pads)))
        assertEquals(listOf(PlaceAction.Tab(Tab.Pads)), f.follow(s("HOME"), PlaceNow(Tab.Edit)))
    }

    @Test fun seqAutomationOpensTheLaneAndSongTheTimeline() {
        val f = primed()
        assertEquals(listOf(PlaceAction.Tab(Tab.Edit), PlaceAction.Lane(true)), f.follow(s("SEQ", 44, "AUTOMATION"), PlaceNow(Tab.Pads)))
        assertEquals(listOf(PlaceAction.Lane(false), PlaceAction.Tab(Tab.Timeline)), f.follow(s("SEQ", 45, "SONG"), PlaceNow(Tab.Edit, lane = true)))
        assertEquals(listOf(PlaceAction.Tab(Tab.Pads)), f.follow(s("HOME"), PlaceNow(Tab.Timeline)))
    }
}
