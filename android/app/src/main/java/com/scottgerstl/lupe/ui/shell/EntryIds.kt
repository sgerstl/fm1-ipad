package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector2D
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.round
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.invisibleToUser
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.FastOutSlowInEasing
import com.scottgerstl.lupe.core.PadEntry
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlinx.coroutines.launch

// Nothing pops (Scott's standing rule): when a track's list is rewritten (a duplicate, Duplicate after, a pad moved or swapped, a block deleted, an Undo) the pads
// that are still there slide to their new places. The core gives entries no identity, so the screen follows them: an entry that keeps its kind, pattern and passes
// is the same entry, matched against the list before it (the longest run in order first, then the ones that moved).

/** What makes an entry the same entry from one list to the next: its kind and pattern (not its play state, which changes every beat, nor its passes, which Play once more changes). */
fun entryKey(e: PadEntry): String = "${e.kind}:${e.pattern}"

/** The ids for [newKeys], reusing those of [oldKeys]/[oldIds] where an entry is still there ([fresh] makes a new one). */
fun matchIds(oldKeys: List<String>, oldIds: List<Long>, newKeys: List<String>, fresh: () -> Long): List<Long> {
    val n = oldKeys.size; val m = newKeys.size
    // the longest common run in order
    val dp = Array(n + 1) { IntArray(m + 1) }
    for (i in n - 1 downTo 0) for (j in m - 1 downTo 0) dp[i][j] = if (oldKeys[i] == newKeys[j]) dp[i + 1][j + 1] + 1 else maxOf(dp[i + 1][j], dp[i][j + 1])
    val out = arrayOfNulls<Long>(m); val taken = BooleanArray(n)
    var i = 0; var j = 0
    while (i < n && j < m) when {
        oldKeys[i] == newKeys[j] && dp[i][j] == dp[i + 1][j + 1] + 1 -> { out[j] = oldIds[i]; taken[i] = true; i++; j++ }
        dp[i + 1][j] >= dp[i][j + 1] -> i++
        else -> j++
    }
    // the ones that moved out of order (a swap): the first untaken old entry with the same key
    for (jj in 0 until m) if (out[jj] == null) {
        val k = (0 until n).firstOrNull { !taken[it] && oldKeys[it] == newKeys[jj] }
        if (k != null) { out[jj] = oldIds[k]; taken[k] = true }
    }
    return out.map { it ?: fresh() }
}

/** Keeps each track's last list and ids between recompositions. */
class EntryIdTracker {
    private var next = 1L
    /** Set once the page has opened: pads that come after that grow in. */
    var settled = false
    private val last = HashMap<Int, Pair<List<String>, List<Long>>>()
    fun update(track: Int, entries: List<PadEntry>): List<Long> {
        val keys = entries.map(::entryKey)
        val prev = last[track]
        if (prev != null && prev.first == keys) return prev.second
        val ids = matchIds(prev?.first.orEmpty(), prev?.second.orEmpty(), keys) { next++ }
        last[track] = keys to ids
        return ids
    }
}

/**
 * Slides to a new place in its parent instead of jumping (about a quarter of a second, ease out); with Reduce Motion it stays where the layout puts it and
 * cross-fades in. A thing that has only just come into being doesn't slide from anywhere.
 */
fun Modifier.slideToPlace(onPlace: ((IntOffset, androidx.compose.ui.unit.IntSize) -> Unit)? = null): Modifier = composed {
    val reduce = LocalReduceMotion.current
    val scope = rememberCoroutineScope()
    var target by remember { mutableStateOf(IntOffset.Zero) }
    var anim by remember { mutableStateOf<Animatable<IntOffset, AnimationVector2D>?>(null) }
    val fade = remember { Animatable(1f) }
    this.onPlaced { target = it.positionInParent().round(); onPlace?.invoke(target, it.size) }
        .alpha(fade.value)
        .offset {
            val a = anim ?: Animatable(target, IntOffset.VectorConverter).also { anim = it }
            if (a.targetValue != target) {
                if (reduce) scope.launch { a.snapTo(target); unscaled { fade.snapTo(0.3f); fade.animateTo(1f, tween(150)) } }
                else scope.launch { unscaled { a.animateTo(target, tween(260, easing = FastOutSlowInEasing)) } }
            }
            // drawn where it was and catching up with where the layout now puts it
            a.value - target
        }
}

/** A pad that came into being after the page settled grows in (about 200 ms: from 60 % and clear); with Reduce Motion it only fades. An Undo grows its pad back this way. */
fun Modifier.growIn(animate: Boolean): Modifier = composed {
    val reduce = LocalReduceMotion.current
    val t = remember { Animatable(if (animate) 0f else 1f) }
    androidx.compose.runtime.LaunchedEffect(Unit) { if (animate) unscaled { t.animateTo(1f, tween(200)) } }
    this.graphicsLayer { val s = if (reduce) 1f else 0.6f + 0.4f * t.value; scaleX = s; scaleY = s; alpha = t.value }
}

/** What a pad that is going keeps for its goodbye: where it stood in its row, how big it was, what it said. */
class PadMemo { var pos = IntOffset.Zero; var size = androidx.compose.ui.unit.IntSize.Zero; var entry = PadEntry(); var idx = 0 }

/** A deleted pad, still on the screen while it shrinks and fades (about 200 ms) and the others close up behind it. */
class PadGhost(val id: Long, val pos: IntOffset, val size: androidx.compose.ui.unit.IntSize, val entry: PadEntry, val idx: Int)

@androidx.compose.runtime.Composable
fun GhostPad(g: PadGhost, onDone: () -> Unit) {
    val reduce = LocalReduceMotion.current
    val t = remember { Animatable(0f) }
    androidx.compose.runtime.LaunchedEffect(Unit) { unscaled { t.animateTo(1f, tween(200)) }; onDone() }
    val dens = androidx.compose.ui.platform.LocalDensity.current
    androidx.compose.foundation.layout.Box(
        Modifier.offset { g.pos }.size(with(dens) { g.size.width.toDp() }, with(dens) { g.size.height.toDp() })
            .graphicsLayer { val s = if (reduce) 1f else 1f - 0.4f * t.value; scaleX = s; scaleY = s; alpha = 1f - t.value }
            .androidx_clearSemantics(),
    ) {
        androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) { drawRoundRect(com.scottgerstl.lupe.ui.theme.Tok.control, cornerRadius = androidx.compose.ui.geometry.CornerRadius(8.dp.toPx())) }
        androidx.compose.foundation.text.BasicText(
            ('A' + g.idx).toString() + if (g.entry.pattern != null) "  %02d".format(g.entry.pattern) else if (g.entry.kind == com.scottgerstl.lupe.core.PadKind.Rest) "  REST" else "",
            Modifier.align(androidx.compose.ui.Alignment.CenterStart).padding(start = 8.dp),
            style = com.scottgerstl.lupe.ui.theme.LupeType.label.copy(color = com.scottgerstl.lupe.ui.theme.Tok.text),
        )
    }
}

private fun Modifier.androidx_clearSemantics(): Modifier = this.then(Modifier.semantics { invisibleToUser() })
