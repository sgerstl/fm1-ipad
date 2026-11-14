package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

/**
 * The `clock` area (P1's shape): a reference the screen moves on from every frame, so pass bars and waiting outlines glide between publishes.
 * [ticks] is MIDI clock pulses since Start (24 a beat, 96 a bar) as of [atMs], which is `SystemClock.uptimeMillis()` at that count; a new
 * reference comes every beat, on Start and on a restart. [running] false means no clock (stopped, or joined mid-play): outlines are dashed and
 * nothing is interpolated.
 */
@Serializable
data class ClockState(val running: Boolean = false, val ticks: Double = 0.0, val atMs: Long = 0, val ticksPerSecond: Double = 0.0) {
    /** The pulse count now. */
    fun ticksNow(uptimeMs: Long): Double = ticks + (uptimeMs - atMs) * ticksPerSecond / 1000.0
    /** Pulses until [launchTick], never under 0; null when there is no clock or no launch point. */
    fun ticksLeft(launchTick: Double?, uptimeMs: Long): Double? = if (!running || launchTick == null) null else (launchTick - ticksNow(uptimeMs)).coerceAtLeast(0.0)
    /** How far through its pass a playing entry is, 0…1, or null when the clock or the pass isn't known (use the entry's own `progress` then). */
    fun passProgress(passStartTick: Double?, passTicks: Double?, uptimeMs: Long): Float? {
        if (!running || passStartTick == null || passTicks == null || passTicks <= 0) return null
        val p = ((ticksNow(uptimeMs) - passStartTick) / passTicks) % 1.0
        return (if (p < 0) p + 1 else p).toFloat()
    }
}

object ClockDefaults { val clock: StateFlow<ClockState> = MutableStateFlow(ClockState()) }
