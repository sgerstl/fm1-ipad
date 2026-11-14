package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * When the sound panel is docked at the right of Pads, Edit and the Timeline (decision 32, the iPad's panel rule). It comes in when the FM-1
 * *changes* to a sound page (a sound key on the FM-1 or on the phone's rail, or a page step within the family), never because the FM-1 is
 * resting on one: the first page seen after launch or a reconnect is only the baseline. A knob turned on the FM-1 brings it back for that
 * page. It **stays** until HOME (no sound page), its close key, or another tab. There is no timeout (decision 32: the 8 s pop-up rule went).
 */
class SoundPanelModel {
    var up by mutableStateOf(false); private set
    private var primed = false
    private var last: String? = null
    private var lastTurn: Int? = null

    /** The link dropped: the next page seen is a new baseline, and the panel is shut. */
    fun reset() { primed = false; last = null; lastTurn = null; up = false }

    /** The sound page the FM-1 shows ([key] names it: family and page), or null when it shows none (HOME, SEQ, GLO…). */
    fun page(key: String?) {
        if (!primed) { primed = true; last = key; return }
        if (key == last) return
        last = key
        up = key != null
    }

    /** The page area's knob counter: a new value is a knob turned on the FM-1. */
    fun turn(seq: Int) {
        if (lastTurn == null) { lastTurn = seq; return }
        if (seq == lastTurn) return
        lastTurn = seq
        if (last != null) up = true
    }

    /** Its close key, or another tab chosen. The FM-1 stays where it is; its next page change or knob turn opens the panel again. */
    fun dismiss() { up = false }
}

/** The phone's sound keys, in the iPad's order (decision 32). */
val SOUND_KEYS = listOf("FX", "SEL", "ENV", "LFO", "EDIT", "ARP")

/**
 * What a sound key on the rail asks the FM-1 for: a family whose panel is shut opens on the page it is on (null: the FM-1's own choice); the
 * open family's key again steps to its next page, round to the first, as the FM-1's own key does. [pages] are the open family's page numbers.
 */
fun railTarget(family: String, openFamily: String?, pages: List<Int>, page: Int): Int? {
    if (family != openFamily || pages.isEmpty()) return null
    val at = pages.indexOf(page)
    return pages[(at + 1).mod(pages.size)]
}
