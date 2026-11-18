package com.scottgerstl.lupe.ui.shell

import androidx.compose.ui.graphics.graphicsLayer

import androidx.compose.foundation.interaction.collectIsPressedAsState

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import kotlinx.coroutines.launch
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Shape
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import com.scottgerstl.lupe.ui.theme.hybridMotion
import com.scottgerstl.lupe.ui.theme.springFloat

/**
 * Pads · Edit · Timeline · Mix as a connected group of pills (hybrid UI, Scott 2026-11-17: pills over decision 29's words; spec 3.4). The tab
 * showing is a full white pill with dark ink; the others are `control` with grey ink, their inner corners 8 and the group's two ends round.
 * Shape carries the state beside colour: the selected tab's corners spring round, the old one's square off (with Reduce Motion it lands at
 * once and only the colour cross-fades). [padH] is each tab's side padding: 16, or 12 when the header gives way (spec 4.1 step 2).
 */
@Composable
fun Tabs(current: Tab, onPick: (Tab) -> Unit, modifier: Modifier = Modifier, padH: Dp = 16.dp) =
    SegmentGroup(Tab.entries.map { it.name }, current.ordinal, { onPick(Tab.entries[it]) }, modifier, height = 40.dp, padH = padH, role = Role.Tab)

/**
 * A connected group (spec 3.4). The segments are `control` with their inner corners 8 and the group's ends round, 2 apart; one white pill
 * (the selection) slides between them. Shape carries the state and it travels (Scott, 2026-11-17, on the Pixel: "any of those shape
 * transitions that also indicate state should all be animated"): the pill's leading edge springs ahead and its trailing edge follows, so it
 * stretches as it goes and settles on the new segment; the inks blend in 150 ms. With Reduce Motion the pill cross-fades from the old
 * segment to the new one. Labels keep one weight so nothing reflows. [selected] −1 selects none.
 * [selectedFill]/[idleFill]: the Mix sub-pages use a quiet variant (a `lifted` pill over bare words).
 */
