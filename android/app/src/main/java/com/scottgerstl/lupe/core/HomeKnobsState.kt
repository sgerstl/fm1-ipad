package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * HOME's four sound knobs (decision 21, board 70): the selected track's engine main params, the same four the FM-1's
 * knobs turn on HOME (Skiff ui.c home_param: ANALOG is CUTOFF, RES, ATTACK, RELEASE; DRUM puts MORPH on knob 1). Shown under
 * the step grid while no step is picked. A knob is a [PageControl] (label, value text, raw and range), so it turns
 * exactly like a sound page's.
 *
 * Shape as P1 fixed it (2026-11-13). The area isn't published until a Skiff FM-1 has been read.
 */
@Serializable
data class HomeKnobsState(
    val track: Int = 1,
    val trackName: String = "",
    /** "ANALOG", "DRUM", "FM6"…: the header reads "Sound  ANALOG · ACID". */
    val engine: String = "",
    /** The preset's name ("ACID"), or empty. */
    val preset: String = "",
    /** The FM-1's knobs 1-4, as the sound pages' controls; null is an empty well. */
    val controls: List<PageControl?> = List(4) { null },
    /** The knob (0…3) last turned on the FM-1, or -1; [hotSeq] changes with each turn (restart the light). It lights for any change of that parameter, from any page. */
    val hot: Int = -1,
    val hotSeq: Int = 0,
    /** The FM-1's screen is on HOME, where its knobs turn these four. */
    val fm1Home: Boolean = false,
)

/** Turn one of the four. [slot] 0…3, [value] raw. A write: refused while read-only, same path as setParam. */
@Serializable @SerialName("setHomeKnob")
data class SetHomeKnob(val slot: Int, val value: Int) : Intent

object HomeKnobsDefaults { val state: StateFlow<HomeKnobsState> = MutableStateFlow(HomeKnobsState()) }
