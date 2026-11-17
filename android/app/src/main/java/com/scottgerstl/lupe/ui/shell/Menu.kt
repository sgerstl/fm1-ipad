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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.unit.sp
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
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
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
    val t = animatedFloat(if (open) 1f else 0f, if (open) Dur.FINGER else 120, if (open) EaseOut else EaseIn)
    // hybrid UI (spec §5, "popup or menu from a control"): it grows from 0.94 and drops 12 into place on the spring; the fade eases. Exits are quicker.
    val hm = com.scottgerstl.lupe.ui.theme.hybridMotion
    val grow by com.scottgerstl.lupe.ui.theme.springFloat(if (open) 1f else 0f, if (open) hm.fingerMs else 120, if (open) hm.sheetBounce else 0f, spring = !reduce)
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
                    val right = fx + side + popupContentSize.width + margin <= windowSize.width
                    val leftX = fx - side - popupContentSize.width
                    // no room beside the finger on either side: above it (never over it)
                    if (!right && leftX < margin) return IntOffset((fx - popupContentSize.width / 2).coerceIn(margin, (windowSize.width - popupContentSize.width - margin).coerceAtLeast(margin)),
                        (fy - side * 2 - popupContentSize.height).coerceAtLeast(margin))
                    val x = if (right) fx + side else leftX
                    return IntOffset(x.coerceIn(margin, (windowSize.width - popupContentSize.width - margin).coerceAtLeast(margin)),
                        (fy - side).coerceIn(margin, (windowSize.height - popupContentSize.height - margin).coerceAtLeast(margin)))
                }
                val x = if (alignEnd) anchorBounds.right - popupContentSize.width else anchorBounds.left
                // under the anchor; a menu taller than the room left moves up rather than off the screen
                val y = (anchorBounds.bottom + gap).coerceAtMost((windowSize.height - popupContentSize.height - margin).coerceAtLeast(margin))
                return IntOffset(x.coerceIn(margin, (windowSize.width - popupContentSize.width - margin).coerceAtLeast(margin)), y)
            }
        }
    }
    // At most the window minus the system bars and a margin each end, and it scrolls: P4's page scenarios made
    // the FM-1 key's menu taller than the screen (Scott's run, 2026-11-13, P4 check 10).
    val density = androidx.compose.ui.platform.LocalDensity.current
    val windowH = androidx.compose.ui.platform.LocalWindowInfo.current.containerSize.height
    val bars = WindowInsets.systemBars.getTop(density) + WindowInsets.systemBars.getBottom(density)
    val maxH = with(density) { (windowH - bars - 2 * margin).coerceAtLeast(margin).toDp() }
    Popup(popupPositionProvider = provider, onDismissRequest = onDismiss, properties = PopupProperties(focusable = true)) {
        Column(
            Modifier
                .width(width)
                .heightIn(max = maxH)
                .graphicsLayer {
                    alpha = t.value
                    if (!reduce) {
                        val s = 0.94f + 0.06f * grow
                        scaleX = s; scaleY = s
                        if (at == null) translationY = -12.dp.toPx() * (1f - grow)
                        transformOrigin = TransformOrigin(if (alignEnd) 1f else 0f, if (at != null) 0.2f else 0f)
                    }
                    shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(com.scottgerstl.lupe.ui.theme.Shape.panel); clip = true
                    ambientShadowColor = androidx.compose.ui.graphics.Color.Black; spotShadowColor = androidx.compose.ui.graphics.Color.Black
                }
                .background(Tok.held, RoundedCornerShape(com.scottgerstl.lupe.ui.theme.Shape.panel))
                .verticalScroll(rememberScrollState())
                .padding(6.dp),
        ) { content() }
    }
}

/**
 * A menu row (spec 3.9): 44 tall (52 with a second line), radius 10. [checked] is shape as state: the row becomes a `lifted` pill with a tick,
 * and says "selected" to TalkBack. The second line is `textSecondaryRaised` (the plain secondary grey is 4.13:1 on `held`).
 */
@Composable
fun MenuRow(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, checked: Boolean? = null, enabled: Boolean = true, sub: String? = null) {
    // the checked pill grows in from the row's middle and its tick fades in; moving the tick to another row, the old pill shrinks away
    val reduce = LocalReduceMotion.current
    val hm = com.scottgerstl.lupe.ui.theme.hybridMotion
    val on = checked == true
    val lit by animatedFloat(if (on) 1f else 0f, Dur.STATE)
    val grow by com.scottgerstl.lupe.ui.theme.springFloat(if (on) 1f else 0f, hm.fingerMs, hm.bounce, spring = !reduce)
    Row(
        modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = if (sub != null) 52.dp else 44.dp)
            .drawBehind {
                if (lit <= 0f) return@drawBehind
                val g = if (reduce) 1f else (0.85f + 0.15f * grow).coerceIn(0.85f, 1.02f)
                val w = size.width * g; val h = size.height * g
                drawRoundRect(Tok.lifted.copy(alpha = lit), androidx.compose.ui.geometry.Offset((size.width - w) / 2, (size.height - h) / 2), androidx.compose.ui.geometry.Size(w, h), androidx.compose.ui.geometry.CornerRadius(h / 2))
            }
            .semantics(mergeDescendants = true) {
                role = Role.Button
                if (checked == true) selected = true
                if (!enabled) disabled()
            }
            .clip(RoundedCornerShape(10.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            BasicText(text, style = LupeType.key.copy(fontSize = 16.sp, lineHeight = 19.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal, color = if (enabled) Tok.text else Tok.text2Raised))
            if (sub != null) BasicText(sub, style = LupeType.small.copy(color = Tok.text2Raised))
        }
        if (lit > 0f) { Spacer(Modifier.width(8.dp)); Box(Modifier.graphicsLayer { alpha = lit }) { Check(Tok.text) } }
    }
}

@Composable
fun MenuHeading(text: String) =
    BasicText(text.uppercase(), Modifier.padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 2.dp), style = LupeType.label.copy(color = Tok.text2Raised))

@Composable
fun MenuDivider() = Box(Modifier.fillMaxWidth().padding(vertical = 4.dp).height(1.dp).background(Tok.lifted))
