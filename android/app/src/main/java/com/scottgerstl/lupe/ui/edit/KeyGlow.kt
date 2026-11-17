package com.scottgerstl.lupe.ui.edit

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlinx.coroutines.launch

/**
 * The FM-1's keys lit on Edit (Scott, 2026-11-17: "if I press the piano keys on the FM1, I should get some response from the piano roll"): each
 * held key (a pitch, or a kit's lane) has a 0…1 light that comes up in 60 ms and fades back over 150 ms ease-out when it's let go. Never a cut.
 * Read [of] while drawing: it redraws as it moves.
 */
class KeyGlow {
    internal val anims = mutableStateMapOf<Int, Animatable<Float, AnimationVector1D>>()
    fun of(key: Int): Float = anims[key]?.value ?: 0f
    /** Every key lit at all now (fading ones too). */
    val lit: Set<Int> get() = anims.keys
}

@Composable
fun rememberKeyGlow(held: Set<Int>): KeyGlow {
    val g = remember { KeyGlow() }
    val scope = rememberCoroutineScope()
    val now by rememberUpdatedState(held)
    LaunchedEffect(held) {
        for (k in held) { val a = g.anims.getOrPut(k) { Animatable(0f) }; scope.launch { unscaled { a.animateTo(1f, tween(60)) } } }
        for ((k, a) in g.anims.toMap()) if (k !in held) scope.launch { unscaled { a.animateTo(0f, tween(150, easing = EaseOut)) }; if (k !in now && a.value <= 0.001f) g.anims.remove(k) }
    }
    return g
}

/** Where a held pitch is against the visible rows: above them (+1), below (−1) or in view (0). */
fun offScreen(pitch: Int, visible: IntRange): Int = when { pitch > visible.last -> 1; pitch < visible.first -> -1; else -> 0 }
