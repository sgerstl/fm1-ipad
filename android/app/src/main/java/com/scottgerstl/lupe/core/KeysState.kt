package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

/**
 * The FM-1's notes sounding now (the core's `keys` area, 2026-11-17): a list a track, track 1 at index 0. Its keys, and while the transport
 * runs its sequencer's notes too (Skiff sends every track's notes on their channels). Edit lights its piano edge and lane keys from it.
 */
@Serializable
data class KeysState(val tracks: List<List<Int>> = emptyList()) {
    /** The notes sounding on [track] (1…6). */
    fun on(track: Int): Set<Int> = tracks.getOrNull(track - 1)?.toSet() ?: emptySet()
}

object KeysDefaults { val state: StateFlow<KeysState> = MutableStateFlow(KeysState()) }
