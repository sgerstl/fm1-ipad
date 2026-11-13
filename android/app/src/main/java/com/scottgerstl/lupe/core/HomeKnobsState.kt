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
 * PROVISIONAL shape: P1 is adding the real `homeKnobs` area and its set intent and will message the fields; this is
 * what the fake and the fixture use until then.
 */
@Serializable
data class HomeKnobsState(
    /** "ANALOG", "DRUM", "FM6"…: the header reads "Sound  ANALOG · the FM-1's four knobs". */
    val engine: String = "",
    /** Always four; null is an empty well (a knob with no parameter). */
    val controls: List<PageControl?> = List(4) { null },
    /** The knob (0…3) the FM-1 last turned and a counter that grows with each turn: Compose lights it for 600 ms. */
    val turned: Int = -1,
    val turnSeq: Int = 0,
)

/** Turn one of the four. [slot] 0…3, [value] raw. PROVISIONAL name, see [HomeKnobsState]. */
@Serializable @SerialName("setHomeKnob")
data class SetHomeKnob(val slot: Int, val value: Int) : Intent

object HomeKnobsDefaults { val state: StateFlow<HomeKnobsState> = MutableStateFlow(HomeKnobsState()) }
