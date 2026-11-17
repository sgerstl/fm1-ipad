package com.scottgerstl.lupe.ui.page

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.SlideDirection
import com.scottgerstl.lupe.ui.slide.slideToTurn
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * The hybrid parameter tile (spec 3.7; the Edit step panel's Notes, 2026-11-17): `lifted` at radius 10, 12/10 inside. The label in Barlow 12 grey,
 * uppercase as the FM-1 prints it; the FM-1's knob number in an 18 round `panel` badge; the value large (Barlow Condensed Bold 24) with its unit;
 * a 4-tall `panel` track along the foot, its active part in [tint]. A finger slid sideways along it changes the value by steps (only once the drag
 * is clearly sideways, so a vertical drag passes on); double tap puts back what this tile changed. [num]/[min]/[max] give the gauge and TalkBack's
 * range; without them it reads a value with no range (PITCH). [locked] marks a lock on this step (◆ by the label).
 */
@Composable
fun ParamTile(
    label: String, knob: Int?, value: String, name: String, tint: Color, key: Any, modifier: Modifier = Modifier,
    unit: String? = null, num: Int? = null, min: Int = 0, max: Int = 0, bipolar: Boolean = false, dpPerStep: Float = 12f, tick: Boolean = false,
    locked: Boolean = false, limitWord: String? = null, onSteps: (Int) -> Unit,
) {
    val haptic = LocalHapticFeedback.current
    val send by rememberUpdatedState(onSteps)
    var net by remember(key) { mutableStateOf(0) }
    var last by remember { mutableStateOf(0) }
    var hot by remember { mutableStateOf(false) }
    val hotF = animatedFloat(if (hot) 1f else 0f, Dur.STATE).value
    val fraction = if (num != null && max > min) (num - min).toFloat() / (max - min) else null
    val shown by rememberUpdatedState(value)
    val frac by rememberUpdatedState(fraction)
    fun step(d: Int) { if (d == 0) return; net += d; send(d); if (tick) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
    Column(
        modifier.clip(RoundedCornerShape(10.dp)).background(lerp(Tok.lifted, Tok.held, hotF))
            .semantics(mergeDescendants = true) {
                contentDescription = name + (knob?.let { ", FM-1 knob $it" } ?: "") + if (locked) ", locked on this step" else ""
                stateDescription = value + (unit?.let { " $it" } ?: "") + (if (num != null) ", range $min to $max" else "") + (limitWord?.let { ", can't grow: $it" } ?: "")
                role = Role.Button
                if (num != null) {
                    progressBarRangeInfo = ProgressBarRangeInfo(num.toFloat(), min.toFloat()..max.toFloat(), (max - min - 1).coerceAtLeast(0))
                    setProgress { v -> step(kotlin.math.round(v).toInt() - num); true }
                }
                customActions = listOf(
                    CustomAccessibilityAction("Increase $name") { step(1); true },
                    CustomAccessibilityAction("Decrease $name") { step(-1); true },
                    CustomAccessibilityAction("Put $name back as it was") { val b = -net; net = 0; send(b); true },
                )
            }
            .pointerInput(key) { detectTapGestures(onDoubleTap = { val b = -net; net = 0; if (b != 0) { send(b); haptic.performHapticFeedback(HapticFeedbackType.Confirm) } }) }
            .slideToTurn(
                enabled = true, stepDp = dpPerStep,
                face = remember(label, tint) { MagnifierFace(label, { shown }, { frac }, bipolar, ring = false, tint = tint) },
                onStart = { last = 0; hot = true }, onSlide = { total -> step(total - last); last = total }, onEnd = { hot = false },
                bounds = { num?.let { n -> -(n - min)..(max - n) } },
                onLimit = { haptic.performHapticFeedback(HapticFeedbackType.ContextClick) },
                forceDirection = SlideDirection.Sideways, strictAxis = true,
            )
            .padding(start = 12.dp, end = 10.dp, top = 10.dp, bottom = 10.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (locked) { Canvas(Modifier.size(8.dp)) { val r = size.width / 2; drawPath(androidx.compose.ui.graphics.Path().apply { moveTo(r, 0f); lineTo(size.width, r); lineTo(r, size.height); lineTo(0f, r); close() }, tint) }; Spacer(Modifier.width(6.dp)) }
            BasicText(label.uppercase(), Modifier.weight(1f), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp), maxLines = 1)
            if (knob != null) Box(Modifier.size(18.dp).background(Tok.panel, CircleShape), contentAlignment = Alignment.Center) {
                BasicText("$knob", style = LupeType.number.copy(fontSize = 11.sp, lineHeight = 11.sp, fontWeight = FontWeight.Bold, color = Tok.text2Raised))
            }
        }
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            BasicText(value, style = LupeType.number.copy(fontSize = 24.sp, lineHeight = 24.sp, fontWeight = FontWeight.Bold), maxLines = 1)
            if (unit != null) { Spacer(Modifier.width(4.dp)); BasicText(unit, Modifier.padding(bottom = 2.dp), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised), maxLines = 1) }
        }
        Spacer(Modifier.height(8.dp))
        Canvas(Modifier.fillMaxWidth().height(4.dp)) {
            val r = CornerRadius(2.dp.toPx())
            drawRoundRect(Tok.panel, cornerRadius = r)
            val f = fraction ?: return@Canvas
            if (bipolar) { val c = size.width / 2; val x = size.width * f; drawRoundRect(tint, Offset(minOf(c, x), 0f), Size(kotlin.math.abs(x - c).coerceAtLeast(2.dp.toPx()), size.height), r) }
            else drawRoundRect(tint, size = Size(size.width * f.coerceIn(0f, 1f), size.height), cornerRadius = r)
        }
    }
}
