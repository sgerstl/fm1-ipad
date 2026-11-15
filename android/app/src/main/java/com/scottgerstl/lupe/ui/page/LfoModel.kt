package com.scottgerstl.lupe.ui.page

import com.scottgerstl.lupe.core.ClockState
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * Skiff's LFO as its LFO page draws it, ported from ios/SloopKit/Sources/SloopKit/SkiffLFO.swift (firmware ui_graph.c lfo_view_at, voice.c
 * lfo_wave / lfo_sync_inc): RATE's curve, SYNC's note values, the five waves, PHASE, FADE, BI / UNI. Pure, so the picture and the tests agree.
 * [sync] 0 = OFF (RATE), 1… = 4BAR 2BAR 1/1 1/2 1/4 1/8 8T 1/16 16T 1/32; [trig] 0 = NOTE, 1 = FREE; [polarity] 0 = BI, 1 = UNI.
 */
data class SkiffLfo(val rate: Int = 60, val wave: Int = 0, val phase: Int = 0, val fade: Int = 0, val sync: Int = 0, val trig: Int = 0, val polarity: Int = 0) {
    /** Cycles a second: SYNC's at the tempo, or RATE's. */
    fun cyclesPerSecond(bpm: Double): Double = syncQuarters(sync)?.let { bpm / 60 / it } ?: hz(rate)

    /** PHASE as a part of a cycle. */
    val startPhase: Double get() = (phase and 127) / 128.0

    /** −1…1 (UNI: 0…1) at [cycles], [since] seconds after the restart (FADE's share). */
    fun value(cycles: Double, since: Double): Double {
        var v = wave(wave, cycles)
        if (polarity != 0) v = (v + 1) / 2
        val ft = fadeSeconds(fade)
        return if (ft > 0 && since < ft) v * max(0.0, since) / ft else v
    }

    /** The page's view: [count] values across the window and where "now" is in it (0…1). The window starts at the restart, then scrolls. */
    fun view(cyclesNow: Double, since: Double, bpm: Double, count: Int): Pair<DoubleArray, Double> {
        val k = max(0.0, since); val t0 = max(0.0, k - WINDOW); val rate = cyclesPerSecond(bpm); val n = max(count, 2)
        val values = DoubleArray(n) { i -> val t = t0 + WINDOW * i / (n - 1); value(cyclesNow - rate * (k - t), t) }
        return values to min(1.0, (k - t0) / WINDOW)
    }

    /** "1/4 at 120 BPM" when synced, else the rate in Hz. */
    fun caption(bpm: Double): String {
        if (sync > 0) return "${SYNC_NAMES.getOrElse(sync) { "SYNC" }} at ${Math.round(bpm)} BPM"
        val hz = hz(rate)
        return if (hz < 10) "%.2f Hz".format(java.util.Locale.US, hz) else "%.1f Hz".format(java.util.Locale.US, hz)
    }

    companion object {
        /** The window the page shows: 2 s from the restart, then the last 2 s. */
        const val WINDOW = 2.0
        val SYNC_NAMES = listOf("", "4BAR", "2BAR", "1/1", "1/2", "1/4", "1/8", "8T", "1/16", "16T", "1/32")
        val WAVE_NAMES = listOf("sine", "triangle", "saw", "square", "sample and hold")

        /** RATE 0…127: 0.05 Hz × 800^(v/127). */
        fun hz(v: Int): Double = 0.05 * 800.0.pow(v.coerceIn(0, 127) / 127.0)

        /** SYNC's cycle in quarter notes; null for OFF. */
        fun syncQuarters(s: Int): Double? = listOf(16.0, 8.0, 4.0, 2.0, 1.0, 0.5, 1.0 / 3, 0.25, 1.0 / 6, 0.125).getOrNull(s - 1)

        /** FADE 1…127: 1 ms × 10000^(v/127), in seconds; 0: none. */
        fun fadeSeconds(v: Int): Double = if (v <= 0) 0.0 else 10000.0.pow((v and 127) / 127.0) / 1000

        fun wave(w: Int, cycles: Double): Double {
            val ph = cycles - floor(cycles)
            return when (w) {
                1 -> if (ph < 0.5) ph * 4 - 1 else 3 - ph * 4
                2 -> ph * 2 - 1
                3 -> if (ph < 0.5) 1.0 else -1.0
                4 -> { val n = floor(cycles).toLong() and 0xFFFFFFFFL; ((((n * 2654435761L) and 0xFFFFFFFFL) shr 16).toInt() - 32768) / 32768.0 }
                else -> sin(ph * 2 * Math.PI)
            }
        }

        /** From a picture's values: RATE, WAVE, PHASE, FADE, then (when the page area carries them) SYNC, TRIG, POLARITY. */
        fun of(values: List<Int>) = SkiffLfo(
            values.getOrElse(0) { 60 }, values.getOrElse(1) { 0 }, values.getOrElse(2) { 0 }, values.getOrElse(3) { 0 },
            values.getOrElse(4) { 0 }, values.getOrElse(5) { 0 }, values.getOrElse(6) { 0 },
        )
    }
}

/** Where the LFO is now: its cycles, the seconds since its restart, and the tempo it runs at. */
data class LfoNow(val cycles: Double, val since: Double, val bpm: Double)

/**
 * The LFO now, from the `clock` area. The FM-1 restarts a NOTE-triggered LFO on a fresh phrase, which the phone isn't told, so the restart
 * here is the clock's Start (pulse 0) while it runs, and [openedMs] (when the picture first showed) while it doesn't. A synced LFO keeps
 * the clock's pace exactly; a RATE one runs from that restart.
 */
fun lfoNow(lfo: SkiffLfo, clock: ClockState, tempo: Double, openedMs: Long, nowMs: Long): LfoNow {
    val running = clock.running && clock.ticksPerSecond > 0
    val bpm = if (running) clock.ticksPerSecond * 60 / 24 else tempo
    val p0 = lfo.startPhase
    if (running) {
        val ticks = max(0.0, clock.ticksNow(nowMs))
        val since = ticks / clock.ticksPerSecond
        val q = SkiffLfo.syncQuarters(lfo.sync)
        return LfoNow(if (q != null) p0 + ticks / 24 / q else p0 + since * SkiffLfo.hz(lfo.rate), since, bpm)
    }
    val since = max(0L, nowMs - openedMs) / 1000.0
    return LfoNow(p0 + since * lfo.cyclesPerSecond(bpm), since, bpm)
}
