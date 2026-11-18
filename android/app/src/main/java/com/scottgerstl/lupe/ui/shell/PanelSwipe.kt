package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlinx.coroutines.launch
import kotlin.math.abs

/**
 * A docked panel swiped away by hand (Scott, 2026-11-18: "more reactive to the initiation of the swipe so that it feels more like the panel
 * follows the finger"). Once a drag passes touch slop and is mostly sideways (1.5×, round 7's lock), the panel's x follows the finger 1:1 from
 * there, rightward; leftward it resists (a third of the finger, at most 24 dp). Let go: past 35 % of its width or flung right, it leaves with the
 * finger's speed and closes; otherwise it springs back from that speed. A mostly vertical drag never moves it. Reduce Motion: it still follows
 * the finger (direct manipulation); it settles without overshoot.
 */
class PanelSwipe {
    /** The panel's drag offset, px (+: towards the right edge). Added to its own slide-in. */
    val offset = Animatable(0f)
}

/** The pure parts, tested. */
object PanelSwipeRule {
    const val DISMISS_SHARE = 0.35f
    const val FLING_DP_S = 500f
    const val RESIST = 1f / 3f
    const val RESIST_MAX_DP = 24f
    /** Where the panel is for a finger [dx] (px) past the slop: 1:1 rightward, a resisted third leftward, at most [maxLeftPx]. */
    fun follow(dx: Float, maxLeftPx: Float): Float = if (dx >= 0f) dx else maxOf(dx * RESIST, -maxLeftPx)
    /** Whether a release at [offset] (px) of a [width]-wide panel, moving [vx] px/s, closes it. */
    fun dismisses(offset: Float, width: Float, vx: Float, flingPx: Float): Boolean = offset > width * DISMISS_SHARE || vx > flingPx
}

@Composable
fun rememberPanelSwipe(open: Boolean): PanelSwipe {
    val s = remember { PanelSwipe() }
    // opened again: from its place, whatever the last swipe left
    LaunchedEffect(open) { if (open) s.offset.snapTo(0f) }
    return s
}

fun Modifier.panelSwipe(state: PanelSwipe, onDismiss: () -> Unit): Modifier = composed {
    val scope = rememberCoroutineScope()
    val reduce = LocalReduceMotion.current
    pointerInput(state, reduce) {
        val slop = viewConfiguration.touchSlop
        val maxLeft = PanelSwipeRule.RESIST_MAX_DP.dp.toPx()
        val fling = PanelSwipeRule.FLING_DP_S.dp.toPx()
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false)
            var total = Offset.Zero
            // until the slop: is it sideways? (a control inside that took the touch, or a vertical scroll, keeps it)
            var start: Offset? = null
            while (start == null) {
                val ev = awaitPointerEvent()
                val ch = ev.changes.firstOrNull { it.id == down.id } ?: return@awaitEachGesture
                if (!ch.pressed || ch.isConsumed) return@awaitEachGesture
                total += ch.positionChange()
                if (total.getDistance() > slop) {
                    if (abs(total.x) < 1.5f * abs(total.y)) return@awaitEachGesture
                    ch.consume(); start = ch.position
                }
            }
            scope.launch { state.offset.stop() }
            val tracker = VelocityTracker()
            val origin = start!!.x
            drag(down.id) { ch ->
                ch.consume()
                tracker.addPosition(ch.uptimeMillis, ch.position)
                val to = PanelSwipeRule.follow(ch.position.x - origin, maxLeft)
                scope.launch { state.offset.snapTo(to) }
            }
            val vx = tracker.calculateVelocity().x
            val w = size.width.toFloat()
            scope.launch {
                unscaled {
                    if (PanelSwipeRule.dismisses(state.offset.value, w, vx, fling)) {
                        // closed at once, so what sits beside the panel changes with it, not after it; the panel leaves at the finger's speed
                        onDismiss()
                        state.offset.animateTo(w, spring(dampingRatio = 1f, stiffness = 800f), initialVelocity = maxOf(vx, 0f))
                    } else {
                        state.offset.animateTo(0f, if (reduce) spring(dampingRatio = 1f, stiffness = 800f) else spring(dampingRatio = 0.8f, stiffness = 380f), initialVelocity = vx)
                    }
                }
            }
        }
    }
}

/** A panel's x: its slide-in [slide] and the drag [offset]. Dragged left it resists from its place; dragged right (or leaving) whichever is further out, so a swiped-out panel doesn't jump back as its own close begins. */
fun panelX(slide: Float, offset: Float): Float = if (offset < 0f) slide + offset else maxOf(slide, offset)
