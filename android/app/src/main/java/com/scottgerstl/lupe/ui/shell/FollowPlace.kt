package com.scottgerstl.lupe.ui.shell

import com.scottgerstl.lupe.core.Divider
import com.scottgerstl.lupe.core.Fm1ScreenState
import com.scottgerstl.lupe.core.Tab

sealed interface PlaceAction {
    data class Tab(val tab: com.scottgerstl.lupe.core.Tab) : PlaceAction
    data class Divider(val position: com.scottgerstl.lupe.core.Divider) : PlaceAction
    data object OpenSounds : PlaceAction
    data object CloseSounds : PlaceAction
    data object ShowProjects : PlaceAction
    data object CloseProjects : PlaceAction
}

/**
 * The phone follows the FM-1's own GLO, SAVE and SEQ (decision 24, followed): the Mix tab for GLO (its section follows the core's own `mix` area),
 * the Sounds sheet for SAVE's PRESETS and USER or Projects for PROJECT, the editor for SEQ, with AUTOMATION to the lane (bottom full) and
 * SONG to the Timeline. HOME, or a sound family, puts it back as it was: it closes what it opened and restores the top tab and the
 * divider it changed. It closes only what it opened itself; the tab and divider it saved are put back even if the person moved them since (they asked for the screen the FM-1 left).
 */
class PlaceFollower {
    private var savedTab: Tab? = null
    private var savedDivider: Divider? = null
    private var ownSounds = false
    private var ownProjects = false
    private var last: Fm1ScreenState? = null

    fun follow(screen: Fm1ScreenState, tab: Tab, divider: Divider, soundsOpen: Boolean, projectsOpen: Boolean): List<PlaceAction> {
        if (screen == last) return emptyList()
        last = screen
        val out = mutableListOf<PlaceAction>()
        fun goTab(t: Tab) { if (savedTab == null) savedTab = tab; if (tab != t) out += PlaceAction.Tab(t) }
        fun sounds(open: Boolean) {
            if (open && !soundsOpen) { out += PlaceAction.OpenSounds; ownSounds = true }
            if (!open && ownSounds) { if (soundsOpen) out += PlaceAction.CloseSounds; ownSounds = false }
        }
        fun projects(open: Boolean) {
            if (open && !projectsOpen) { out += PlaceAction.ShowProjects; ownProjects = true }
            if (!open && ownProjects) { if (projectsOpen) out += PlaceAction.CloseProjects; ownProjects = false }
        }
        fun restore(keepTab: Boolean = false, keepDivider: Boolean = false) {
            sounds(false); projects(false)
            if (!keepTab) { savedTab?.let { if (it != tab) out += PlaceAction.Tab(it) }; savedTab = null }
            if (!keepDivider) { savedDivider?.let { if (it != divider) out += PlaceAction.Divider(it) }; savedDivider = null }
        }
        when (screen.key) {
            "GLO" -> { restore(keepTab = true); goTab(Tab.Mix) }
            "SAVE" -> when (screen.title) {
                "PRESETS", "USER" -> { projects(false); restore(keepTab = true); sounds(true) }
                "PROJECT" -> { sounds(false); restore(keepTab = true); projects(true) }
                else -> restore(keepTab = true)
            }
            "SEQ" -> when (screen.title) {
                "AUTOMATION" -> { restore(keepTab = false, keepDivider = true); if (savedDivider == null) savedDivider = divider; if (divider != Divider.Bottom) out += PlaceAction.Divider(Divider.Bottom) }
                "SONG" -> { restore(keepTab = true); goTab(Tab.Timeline) }
                else -> restore()
            }
            else -> restore()   // HOME, a sound family: back to where the phone was
        }
        return out
    }
}
