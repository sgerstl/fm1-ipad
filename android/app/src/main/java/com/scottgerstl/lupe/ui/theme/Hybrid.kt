package com.scottgerstl.lupe.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings

/**
 * The hybrid UI's shapes (design/hybrid-ui/tokens-proposal.json, approved as the direction for Android 2026-11-17). Not in tokens/tokens.json
 * yet: radii and shape pairs go in when Scott settles the look after the Pixel trial. No new colours: the hybrid uses Lupe's surface and text tokens.
 */
object Shape {
    val key = 8.dp        // inner corners of connected groups, app-strip keys (today's chiclet radius)
    val pad = 10.dp       // the idle, queued and pressed pad
    val panel = 14.dp     // menus, popups
    val sheet = 24.dp     // sheet top corners, docked panels
    /** A selectable thing selected squares off (shape as state): 12 at 40 tall. */
    val selected = 12.dp
    // the transport (decision 23's round keys, sized for priority; Scott 2026-11-17)
    val record = 48.dp
    val playStop = 56.dp
    // the switch: the thumb grows when on
    val switchThumbOff = 16.dp
    val switchThumbOn = 24.dp
}

/**
 * The motion table's starting values (spec §5), read from Labs (Settings › Labs › Hybrid motion; CLAUDE.md rule 3: added 2026-11-17,
 * review 2026-12-01). Graduates to tokens.json's `motion` when Scott settles it on the Pixel.
 */
class HybridMotion(
    /** Spatial spring bounce, 0..0.5 (spec: 0.25; sheets and popups 0.05 less). */
    val bounce: Float,
    /** At the finger: pad shape, hold menu, popup (spec 200). */
    val fingerMs: Int,
    /** Sheets and docked panels (spec 300). */
    val panelMs: Int,
    /** The 8-step page flip (spec 280). */
    val pageFlipMs: Int,
    /** A press squashes to this (spec 0.92). */
    val pressScale: Float,
    /** The default spatial spring for shape changes (M3 Expressive: damping 0.8, stiffness 380). */
    val spatialDamping: Float = 0.8f,
    val spatialStiffness: Float = 380f,
    /** The fast spatial spring (M3 Expressive: 0.6, 800). */
    val fastStiffness: Float = 800f,
    /** Squash-and-stretch on a shape change, 0…0.15 (6 %). */
    val squash: Float = 0.06f,
) {
    fun <T> spatial(visibility: T? = null) = androidx.compose.animation.core.spring(dampingRatio = spatialDamping, stiffness = spatialStiffness, visibilityThreshold = visibility)
    fun <T> fastSpatial(visibility: T? = null) = androidx.compose.animation.core.spring(dampingRatio = 0.6f, stiffness = fastStiffness, visibilityThreshold = visibility)
    /** M3 Expressive's default effects spring (damping 1.0, stiffness 1600): colour and opacity, never bouncing. */
    fun <T> effects(visibility: T? = null) = androidx.compose.animation.core.spring(dampingRatio = 1f, stiffness = 1600f, visibilityThreshold = visibility)
    val sheetBounce get() = (bounce - 0.05f).coerceAtLeast(0f)
}

val hybridMotion: HybridMotion
    @Composable @ReadOnlyComposable get() {
        val s = LocalPhoneSettings.current
        return HybridMotion(s.motionBounce / 100f, s.motionFingerMs, s.motionPanelMs, s.motionPageFlipMs, s.motionPressScale / 100f,
            s.spatialDamping / 100f, s.spatialStiffness.toFloat(), s.fastStiffness.toFloat(), s.squashPct / 100f)
    }

/**
 * A shape value on the expressive spatial spring (round 3): 0…1 toward [target]'s state. With Reduce Motion it eases over 150 ms and never
 * overshoots, and callers cross-fade rather than travel.
 */
@Composable
fun spatialFloat(target: Float, reduce: Boolean, fast: Boolean = false): androidx.compose.runtime.State<Float> {
    val m = hybridMotion
    val anim = androidx.compose.runtime.remember { androidx.compose.animation.core.Animatable(target) }
    androidx.compose.runtime.LaunchedEffect(target) {
        unscaled { anim.animateTo(target, if (reduce) androidx.compose.animation.core.tween(Dur.STATE, easing = EaseOut) else if (fast) m.fastSpatial() else m.spatial()) }
    }
    return androidx.compose.runtime.remember { object : androidx.compose.runtime.State<Float> { override val value: Float get() = anim.value } }
}

/**
 * Squash and stretch when [state] changes (round 3: "it should be clear that there is a shape transformation happening"): turning on, the thing
 * goes wider and shorter (width +squash, height −2/3 of it) on the fast spring, then settles back on the spatial spring; turning off, the reverse.
 * Not on the first composition. Reduce Motion: none. Returns (scaleX, scaleY), read while drawing (graphicsLayer).
 */
@Composable
fun rememberSquash(state: Boolean, reduce: Boolean): () -> Pair<Float, Float> {
    val m = hybridMotion
    val k = androidx.compose.runtime.remember { androidx.compose.animation.core.Animatable(0f) }
    val first = androidx.compose.runtime.remember { booleanArrayOf(true) }
    androidx.compose.runtime.LaunchedEffect(state) {
        if (first[0]) { first[0] = false; return@LaunchedEffect }
        if (reduce || m.squash <= 0f) return@LaunchedEffect
        unscaled {
            k.animateTo(if (state) 1f else -1f, m.fastSpatial())
            k.animateTo(0f, m.spatial())
        }
    }
    return { val v = k.value; (1f + m.squash * v) to (1f - m.squash * 0.67f * v) }
}
