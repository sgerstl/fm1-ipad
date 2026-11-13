package com.scottgerstl.lupe.ui.slide

import androidx.compose.foundation.Canvas
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
 * A value set by sliding, for a row inside a menu (decision 10: no − / + anywhere): label, the value large, a gauge at
 * the foot. The slide direction is Settings'; the Magnifier would sit behind the menu's window, so the value is big here
 * instead. [stepDp] is how far a finger moves for one step. TalkBack gets the range, Increase and Decrease.
 */
@Composable
fun MenuSlideRow(
    label: String, text: String, raw: Int, min: Int, max: Int, name: String, modifier: Modifier = Modifier,
    stepDp: Float = 2f, bipolarAt: Int? = null, onSet: (Int) -> Unit,
) {
    val latest by rememberUpdatedState(raw)
    val send by rememberUpdatedState(onSet)
    var base by remember { mutableIntStateOf(0) }
    fun set(v: Int) { val n = v.coerceIn(min, max); if (n != latest) send(n) }
    CompositionLocalProvider(LocalMagnifier provides null) {
        Column(
            modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp).clip(RoundedCornerShape(8.dp)).background(Tok.well)
                .semantics(mergeDescendants = true) {
                    contentDescription = name; stateDescription = text; role = Role.Button
                    progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), min.toFloat()..max.toFloat(), max - min - 1)
                    setProgress { v -> set(v.roundToInt()); true }
                    customActions = listOf(CustomAccessibilityAction("Increase $name") { set(latest + 1); true }, CustomAccessibilityAction("Decrease $name") { set(latest - 1); true })
                }
                .slideToTurn(enabled = true, stepDp = stepDp, face = null, onStart = { base = latest }, onSlide = { set(base + it) }, bounds = { (min - latest)..(max - latest) })
                .padding(10.dp),
        ) {
            BasicText(label, style = LupeType.number.copy(fontSize = 12.sp, color = Tok.text2, letterSpacing = 0.5.sp))
            BasicText(text, style = LupeType.number.copy(fontSize = 28.sp, lineHeight = 30.sp))
            Canvas(Modifier.padding(top = 4.dp).fillMaxWidth().height(3.dp)) {
                drawRect(Tok.stepEmpty)
                val x = if (max > min) ((raw - min).toFloat() / (max - min)) * size.width else 0f
                val from = if (bipolarAt != null && max > min) ((bipolarAt - min).toFloat() / (max - min)) * size.width else 0f
                drawRect(Tok.text, Offset(minOf(from, x), 0f), Size(maxOf(kotlin.math.abs(x - from), if (bipolarAt != null) 2f else 0f), size.height))
            }
        }
    }
}
