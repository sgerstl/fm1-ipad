package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Something that shows while it is being used and settles back a while after the last use: the page's picture under the dials (decision 30),
 * raised by a knob turn on the FM-1 or a touch on a dial, lowered [holdMs] after the last one. Clock-driven by `now` so tests can run it.
 */
class HoldTimer {
    var up by mutableStateOf(false); private set
    var deadline by mutableStateOf(0L); private set
    var holdMs = 8000L
    private var lastTurn: Int? = null

    /** A use: up, and the wait starts again. */
    fun poke(now: Long) { up = true; deadline = now + holdMs }
    /** The page area's knob counter: the first value is only the baseline; a new one is a knob turned. */
    fun turn(seq: Int, now: Long) { val was = lastTurn; lastTurn = seq; if (was != null && was != seq) poke(now) }
    /** Down at once: the page changed, or went away. */
    fun drop() { up = false }
    fun tick(now: Long) { if (up && now >= deadline) up = false }
}
