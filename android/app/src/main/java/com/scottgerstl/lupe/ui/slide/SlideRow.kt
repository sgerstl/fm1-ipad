package com.scottgerstl.lupe.ui.slide

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.geometry.Size
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import kotlin.math.roundToInt

/**
 * A value set by sliding, for a row in a menu or a sheet (decision 10: no − / + anywhere). Hybrid layout (Scott, 2026-11-17): the label and the
 * value on the left half, the slider on the right half, so the left is a clear lane to scroll in. The slider takes only a sideways drag, and only
 * once it is clearly sideways; an up-and-down drag goes to the scroll. [stepDp] is how far a finger moves for one step. Double tap puts it back to
 * [revertTo]. TalkBack gets the range, Increase and Decrease.
 */
@Composable
fun MenuSlideRow(
    label: String, text: String, raw: Int, min: Int, max: Int, name: String, modifier: Modifier = Modifier,
    stepDp: Float = 2f, bipolarAt: Int? = null, revertTo: Int? = null, onSet: (Int) -> Unit,
) {
    val latest by rememberUpdatedState(raw)
    val shownText by rememberUpdatedState(text)
    val shownRaw by rememberUpdatedState(raw)
    val send by rememberUpdatedState(onSet)
    var base by remember { mutableIntStateOf(0) }
    fun set(v: Int) { val n = v.coerceIn(min, max); if (n != latest) send(n) }
    val loupe = remember { MagnifierState().also { it.screenSpace = true } }
    val face = remember(label, min, max, bipolarAt) { MagnifierFace(label, { shownText }, { if (max > min) (shownRaw - min).toFloat() / (max - min) else 0f }, bipolar = bipolarAt != null) }
    CompositionLocalProvider(LocalMagnifier provides loupe) {
        MagnifierPopup(loupe)
        androidx.compose.foundation.layout.Row(
            modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp).clip(RoundedCornerShape(12.dp)).background(Tok.well)
                .semantics(mergeDescendants = true) {
                    contentDescription = name; stateDescription = text; role = Role.Button
                    progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), min.toFloat()..max.toFloat(), max - min - 1)
                    setProgress { v -> set(v.roundToInt()); true }
                    customActions = listOf(CustomAccessibilityAction("Increase $name") { set(latest + 1); true }, CustomAccessibilityAction("Decrease $name") { set(latest - 1); true })
                }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                BasicText(label, style = LupeType.number.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp), maxLines = 2)
                BasicText(text, style = LupeType.number.copy(fontSize = 24.sp, lineHeight = 26.sp))
            }
            // the slider: the right half, a 44 tall touch lane with an 8 tall track and a 4 × 16 handle (spec 3.13's send)
            androidx.compose.foundation.layout.Box(
                Modifier.weight(1f).height(44.dp)
                    .then(if (revertTo != null) Modifier.pointerInput(revertTo) { detectTapGestures(onDoubleTap = { set(revertTo) }) } else Modifier)
                    .slideToTurn(enabled = true, stepDp = stepDp, face = face, forceDirection = SlideDirection.Sideways, strictAxis = true,
                        onStart = { base = latest }, onSlide = { set(base + it) }, bounds = { (min - latest)..(max - latest) }),
            ) {
                Canvas(Modifier.fillMaxWidth().height(44.dp)) {
                    val th = 8.dp.toPx(); val y = (size.height - th) / 2; val hw = 4.dp.toPx()
                    val f = if (max > min) (raw - min).toFloat() / (max - min) else 0f
                    val x = hw / 2 + (size.width - hw) * f
                    drawRoundRect(Tok.lifted, Offset(0f, y), Size(size.width, th), androidx.compose.ui.geometry.CornerRadius(th / 2))
                    val from = if (bipolarAt != null && max > min) hw / 2 + (size.width - hw) * ((bipolarAt - min).toFloat() / (max - min)) else 0f
                    drawRoundRect(Tok.text, Offset(minOf(from, x), y), Size(maxOf(kotlin.math.abs(x - from), if (bipolarAt != null) 2f else 0f), th), androidx.compose.ui.geometry.CornerRadius(th / 2))
                    drawRoundRect(Tok.text, Offset(x - hw / 2, (size.height - 16.dp.toPx()) / 2), Size(hw, 16.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()))
                }
            }
        }
    }
}