@Composable
fun SegmentGroup(
    labels: List<String>, selected: Int, onPick: (Int) -> Unit, modifier: Modifier = Modifier, height: Dp = 40.dp, padH: Dp = 16.dp,
    role: Role = Role.Tab, descriptions: List<String> = labels, fontSize: Int = 16, minWidth: Dp = 0.dp,
    fill: Boolean = false, wrap: Boolean = false, selectedFill: Color = Tok.text, idleFill: Color? = Tok.control, selectedInk: Color = Tok.onColour, idleInk: Color = Tok.text2,
    gap: Dp = 2.dp,
) {
    val reduce = LocalReduceMotion.current
    val m = hybridMotion
    val density = androidx.compose.ui.platform.LocalDensity.current
    // each segment's place in the row (px), measured
    val lefts = remember(labels.size) { androidx.compose.runtime.mutableStateListOf<Float>().apply { repeat(labels.size) { add(-1f) } } }
    val widths = remember(labels.size) { androidx.compose.runtime.mutableStateListOf<Float>().apply { repeat(labels.size) { add(0f) } } }
    val known = selected in labels.indices && widths.getOrElse(selected) { 0f } > 0f
    val targetL = if (known) lefts[selected] else 0f
    val targetR = if (known) lefts[selected] + widths[selected] else 0f
    val l = remember { androidx.compose.animation.core.Animatable(-1f) }
    val r = remember { androidx.compose.animation.core.Animatable(-1f) }
    // Reduce Motion: the old place and the new, cross-fading
    var fromSel by remember { androidx.compose.runtime.mutableIntStateOf(selected) }
    val fade = remember { androidx.compose.animation.core.Animatable(1f) }
    androidx.compose.runtime.LaunchedEffect(targetL, targetR, known) {
        if (!known) return@LaunchedEffect
        if (l.value < 0f || reduce) { l.snapTo(targetL); r.snapTo(targetR) }
        if (reduce) return@LaunchedEffect
        val right = targetL > l.value
        // the leading edge is quicker, the trailing one slower: the pill stretches toward the new segment, then gathers there
        kotlinx.coroutines.coroutineScope {
            // round 3: M3 Expressive's spatial spring (Labs › Shape spring); the leading edge on a 1.8× stiffer one so the pill visibly stretches
            val lead = androidx.compose.animation.core.spring<Float>(dampingRatio = m.spatialDamping, stiffness = m.spatialStiffness * 1.8f)
            val trail = androidx.compose.animation.core.spring<Float>(dampingRatio = m.spatialDamping, stiffness = m.spatialStiffness * 0.85f)
            launch { com.scottgerstl.lupe.ui.theme.unscaled { l.animateTo(targetL, if (right) trail else lead) } }
            launch { com.scottgerstl.lupe.ui.theme.unscaled { r.animateTo(targetR, if (right) lead else trail) } }
        }
    }
    androidx.compose.runtime.LaunchedEffect(selected) {
        if (!reduce) { fromSel = selected; return@LaunchedEffect }
        fade.snapTo(0f); com.scottgerstl.lupe.ui.theme.unscaled { fade.animateTo(1f, androidx.compose.animation.core.tween(Dur.STATE, easing = com.scottgerstl.lupe.ui.theme.EaseOut)) }; fromSel = selected
    }
    // each segment's press (Scott, 2026-11-17: the tap's own reaction, with elasticity): read while drawing, so a press redraws only the row
    val presses = remember(labels.size) { arrayOfNulls<androidx.compose.runtime.State<Float>>(labels.size) }
    fun sc(i: Int) = presses.getOrNull(i)?.value ?: 1f
    Row(
        modifier.selectableGroup().drawBehind {
            val h = height.toPx(); val top = (size.height - h) / 2
            val pill = h / 2; val inner = Shape.key.toPx()
            // the segments' own shapes
            if (idleFill != null) for (i in labels.indices) {
                if (widths[i] <= 0f) continue
                val outerL = i == 0; val outerR = i == labels.lastIndex
                val lr = CornerRadius(if (outerL) pill else inner); val rr = CornerRadius(if (outerR) pill else inner)
                val k = sc(i); val w = widths[i] * k; val hh = h * k; val x = lefts[i] + (widths[i] - w) / 2; val y = top + (h - hh) / 2
                val lr2 = CornerRadius(lr.x * k); val rr2 = CornerRadius(rr.x * k)
                drawPath(Path().apply { addRoundRect(RoundRect(x, y, x + w, y + hh, lr2, rr2, rr2, lr2)) }, idleFill)
            }
            // the selection
            fun pillAt(a: Float, b: Float, alpha: Float) { if (b > a && alpha > 0f) drawRoundRect(selectedFill.copy(alpha = selectedFill.alpha * alpha), Offset(a, top), Size(b - a, h), CornerRadius(pill)) }
            if (!known) return@drawBehind
            if (reduce) {
                if (fromSel in labels.indices && fromSel != selected) pillAt(lefts[fromSel], lefts[fromSel] + widths[fromSel], 1f - fade.value)
                pillAt(targetL, targetR, if (fromSel != selected) fade.value else 1f)
            } else {
                // stretched, the pill thins a little (squash and stretch), back to full height as it gathers
                val natural = (targetR - targetL).coerceAtLeast(1f)
                val stretch = ((r.value - l.value) / natural - 1f).coerceIn(0f, 1f)
                val thin = h * m.squash * 1.2f * stretch
                // the pill takes the press of the segment it sits on
                val cx = (l.value + r.value) / 2
                val under = labels.indices.minByOrNull { kotlin.math.abs(lefts[it] + widths[it] / 2 - cx) } ?: 0
                val k = sc(under); val w = (r.value - l.value) * k; val hh = (h - thin) * k
                if (r.value > l.value) drawRoundRect(selectedFill, Offset(cx - w / 2, top + (h - hh) / 2), Size(w, hh), CornerRadius(hh / 2))
            }
        },
        horizontalArrangement = Arrangement.spacedBy(gap), verticalAlignment = Alignment.CenterVertically,
    ) {
        labels.forEachIndexed { i, label ->
            val on = i == selected
            val lit by animatedFloat(if (on) 1f else 0f, Dur.STATE)
            val source = remember { MutableInteractionSource() }
            val focused by source.collectIsFocusedAsState()
            val pressed by source.collectIsPressedAsState()
            val press = com.scottgerstl.lupe.ui.theme.pressScale(pressed, reduce)
            val light = com.scottgerstl.lupe.ui.theme.pressedLight(pressed, reduce)
            presses[i] = press
            Box(
                (if (fill) Modifier.weight(1f) else Modifier)
                    .defaultMinSize(minHeight = 48.dp, minWidth = minWidth)
                    .onGloballyPositioned { c -> val x = c.positionInParent().x; val w = c.size.width.toFloat(); if (lefts.getOrNull(i) != x) lefts[i] = x; if (widths.getOrNull(i) != w) widths[i] = w }
                    .semantics(mergeDescendants = true) { this.role = role; this.selected = on; contentDescription = descriptions[i] }
                    .clickable(interactionSource = source, indication = null, role = role) { onPick(i) }
                    .drawBehind {
                        val h = height.toPx()
                        if (light.value > 0f) drawRoundRect(Tok.text.copy(alpha = 0.12f * light.value), Offset(0f, (size.height - h) / 2), Size(size.width, h), CornerRadius(h / 2))   // Reduce Motion's press
                        if (focused) drawRoundRect(Tok.text, Offset(-3.dp.toPx(), (size.height - h) / 2 - 3.dp.toPx()), Size(size.width + 6.dp.toPx(), h + 6.dp.toPx()), CornerRadius(h / 2 + 3.dp.toPx()), style = Stroke(2.dp.toPx()))
                    }
                    .graphicsLayer { val k = press.value; scaleX = k; scaleY = k }
                    .padding(horizontal = padH),
                contentAlignment = Alignment.Center,
            ) {
                // [wrap]: a label too long for its share goes onto a second line rather than being cut (Settings at large font sizes)
                BasicText(label, maxLines = if (wrap) 2 else 1,
                    style = LupeType.key.copy(fontSize = fontSize.sp, lineHeight = (fontSize * 1.2f).sp, color = lerp(idleInk, selectedInk, lit), fontWeight = FontWeight.SemiBold,
                        textAlign = if (wrap) androidx.compose.ui.text.style.TextAlign.Center else androidx.compose.ui.text.style.TextAlign.Unspecified))
            }
        }
    }
}

/** A rounded rect whose left corners are [left] and right corners [right] (the connected group's outer ends round, inner ones tighter). */
internal fun DrawScope.segmentShape(color: Color, left: Float, right: Float) {
    val l = CornerRadius(left.coerceAtMost(size.height / 2)); val r = CornerRadius(right.coerceAtMost(size.height / 2))
    drawPath(Path().apply { addRoundRect(RoundRect(0f, 0f, size.width, size.height, l, r, r, l)) }, color)
}

/** The connected group's segment shape, for other packages (Settings' segments). */
object SegmentDraw {
    fun DrawScope.segment(color: Color, left: Float, right: Float) = segmentShape(color, left, right)
}
