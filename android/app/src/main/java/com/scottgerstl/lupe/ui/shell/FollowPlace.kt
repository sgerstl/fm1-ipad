package com.scottgerstl.lupe.ui.shell

import com.scottgerstl.lupe.core.Fm1ScreenState
import com.scottgerstl.lupe.core.Tab

sealed interface PlaceAction {
    data class Tab(val tab: com.scottgerstl.lupe.core.Tab) : PlaceAction
    /** The Edit tab's one-lane view, in the keyboard's place. */
    data class Lane(val on: Boolean) : PlaceAction
    data object OpenMix : PlaceAction
    /** The Sounds sheet's list, as the FM-1's SAVE page: USER's slots, or the presets. */
    data class SoundsView(val user: Boolean) : PlaceAction
    data object CloseMix : PlaceAction
    data object OpenSounds : PlaceAction
    data object CloseSounds : PlaceAction
    data object ShowProjects : PlaceAction
    data object CloseProjects : PlaceAction
}

/** What is open on the phone now, as the follower needs it. */
data class PlaceNow(val tab: Tab, val lane: Boolean = false, val mixOpen: Boolean = false, val soundsOpen: Boolean = false, val projectsOpen: Boolean = false)

/**
 * The phone follows the FM-1's own GLO, SAVE and SEQ (decisions 24, 27, 28): for GLO the Mix tab on its MIXER page and the Mix sheet on
 * DELAY, REVERB, CHORUS and GLOBAL (its section follows the core's own `mix` area), the Sounds sheet for SAVE's PRESETS and USER or Projects for PROJECT, the Edit tab for SEQ, with AUTOMATION to its lane view and
 * SONG to the Timeline tab. HOME, or a sound family, puts it back as it was: it closes what it opened and restores the tab and the lane
 * view it changed. It closes only what it opened itself. The first screen it sees after start or a reconnect is only the baseline.
 */
class PlaceFollower {
    private var savedTab: Tab? = null
    private var savedLane: Boolean? = null
    private var ownMix = false
    private var ownSounds = false
    private var ownProjects = false
    private var last: Fm1ScreenState? = null
    private var primed = false

    /** The link dropped: the next screen it sees is a new baseline. */
    fun reset() { last = null; primed = false }

    fun follow(screen: Fm1ScreenState, now: PlaceNow): List<PlaceAction> {
        if (screen == last) return emptyList()
        last = screen
        // the first screen seen after start or reconnect only sets the baseline: nothing opens for where the FM-1 already was
        if (!primed) { primed = true; return emptyList() }
        val out = mutableListOf<PlaceAction>()
        var tab = now.tab
        fun goTab(t: Tab) { if (savedTab == null) savedTab = now.tab; if (tab != t) { out += PlaceAction.Tab(t); tab = t } }
        fun mix(open: Boolean) {
            if (open && !now.mixOpen) { out += PlaceAction.OpenMix; ownMix = true }
            if (!open && ownMix) { if (now.mixOpen) out += PlaceAction.CloseMix; ownMix = false }
        }
        fun sounds(open: Boolean) {
            if (open && !now.soundsOpen) { out += PlaceAction.OpenSounds; ownSounds = true }
            if (!open && ownSounds) { if (now.soundsOpen) out += PlaceAction.CloseSounds; ownSounds = false }
        }
        fun projects(open: Boolean) {
            if (open && !now.projectsOpen) { out += PlaceAction.ShowProjects; ownProjects = true }
            if (!open && ownProjects) { if (now.projectsOpen) out += PlaceAction.CloseProjects; ownProjects = false }
        }
        fun lane(on: Boolean) {
            if (on) { if (savedLane == null) savedLane = now.lane; if (!now.lane) out += PlaceAction.Lane(true) }
            else { savedLane?.let { if (it != now.lane) out += PlaceAction.Lane(it) }; savedLane = null }
        }
        fun restoreTab() { savedTab?.let { if (it != tab) { out += PlaceAction.Tab(it); tab = it } }; savedTab = null }
        when (screen.key) {
            // every GLO page: the sheet, re-opened if it was dismissed. Its section is the core's own: the `mix` area follows the FM-1's GLO page
            // by itself (P1), so the phone sends nothing for it (a send could pull the FM-1 back a page)
            // the MIXER page is the Mix tab now (batch item 11); DELAY, REVERB, CHORUS and GLOBAL are the pop-up
            // decision 44: MIXER is the Mix tab; DELAY, REVERB, CHORUS and GLOBAL are the docked sound panel's pages (it opens by itself on the page change), so nothing opens here
            "GLO" -> { sounds(false); projects(false); lane(false); mix(false); if (screen.title == "MIXER") goTab(Tab.Mix) }
            "SAVE" -> { mix(false); lane(false); when (screen.title) {
                "PRESETS", "USER" -> { projects(false); sounds(true); out += PlaceAction.SoundsView(user = screen.title == "USER") }
                "PROJECT" -> { sounds(false); projects(true) }
                else -> { sounds(false); projects(false) }
            } }
            "SEQ" -> { mix(false); sounds(false); projects(false); when (screen.title) {
                "SONG" -> { lane(false); goTab(Tab.Timeline) }
                "AUTOMATION" -> { goTab(Tab.Edit); lane(true) }
                else -> { lane(false); goTab(Tab.Edit) }
            } }
            else -> { mix(false); sounds(false); projects(false); lane(false); restoreTab() }   // HOME, a sound family: back to where the phone was
        }
        return out
    }

}
