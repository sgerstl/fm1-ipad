package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.Divider
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.heightPx
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlin.math.abs

private fun Divider.index() = when (this) { Divider.Top -> 0; Divider.Split -> 1; Divider.Bottom -> 2 }
private fun Int.toDivider() = Divider.entries[this]

private const val HANDLE_H = 16f   // dp, the divider's drawn band (board 53)
private const val GAP = 4f         // dp above and below it
private const val HEADER_H = 36f   // the tab row
private const val STRIP_H = 40f    // bottom full: the selected track's pads stay up as a strip
private const val TOP_OFFSET = HEADER_H + 8f // content starts 8 below the tabs
private const val BOTTOM_TOP = STRIP_H + GAP // the divider's top at bottom full

/**
 * Tabs, the top half, the divider, the bottom half. [p] is the divider's place as a number: 0 top only,
 * 1 split, 2 bottom full, with everything between. The positions are the boards' (board 54): at 412 × 915 dp
 * split puts the divider at 350 dp below the tabs, top only at the bottom edge, bottom full under a 40 dp
 * strip. Heights scale with the screen.
 */
@Composable
fun ShellBody(shell: ShellState, core: LupeCore, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current
    val pads by core.pads.collectAsStateWithLifecycle()
    val editor by core.editor.collectAsStateWithLifecycle()

    BoxWithConstraints(modifier.fillMaxSize()) {
        val hb = with(density) { maxHeight.toPx() }
        fun dp(v: Float) = with(density) { v.dp.toPx() }
        // the divider's top, in px below the body's top, for each position
        val stops = floatArrayOf(hb - dp(HANDLE_H), (hb * 350f / 787f).coerceAtLeast(dp(BOTTOM_TOP) + dp(80f)), dp(BOTTOM_TOP))
        fun topAt(p: Float): Float {
            val c = p.coerceIn(0f, 2f); val i = c.toInt().coerceAtMost(1); val f = c - i
            return stops[i] + (stops[i + 1] - stops[i]) * f
        }
        fun pAt(top: Float): Float {
            val t = top.coerceIn(stops[2], stops[0])
            return if (t >= stops[1]) (stops[0] - t) / (stops[0] - stops[1]) else 1f + (stops[1] - t) / (stops[1] - stops[2])
        }

        val place = remember { Animatable(shell.divider.index().toFloat()) }
        var dragging by remember { mutableStateOf(false) }
        // Reduce Motion: nothing travels. The settled position cross-fades; a drag only moves the handle's choice.
        var dragP by remember { mutableStateOf(0f) }

        LaunchedEffect(shell.divider, reduce) {
            if (dragging) return@LaunchedEffect
            val target = shell.divider.index().toFloat()
            if (reduce) place.snapTo(target) else unscaled { place.animateTo(target, tween(Dur.PANEL, easing = EaseOut)) }
        }

        fun settle(to: Divider) {
            if (to != shell.divider) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
            core.send(Intent.SetDivider(to))
            scope.launch {
                if (reduce) place.snapTo(to.index().toFloat()) else unscaled { place.animateTo(to.index().toFloat(), tween(Dur.PANEL, easing = EaseOut)) }
            }
        }

        if (reduce) {
            LupeCrossfade(shell.divider) { d -> Layers(d.index().toFloat(), shell, pads, editor, core, hb, ::topAt) }
        } else {
            Layers(place.value, shell, pads, editor, core, hb, ::topAt)
        }

        // The divider's touch target: 48 dp tall around the 16 dp band, over both halves.
        Box(
            Modifier
                .fillMaxWidth().height(48.dp)
                .offset { IntOffset(0, (topAt(if (reduce) shell.divider.index().toFloat() else place.value) + dp(HANDLE_H) / 2 - dp(24f)).toInt()) }
                .semantics {
                    role = Role.Button
                    contentDescription = "Divider between the top and bottom halves"
                    stateDescription = when (shell.divider) { Divider.Top -> "Top only"; Divider.Split -> "Split"; Divider.Bottom -> "Bottom full" }
                    customActions = Divider.entries.map { d ->
                        CustomAccessibilityAction(when (d) { Divider.Top -> "Top only"; Divider.Split -> "Split"; Divider.Bottom -> "Bottom full" }) { settle(d); true }
                    }
                }
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                    // a tap steps through the three: top → split → bottom → split …
                    settle(when (shell.divider) { Divider.Top -> Divider.Split; Divider.Split -> Divider.Bottom; Divider.Bottom -> Divider.Split })
                }
                .draggable(
                    orientation = Orientation.Vertical,
                    state = rememberDraggableState { dy ->
                        dragP = pAt(topAt(dragP) + dy)
                        if (!reduce) scope.launch { place.snapTo(dragP) }
                    },
                    onDragStarted = { dragging = true; dragP = place.value },
                    onDragStopped = { v ->
                        dragging = false
                        // a fling carries it: aim where it would be in 150 ms
                        val aim = pAt(topAt(dragP) + v * 0.15f)
                        settle(Math.round(aim).coerceIn(0, 2).toDivider())
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.width(44.dp).height(5.dp).background(Tok.lifted, RoundedCornerShape(3.dp)))
        }
    }
}

