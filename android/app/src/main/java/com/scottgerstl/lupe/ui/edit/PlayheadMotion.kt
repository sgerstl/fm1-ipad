package com.scottgerstl.lupe.ui.edit

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.ClockState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PlayheadState
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sqrt

/**
 * The smooth playhead and the hit bounce (Scott, 2026-11-17: "the playhead running smoothly across and making all of the steps in the sequence
 * bounce slightly as it passes them"; then: only hits bounce). Both run off the FM-1's clock, never frame time, so they can't drift from what's
 * heard: the playhead area says which step plays and the ticks it started and ends on, and [ClockState] says what tick it is now.
 */
object PlayheadMotion {
    /**
     * Where the playhead is, in steps (2.5 = halfway through the third step), or null with nothing playing. Forward it sweeps from the step's start
     * to the next; backward from its end to its start; any other direction (random) and a step with no ticks known sit on the step.
     */
    fun position(ph: PlayheadState, clock: ClockState, uptimeMs: Long): Float? {
        if (ph.step < 0) return null
        val a = ph.startTick; val b = ph.nextTick
        if (!clock.running || a == null || b == null || b <= a) return ph.step.toFloat()
        val f = ((clock.ticksNow(uptimeMs) - a) / (b - a)).coerceIn(0.0, 1.0).toFloat()
        return when { ph.direction > 0 || ph.direction == 0 -> ph.step + f; ph.direction < 0 -> ph.step + 1 - f; else -> ph.step.toFloat() }
    }

    /**
     * A hit's scale [tMs] after its step sounded: up to [scale] in [upMs] (ease-out), then back to 1 on a spring that settles in about [backMs]
     * (damping 0.5, a small dip under 1). 1 before the step sounds and once it has settled.
     */
    fun hitBounce(tMs: Float, scale: Float = 1.12f, upMs: Int = 50, backMs: Int = 200): Float {
        if (tMs < 0f) return 1f
        val peak = scale - 1f
        if (tMs < upMs) { val u = tMs / upMs; return 1f + peak * (1f - (1f - u) * (1f - u)) }
        val t = tMs - upMs
        if (t > backMs * 1.5f) return 1f
        // a damped spring released from the peak: ζ 0.5, ω chosen so the envelope is ~2 % at backMs
        val zeta = 0.5f; val w = 4f / (zeta * backMs)
        val wd = w * sqrt(1f - zeta * zeta)
        return 1f + peak * exp(-zeta * w * t) * (cos(wd * t) + zeta / sqrt(1f - zeta * zeta) * kotlin.math.sin(wd * t))
    }

    /** How long ago [startTick] sounded, in ms, by the clock; null with no clock. */
    fun msSince(startTick: Double, clock: ClockState, uptimeMs: Long): Float? =
        if (!clock.running || clock.ticksPerSecond <= 0.0) null else ((clock.ticksNow(uptimeMs) - startTick) / clock.ticksPerSecond * 1000.0).toFloat()
}

/** The playhead and bounce state a grid reads while drawing (reading [frame] in a draw block redraws only that block each frame). */
class PlayheadClock {
    var ph by mutableStateOf(PlayheadState()); internal set
    var clock by mutableStateOf(ClockState()); internal set
    var reduce by mutableStateOf(false); internal set
    var scale = 1.12f; var upMs = 50; var backMs = 200
    /** The steps that sounded lately and the tick each began on (newest last), for their hits' bounce. */
    var recent by mutableStateOf<List<Pair<Int, Double>>>(emptyList()); internal set
    val frame = mutableLongStateOf(0L)
    private fun now() = android.os.SystemClock.uptimeMillis()

    /** The playhead's place in steps for track [track] (null when that track isn't playing). Reduce Motion: it sits on the step (it jumps). */
    fun position(track: Int): Float? {
        frame.longValue
        val p = ph
        if (p.track != track || p.step < 0) return null
        return if (reduce) p.step.toFloat() else PlayheadMotion.position(p, clock, now())
    }

    /** A hit on [step]'s scale now (1 when it isn't bouncing). Reduce Motion: always 1. */
    fun bounce(step: Int, track: Int): Float {
        if (reduce || ph.track != track) return 1f
        val r = recent.lastOrNull { it.first == step } ?: return 1f
        frame.longValue
        val t = PlayheadMotion.msSince(r.second, clock, now()) ?: return 1f
        return PlayheadMotion.hitBounce(t, scale, upMs, backMs)
    }
}

/** The playhead clock for a grid: collects the playhead and clock areas, keeps the recent steps, and ticks [PlayheadClock.frame] while playing. */
@Composable
fun rememberPlayheadClock(core: LupeCore): PlayheadClock {
    val ph by core.playhead.collectAsStateWithLifecycle()
    val clock by core.clock.collectAsStateWithLifecycle()
    val reduce = com.scottgerstl.lupe.ui.theme.LocalReduceMotion.current
    val labs = com.scottgerstl.lupe.ui.slide.LocalPhoneSettings.current
    val pc = remember { PlayheadClock() }
    pc.ph = ph; pc.clock = clock; pc.reduce = reduce
    pc.scale = labs.bounceScalePct / 100f; pc.upMs = labs.bounceUpMs; pc.backMs = labs.bounceBackMs
    LaunchedEffect(ph.step, ph.startTick) {
        val a = ph.startTick
        if (ph.step >= 0 && a != null) pc.recent = (pc.recent.filter { it.first != ph.step } + (ph.step to a)).takeLast(4)
    }
    val running = clock.running && ph.step >= 0 && !reduce
    LaunchedEffect(running) { while (running) withFrameNanos { pc.frame.longValue = it } }
    return pc
}
