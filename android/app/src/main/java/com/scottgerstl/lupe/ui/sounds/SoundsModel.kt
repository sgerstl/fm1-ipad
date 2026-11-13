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
}

val LocalSoundsHost = staticCompositionLocalOf { SoundsHost() }
