package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.scottgerstl.lupe.core.BottomPage

/**
 * What the bottom half shows, and whether it is held (Labs: Pause following after a touch, Pin). It follows the FM-1.
 * Pause and Pin hold only against changes the FM-1 makes by itself (its buttons): a page change the phone itself asked
 * for (the family row, the page row, a route or tile pick, back) applies at once, resets the pause timer, and its echo from the
 * FM-1 (the same page) is not "the FM-1 moved on". Clock-driven by [now] so tests can run it.
 */
class FollowModel(initial: BottomPage) {
    var pin = false
    var pause = false
    var shown by mutableStateOf(initial); private set
    var held by mutableStateOf(false); private set
    private var actual = initial
    private var heldUntil = 0L
    private var applyUntil = 0L

    /** A touch in the bottom half: with Pause on, the page holds for [HOLD_MS]. */
    fun touch(now: Long) { if (pause) { held = true; heldUntil = now + HOLD_MS } }

    /** The phone asked for a page change (before the FM-1 has answered): it applies when it arrives, held or not. */
    fun ask(now: Long) { held = false; heldUntil = 0; applyUntil = now + ASK_WINDOW_MS }

    /** The core's page changed (or the flags did). */
    fun onActual(page: BottomPage, now: Long) {
        actual = page
        if (now < applyUntil || (!pin && !(held && now < heldUntil))) shown = page
    }

    /** The hold may have run out. */
    fun tick(now: Long) {
        if (held && now >= heldUntil) held = false
        if (!pin && !held) shown = actual
    }

    /** Frozen as it was: held by Pin, or by a touch's pause. */
    val frozen get() = pin || held

    companion object { const val HOLD_MS = 3000L; const val ASK_WINDOW_MS = 600L }
}
