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
        assertEquals(listOf(PlaceAction.OpenSounds, PlaceAction.SoundsView(user = true)), f.follow(s("SAVE", 36, "USER"), PlaceNow(Tab.Pads)))   // a real change after that follows
        f.reset()
        assertTrue(f.follow(s("SAVE", 35, "PRESETS"), PlaceNow(Tab.Pads)).isEmpty())
    }

    /** Hybrid UI (2026-11-17, superseding decision 44): GLO's DELAY, REVERB, CHORUS and GLOBAL are the Mix tab's sub-pages; the follower takes the phone there. */
    @Test fun gloBusPagesTakeThePhoneToTheMixTab() {
        val f = primed()
        assertEquals(listOf(PlaceAction.Tab(Tab.Mix)), f.follow(s("GLO", 31, "DELAY"), PlaceNow(Tab.Timeline)))
        assertTrue(f.follow(s("GLO", 33, "CHORUS"), PlaceNow(Tab.Mix)).isEmpty())
        assertEquals(listOf(PlaceAction.Tab(Tab.Timeline)), f.follow(s("HOME"), PlaceNow(Tab.Mix)))
    }

    /** GLO 1/5 MIXER is the Mix tab. */
    @Test fun gloOnItsMixerPageTakesThePhoneToTheMixTab() {
        val f = primed()
        assertEquals(listOf(PlaceAction.Tab(Tab.Mix)), f.follow(s("GLO", 30, "MIXER"), PlaceNow(Tab.Pads)))
        // on to DELAY: the tab stays; its sub-page follows the core's mix area
        assertTrue(f.follow(s("GLO", 31, "DELAY"), PlaceNow(Tab.Mix)).isEmpty())
        // HOME puts the phone back on the tab it was on
        assertEquals(listOf(PlaceAction.Tab(Tab.Pads)), f.follow(s("HOME"), PlaceNow(Tab.Mix)))
    }

    @Test fun saveSwitchesBetweenTheSoundsSheetAndProjects() {
        val f = primed()
        assertEquals(listOf(PlaceAction.OpenSounds, PlaceAction.SoundsView(user = false)), f.follow(s("SAVE", 35, "PRESETS"), PlaceNow(Tab.Pads)))
        assertEquals(listOf(PlaceAction.SoundsView(user = true)), f.follow(s("SAVE", 36, "USER"), PlaceNow(Tab.Pads, soundsOpen = true)))
        assertEquals(listOf(PlaceAction.CloseSounds), f.follow(s("SAVE", 37, "PATTERNS"), PlaceNow(Tab.Pads, soundsOpen = true)))
        f.follow(s("SAVE", 36, "USER"), PlaceNow(Tab.Pads))
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
