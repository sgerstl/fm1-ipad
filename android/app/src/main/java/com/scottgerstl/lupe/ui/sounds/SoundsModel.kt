package com.scottgerstl.lupe.ui.sounds

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf

/** The browser is open for [track], and, from a drum pad's menu, for that pad's own sound ([pad] is its entry letter). */
data class SoundsRequest(val track: Int, val pad: String? = null)

/** Which track (and pad) the Sounds browser is open for; the Pads' hold menu, a track number held, and a Mix row set it. */
@Stable
class SoundsHost {
    var request by mutableStateOf<SoundsRequest?>(null)
    fun open(track: Int, pad: String? = null) { request = SoundsRequest(track, pad) }
    fun close() { request = null }
    /** Which list the FM-1's SAVE page asks for (USER's slots, or the presets); null until it has. The browser follows each change. */
    var userView by mutableStateOf<Boolean?>(null)
    /** Counts each ask, so asking for the same list twice still moves the browser back to it. */
    var viewAsk by mutableStateOf(0)
    fun show(user: Boolean) { userView = user; viewAsk++ }
}

val LocalSoundsHost = staticCompositionLocalOf { SoundsHost() }