/** The picture at one divider place. */
@Composable
private fun Layers(p: Float, shell: ShellState, pads: PadsState, editor: EditorState, core: LupeCore, hb: Float, topAt: (Float) -> Float) {
    val density = LocalDensity.current
    fun dp(v: Float) = with(density) { v.dp.toPx() }
    // tabs fade out and the strip fades in as the divider goes past split
    val tabsAlpha = ((1.6f - p) / 0.6f).coerceIn(0f, 1f)
    val stripAlpha = ((p - 1.4f) / 0.6f).coerceIn(0f, 1f)

    Box(Modifier.fillMaxSize()) {
        if (tabsAlpha > 0f) Tabs(shell.tab, { core.send(Intent.SetTab(it)) }, Modifier.padding(horizontal = 8.dp).graphicsLayer { alpha = tabsAlpha })
        if (stripAlpha > 0f) PadsStrip(pads, core, Modifier.padding(horizontal = 8.dp).graphicsLayer { alpha = stripAlpha })

        // top half: from 8 dp under the tabs to 4 dp above the divider
        Box(
            Modifier
                .padding(horizontal = 8.dp)
                .offset(0.dp, TOP_OFFSET.dp)
                .heightPx { (topAt(p) - dp(GAP) - dp(TOP_OFFSET)).toInt() }
                .clipToBounds()
                .graphicsLayer { alpha = (1f - stripAlpha * 2f).coerceIn(0f, 1f) },
        ) { LupeCrossfade(shell.tab, Modifier.fillMaxSize(), Dur.STATE) { if (it == Tab.Pads) PadsPage(pads, core) else TopPlaceholder(it) } }

        // bottom half: from 4 dp under the divider band to the bottom; it follows the FM-1's page
        Box(
            Modifier
                .padding(horizontal = 8.dp)
                .offset { IntOffset(0, (topAt(p) + dp(HANDLE_H) + dp(GAP)).toInt()) }
                .heightPx { (hb - topAt(p) - dp(HANDLE_H) - dp(GAP)).toInt() }
                .clipToBounds(),
        ) {
            // the lane fits only when the bottom half is nearly full height
            val autoFraction = (((hb - topAt(p) - dp(HANDLE_H) - dp(GAP)) - dp(560f)) / dp(100f)).coerceIn(0f, 1f)
            LupeCrossfade(shell.bottom, Modifier.fillMaxSize(), Dur.PANEL) { page ->
                if (page.kind == BottomKind.Editor) EditorPage(editor, core, autoFraction) else com.scottgerstl.lupe.ui.page.SoundOrPlaceholder(page, core)
            }
        }
    }
}
