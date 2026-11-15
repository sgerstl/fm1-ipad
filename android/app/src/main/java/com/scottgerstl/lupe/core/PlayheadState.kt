package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

/**
 * The `playhead` area (P1's shape, 2026-11-15): where the editor's track is in its pattern, one small send per step, so the editor area can be
 * sent only when its content changes (it carried the playhead and was resent every step, up to 15 KB each on a 64-step pattern).
 * [step] is the step playing, from 0 over the whole pattern (the chunk showing it is `step / 16`), as the FM-1's sequencer walks it (RVRS and
 * PING already run the right way, swing is in the timing); -1 when stopped, with no clock, before the first step, or when [direction] is RAND
 * (then [startTick] and [nextTick] are absent). [steps] is the pattern's step count; [direction] 0 FWD, 1 RVRS, 2 PING, 3 RAND.
 * [startTick] and [nextTick] are the clock pulses this step began on and the next begins on, in the `clock` area's count: the fraction through
 * the step is (ticksNow − startTick) / (nextTick − startTick). [track] is 1…6, the editor's; 0 until a frame has come.
 */
@Serializable
data class PlayheadState(
    val track: Int = 0,
    val step: Int = -1,
    val steps: Int = 16,
    val direction: Int = 0,
    val startTick: Double? = null,
    val nextTick: Double? = null,
)

object PlayheadDefaults { val state: StateFlow<PlayheadState> = MutableStateFlow(PlayheadState()) }

/**
 * The editor with the playhead the `playhead` area gives it (the editor area's own is always -1 from the core now): the step playing on this
 * track, or -1 when it is stopped or the area is for another track. Before any frame has come ([PlayheadState.track] 0) the editor's own
 * stands (a recorded scenario that still carries it).
 */
fun EditorState.withPlayhead(p: PlayheadState): EditorState = when {
    p.track == 0 -> this
    p.track == track && p.step >= 0 -> copy(playhead = p.step)
    else -> copy(playhead = -1)
}
