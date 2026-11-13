package com.scottgerstl.lupe.ui.theme

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.MotionDurationScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Density
import kotlinx.coroutines.withContext

/** DESIGN.md numbers: about 150 ms for a state change, 200 ms at the finger, 300 ms for a page or panel; none at 500 or more. */
object Dur {
    const val STATE = 150
    const val FINGER = 200
    const val PANEL = 300
    const val EXIT = 200 // exits quicker than entrances
}

val EaseOut = CubicBezierEasing(0.2f, 0f, 0f, 1f)
val EaseIn = CubicBezierEasing(0.4f, 0f, 1f, 1f)

/**
 * With "Remove animations" on, Android sets the system duration scale to 0 and Compose then finishes every
 * animation at once, which is the "pop" DESIGN.md forbids. Run Lupe's own animations at scale 1 instead and
 * let [LocalReduceMotion] decide what is allowed to travel.
 */
private object UnscaledMotion : MotionDurationScale {
    override val scaleFactor: Float get() = 1f
}

/** An animated 0..1 (or any float) that always runs, whatever the system duration scale. */
@Composable
fun animatedFloat(target: Float, durationMs: Int, easing: androidx.compose.animation.core.Easing = EaseOut): State<Float> {
    val anim = remember { Animatable(target) }
    LaunchedEffect(target) {
        withContext(UnscaledMotion) { anim.animateTo(target, tween(durationMs, easing = easing)) }
    }
    return remember { object : State<Float> { override val value: Float get() = anim.value } }
}

/** Run [block] with the unscaled clock, for Animatable calls made from gestures. */
suspend fun <T> unscaled(block: suspend () -> T): T = withContext(UnscaledMotion) { block() }

/** A cross-fade between two looks of the same place (150 ms, the state change). Keeps the old one until it has faded. */
@Composable
fun <T> LupeCrossfade(target: T, modifier: Modifier = Modifier, durationMs: Int = Dur.STATE, content: @Composable (T) -> Unit) {
    var current by remember { mutableStateOf(target) }
    var previous by remember { mutableStateOf<T?>(null) }
    val progress = remember { Animatable(1f) }
    if (target != current) { previous = current; current = target }
    LaunchedEffect(current) {
        if (previous != null) {
            progress.snapTo(0f)
            withContext(UnscaledMotion) { progress.animateTo(1f, tween(durationMs, easing = EaseOut)) }
            previous = null
        }
    }
    androidx.compose.foundation.layout.Box(modifier) {
        previous?.let { p ->
            androidx.compose.foundation.layout.Box(Modifier.graphicsLayer { alpha = 1f - progress.value }) { content(p) }
        }
        androidx.compose.foundation.layout.Box(Modifier.graphicsLayer { alpha = if (previous != null) progress.value else 1f }) { content(current) }
    }
}

/** A fixed height read at layout time, so animating it never recomposes. */
fun Modifier.heightPx(px: Density.() -> Int): Modifier = layout { m, c ->
    val h = px().coerceAtLeast(0)
    val p = m.measure(c.copy(minHeight = h, maxHeight = h))
    layout(p.width, h) { p.place(0, 0) }
}
