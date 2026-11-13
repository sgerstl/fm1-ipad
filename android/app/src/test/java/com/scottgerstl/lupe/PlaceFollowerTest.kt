package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.Divider
import com.scottgerstl.lupe.core.Fm1ScreenState
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.shell.PlaceAction
import com.scottgerstl.lupe.ui.shell.PlaceFollower
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaceFollowerTest {
    private fun s(key: String, page: Int = -1, title: String = "") = Fm1ScreenState(key = key, page = page, title = title)

    @Test fun theFirstScreenAfterStartOrReconnectOnlySetsTheBaseline() {
        val f = PlaceFollower()
        // a restart with the FM-1 on SAVE's PRESETS, or a reconnect passing through it: nothing opens
        assertTrue(f.follow(s("SAVE", 35, "PRESETS"), Tab.Pads, Divider.Split, false, false).isEmpty())
        assertEquals(listOf(PlaceAction.OpenSounds), f.follow(s("SAVE", 36, "USER"), Tab.Pads, Divider.Split, false, false))   // a real change after that follows
        f.reset()
        assertTrue(f.follow(s("SAVE", 35, "PRESETS"), Tab.Pads, Divider.Split, false, false).isEmpty())
    }

    @Test fun gloOpensMixAndHomeRestoresTheTabTheUserHad() {
        val f = PlaceFollower().also { it.follow(s("HOME"), Tab.Pads, Divider.Split, false, false) }   // the baseline
        assertEquals(listOf(PlaceAction.Tab(Tab.Mix)), f.follow(s("GLO", 30, "MIXER"), Tab.Timeline, Divider.Split, false, false))
        assertTrue(f.follow(s("GLO", 33, "CHORUS"), Tab.Mix, Divider.Split, false, false).isEmpty())   // within GLO: the Mix section follows the core
        assertEquals(listOf(PlaceAction.Tab(Tab.Timeline)), f.follow(s("HOME"), Tab.Mix, Divider.Split, false, false))
    }

    @Test fun saveSwitchesBetweenTheSoundsSheetAndProjects() {
        val f = PlaceFollower().also { it.follow(s("HOME"), Tab.Pads, Divider.Split, false, false) }   // the baseline
        assertEquals(listOf(PlaceAction.OpenSounds), f.follow(s("SAVE", 35, "PRESETS"), Tab.Pads, Divider.Split, false, false))
        assertTrue(f.follow(s("SAVE", 36, "USER"), Tab.Pads, Divider.Split, true, false).isEmpty())
        assertEquals(listOf(PlaceAction.CloseSounds, PlaceAction.ShowProjects), f.follow(s("SAVE", 38, "PROJECT"), Tab.Pads, Divider.Split, true, false))
        assertEquals(listOf(PlaceAction.CloseProjects), f.follow(s("ENV", 0, "ENV"), Tab.Pads, Divider.Split, false, true))
    }

    @Test fun seqAutomationGoesToTheLaneAndBack() {
        val f = PlaceFollower().also { it.follow(s("HOME"), Tab.Pads, Divider.Split, false, false) }   // the baseline
        assertEquals(listOf(PlaceAction.Divider(Divider.Bottom)), f.follow(s("SEQ", 44, "AUTOMATION"), Tab.Pads, Divider.Split, false, false))
        assertEquals(listOf(PlaceAction.Divider(Divider.Split)), f.follow(s("HOME"), Tab.Pads, Divider.Bottom, false, false))
    }

    @Test fun seqSongGoesToTheTimeline() {
        val f = PlaceFollower().also { it.follow(s("HOME"), Tab.Pads, Divider.Split, false, false) }   // the baseline
        assertEquals(listOf(PlaceAction.Tab(Tab.Timeline)), f.follow(s("SEQ", 45, "SONG"), Tab.Mix, Divider.Split, false, false))
        assertEquals(listOf(PlaceAction.Tab(Tab.Mix)), f.follow(s("SEQ", 41, "NOTES"), Tab.Timeline, Divider.Split, false, false))
    }

    @Test fun homePutsBackTheSavedTabAndLeavesAnOwnSheetAlone() {
        val f = PlaceFollower().also { it.follow(s("HOME"), Tab.Pads, Divider.Split, false, false) }   // the baseline
        f.follow(s("GLO", 30, "MIXER"), Tab.Pads, Divider.Split, false, false)
        // the person went to Timeline themselves, then the FM-1 goes HOME: the tab saved before GLO (Pads) is restored
        assertEquals(listOf(PlaceAction.Tab(Tab.Pads)), f.follow(s("HOME"), Tab.Timeline, Divider.Split, false, false))
        // the sounds browser the person opened is not closed by a HOME they didn't ask for
        assertTrue(f.follow(s("ENV", 0, "ENV"), Tab.Pads, Divider.Split, true, false).isEmpty())
    }
}
