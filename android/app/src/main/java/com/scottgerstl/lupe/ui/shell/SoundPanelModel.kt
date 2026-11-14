package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * When the sound panel is up over Pads and the Timeline (Scott, 2026-11-14: "only on a page change"). It rises when the FM-1 *changes* to a
 * sound page (a sound key, or a page step within the family), never because the FM-1 is resting on one: the first page seen after launch or
 * a reconnect is only the baseline. A knob turned on the FM-1 brings it back for that page. It leaves on HOME (no sound page), on a swipe
 * down, or [holdMs] after the last knob turn or touch on it. Clock-driven by `now` so tests can run it.
 */
class SoundPanelModel {
    var up by mutableStateOf(false); private set
    /** When it leaves if nothing else happens; a state so the screen can wait for it. */
    var deadline by mutableStateOf(0L); private set
    var holdMs = 4000L
    private var primed = false
    private var last: String? = null
    private var lastTurn: Int? = null

    /** The link dropped: the next page seen is a new baseline, and the panel is down. */
    fun reset() { primed = false; last = null; lastTurn = null; up = false }

    /** The sound page the FM-1 shows ([key] names it: family and page), or null when it shows none (HOME, SEQ, GLO…). */
    fun page(key: String?, now: Long) {
        if (!primed) { primed = true; last = key; return }
        if (key == last) return
        last = key
        if (key == null) up = false else show(now)
    }

    /** The page area's knob counter: a new value is a knob turned on the FM-1. */
    fun turn(seq: Int, now: Long) {
        if (lastTurn == null) { lastTurn = seq; return }
        if (seq == lastTurn) return
        lastTurn = seq
        if (last != null) show(now)
    }

    /** A touch on the panel (a dial, a tile): it stays while you're shaping. */
    fun touch(now: Long) { if (up) deadline = now + holdMs }

    /** A swipe down on it. */
    fun dismiss() { up = false }

    fun tick(now: Long) { if (up && now >= deadline) up = false }

    private fun show(now: Long) { up = true; deadline = now + holdMs }
}
