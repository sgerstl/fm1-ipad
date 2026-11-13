package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * Lupe's menu: elevation 3 (held surface, the soft shadow), opening from the key that asked for it in 200 ms
 * (fade and a small grow out of the key's corner; fade only with Reduce Motion), leaving in 150. Back, or a
 * tap outside, closes it. Put this inside the key's Box so it anchors to it.
 */
@Composable
fun LupeMenu(open: Boolean, onDismiss: () -> Unit, alignEnd: Boolean = false, width: Dp = 220.dp, at: androidx.compose.ui.geometry.Offset? = null, content: @Composable () -> Unit) {
    val reduce = LocalReduceMotion.current
    var show by remember { mutableStateOf(false) }
    val t = animatedFloat(if (open) 1f else 0f, if (open) Dur.FINGER else Dur.EXIT, if (open) EaseOut else EaseIn)
    if (open && !show) show = true
    LaunchedEffect(open, t.value) { if (!open && t.value <= 0.001f) show = false }
    if (!show) return
    val gap = with(androidx.compose.ui.platform.LocalDensity.current) { 4.dp.roundToPx() }
    val margin = with(androidx.compose.ui.platform.LocalDensity.current) { 8.dp.roundToPx() }
    val provider = remember(alignEnd, gap, margin, at) {
        object : PopupPositionProvider {
            override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize): IntOffset {
                // beside the finger: to its right, or its left when there is no room; level with it
                if (at != null) {
                    val fx = anchorBounds.left + at.x.toInt(); val fy = anchorBounds.top + at.y.toInt()
                    val side = gap * 3
                    val x = if (fx + side + popupContentSize.width + margin <= windowSize.width) fx + side else fx - side - popupContentSize.width
                    return IntOffset(x.coerceIn(margin, (windowSize.width - popupContentSize.width - margin).coerceAtLeast(margin)),
                        (fy - side).coerceIn(margin, (windowSize.height - popupContentSize.height - margin).coerceAtLeast(margin)))
                }
                val x = if (alignEnd) anchorBounds.right - popupContentSize.width else anchorBounds.left
                return IntOffset(x.coerceIn(margin, (windowSize.width - popupContentSize.width - margin).coerceAtLeast(margin)), anchorBounds.bottom + gap)
            }
        }
    }
    Popup(popupPositionProvider = provider, onDismissRequest = onDismiss, properties = PopupProperties(focusable = true)) {
        Column(
            Modifier
                .width(width)
                .graphicsLayer {
                    alpha = t.value
                    if (!reduce) {
                        val s = 0.96f + 0.04f * t.value
                        scaleX = s; scaleY = s
                        transformOrigin = TransformOrigin(if (alignEnd) 1f else 0f, if (at != null) 0.2f else 0f)
                    }
                    shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(12.dp); clip = true
                    ambientShadowColor = androidx.compose.ui.graphics.Color.Black; spotShadowColor = androidx.compose.ui.graphics.Color.Black
                }
                .background(Tok.held, RoundedCornerShape(12.dp))
                .padding(vertical = 6.dp),
        ) { content() }
    }
}

/** A menu row, 48 dp tall; [checked] draws a tick, and the row says "selected" to TalkBack. */
@Composable
fun MenuRow(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, checked: Boolean? = null, enabled: Boolean = true, sub: String? = null) {
    Row(
        modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 48.dp)
            .semantics(mergeDescendants = true) {
                role = Role.Button
                if (checked == true) selected = true
                if (!enabled) disabled()
            }
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            BasicText(text, style = LupeType.key.copy(color = if (enabled) Tok.text else Tok.text2))
            if (sub != null) BasicText(sub, style = LupeType.small)
        }
        if (checked == true) { Spacer(Modifier.width(8.dp)); Check(Tok.text) }
    }
}

@Composable
fun MenuHeading(text: String) =
    BasicText(text.uppercase(), Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 2.dp), style = LupeType.label)

@Composable
fun MenuDivider() = Box(Modifier.fillMaxWidth().padding(vertical = 4.dp).height(1.dp).background(Tok.lifted))
