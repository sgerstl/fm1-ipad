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
        // HOME on the Timeline stays there (Scott, 2026-11-17: HOME goes to the last of Pads and Timeline; it used to restore Pads here)
        assertTrue(f.follow(s("HOME"), PlaceNow(Tab.Timeline)).isEmpty())
    }

    /** HOME goes back to the last of Pads and Timeline, however the phone got to Mix or Edit (Scott, 2026-11-17). */
    @Test fun homeReturnsToTheLastOfPadsAndTimeline() {
        val f = primed()
        f.noteTab(Tab.Timeline); f.noteTab(Tab.Mix)                                  // the phone's own taps: Timeline, then Mix
        assertTrue(f.follow(s("GLO", 30, "MIXER"), PlaceNow(Tab.Mix)).isEmpty())   // a Mix pick sends the FM-1 to GLO: already there
        assertEquals(listOf(PlaceAction.Tab(Tab.Timeline)), f.follow(s("HOME"), PlaceNow(Tab.Mix)))
        f.noteTab(Tab.Pads); f.noteTab(Tab.Edit)
        assertTrue(f.follow(s("SEQ", 41, "NOTES"), PlaceNow(Tab.Edit)).isEmpty())
        assertEquals(listOf(PlaceAction.Tab(Tab.Pads)), f.follow(s("HOME"), PlaceNow(Tab.Edit)))
    }

    @Test fun homeOnPadsOrTimelineStaysPutAndAPhoneHomeMovesNoTab() {
        val f = primed()
        assertTrue(f.follow(s("SEQ", 50, "SONG"), PlaceNow(Tab.Timeline)).isEmpty())
        assertTrue(f.follow(s("HOME"), PlaceNow(Tab.Timeline)).isEmpty())           // on Timeline: stays
        f.noteTab(Tab.Edit)
        assertTrue(f.follow(s("ENV", 10, "ENV"), PlaceNow(Tab.Edit)).isEmpty())
        assertTrue(f.follow(s("HOME"), PlaceNow(Tab.Edit, homeAsked = true)).isEmpty())   // the phone closed the panel: Edit stays
    }

    @Test fun homeGoesToPadsWhenNeitherWasSeen() {
        val f = PlaceFollower().also { it.follow(s("GLO", 30, "MIXER"), PlaceNow(Tab.Mix)) }
        assertEquals(listOf(PlaceAction.Tab(Tab.Pads)), f.follow(s("HOME"), PlaceNow(Tab.Mix)))
    }
}
