package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// HOME's four knobs (decision 21, board 70): what KNOB 1…4 turn on the FM-1's HOME screen, the selected track's
// engine's four main parameters (Skiff ui.c home_param). Mirrors P1's android/core/Sources/PhoneCore/HomeKnobs.swift.
// Labels and values as the FM-1 shows them, the same as a sound page's [PageControl]s.

@Serializable
data class HomeKnobsState(
    /** 1-based; 0 before the FM-1 is read. */
    val track: Int = 0,
    val trackName: String = "",
    /** The engine ("ANALOG") and the sound ("ACID"). */
    val engine: String = "",
    val preset: String = "",
    /** KNOB 1…4 in the FM-1's order (empty before the FM-1 is read); a null slot is an empty well. */
    val controls: List<PageControl?> = emptyList(),
    /**
     * The knob last turned on the FM-1 (0…3), or -1. The FM-1 lights that card for 40 frames from the turn
     * (ui_input.c). The link says which parameter moved, not which screen it was turned on, so a knob is hot when its
     * parameter changed on the FM-1 (a sound loading lights none). It arrives about 150 ms after the turn.
     */
    val hot: Int = -1,
    /** A new value with each turn on the FM-1: start the light again when it changes. */
    val hotSeq: Int = 0,
    /** The FM-1's screen is on HOME, where its knobs turn these four. */
    val fm1Home: Boolean = false,
)

object HomeKnobsDefaults {
    val state: StateFlow<HomeKnobsState> = MutableStateFlow(HomeKnobsState())
}

/** Turn HOME's knob [slot] (0…3) to [value] (its raw number; a list's index), as the FM-1's knob would. A write. */
@Serializable @SerialName("setHomeKnob") data class SetHomeKnob(val slot: Int, val value: Int) : Intent
