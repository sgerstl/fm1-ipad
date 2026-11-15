package com.scottgerstl.lupe.ui.intro

import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * The launch intro's timing and geometry, ported from ios/FM1/LaunchIntro.swift (IntroScene) and the approved prototype
 * design/brand/intro-prototype.html: no drawing, so it can be tested. All times in seconds since the intro started.
 *
 *   zoom 0.42 s from the home-screen icon · power-on line 0.22 s (one soft flash: WCAG 2.3.1) · one Lissajous pass in 1.06 s
 *   · settle 0.4 s · "lupe" fading in over 0.52 s · hold 0.4 s · CRT switch-off: squash 0.12 s, pinch 0.1 s, blip 0.18 s while the app fades up.
 *   About 2.9 s. Reduce Motion: the finished logo fades in, stays to 1.6 s and crossfades to the app (1.94 s).
 */
object IntroMath {
    const val ZOOM = 0.42; const val FLASH = 0.22; const val TRACE = 1.06; const val SETTLE = 0.4
    const val NAME_AT = 0.35; const val NAME = 0.52; const val HOLD = 0.4
    const val SQUASH = 0.12; const val PINCH = 0.1; const val BLIP = 0.18

    val tz = ZOOM
    val tf = tz + FLASH
    val tt = tf + TRACE
    val ts = tt + SETTLE
    /** The name: 20 % sooner than 35 % into the settle, about as the trace finishes. */
    val na = (tt + SETTLE * NAME_AT) * 0.8
    val tn = max(ts, na + NAME)
    val th = tn + HOLD
    val to1 = th + SQUASH
    val to2 = to1 + PINCH
    val end = to2 + BLIP
    /** Reduce Motion: the logo fades in (0.28 s), stays to 1.6 s, then crossfades to the app (0.33 s). */
    const val REDUCED_FADE_IN = 0.28; const val REDUCED_HOLD = 1.6; const val REDUCED_FADE_OUT = 0.33
    const val REDUCED_END = REDUCED_HOLD + 0.34

    /** Where the beam is on the figure when the trace starts. */
    const val BEAM_AT = 0.31

    /** The trail cools from the app's white to a dim grey (flat and white, 2026-11-08). RGB 0…255. */
    val OLD = Triple(70.0, 70.0, 76.0); val FRESH = Triple(244.0, 244.0, 246.0)

    /** The figure in the icon's 100-unit square: x = sin(3t + 0.9 sin 2t), y = sin 2t. */
    fun fig(u: Double): Pair<Double, Double> {
        val t = (u + BEAM_AT) * 2 * PI
        return (50 + sin(3 * t + 0.9 * sin(2 * t)) * 28) to (50 + sin(2 * t) * 28)
    }

    fun ease(x: Double): Double = 1 - (1 - min(1.0, max(0.0, x))).pow(3)

    /** Where the beam is: one pass in the trace, then eased 0.02 on to its rest. */
    fun beamU(t: Double): Double {
        val trace = min(1.0, max(0.0, (t - tf) / TRACE))
        val settle = if (t < tt) 0.0 else min(1.0, (t - tt) / SETTLE)
        return trace + if (settle > 0) 0.02 * ease(settle) else 0.0
    }

    /**
     * The prototype's phosphor frames (60 a second) between [tau] and [t]: each cools it by 10 % toward the dim grey and fades it by 5.5 %, at full
     * rate while tracing, less as it settles (1 − ease), not at all once settled. Computed from the age, so the picture is the same at any frame rate.
     */
    fun coolFrames(tau: Double, t: Double): Double {
        if (t <= tau) return 0.0
        var f = 0.0
        val a = min(tau, tt); val b = min(t, tt)
        if (b > a) f += b - a
        // in the settle: ∫ (1 − ease(s)) = ∫ (1 − s)³ = ((1 − s₁)⁴ − (1 − s₂)⁴) / 4, in the settle's time
        val s1 = min(1.0, max(0.0, (max(tau, tt) - tt) / SETTLE)); val s2 = min(1.0, max(0.0, (t - tt) / SETTLE))
        if (s2 > s1) f += ((1 - s1).pow(4) - (1 - s2).pow(4)) / 4 * SETTLE
        return f * 60
    }

    /** When the beam passed u (the trail's paint time). */
    fun paintTime(u: Double): Double {
        if (u <= 1) return tf + u * TRACE
        // u = 1 + 0.02 ease(s): s = 1 − (1 − y)^(1/3)
        val y = min(1.0, (u - 1) / 0.02)
        return tt + (1 - (1 - y).pow(1.0 / 3)) * SETTLE
    }

    /** How many bits the trail is drawn in while the beam is at [uNow]. */
    fun trailSegments(uNow: Double): Int = max(2, ceil(uNow * 600).toInt())

    fun mix(a: Triple<Double, Double, Double>, b: Triple<Double, Double, Double>, k: Double) =
        Triple(a.first + (b.first - a.first) * k, a.second + (b.second - a.second) * k, a.third + (b.third - a.third) * k)

    /** The trail's colour factor and alpha for a bit of age [frames]: cooling 10 % and fading 5.5 % a frame. */
    fun cool(frames: Double): Pair<Double, Double> = 0.9.pow(frames) to 0.945.pow(frames)
}
