package com.scottgerstl.lupe.ui.page

import com.scottgerstl.lupe.core.PageRoute
import com.scottgerstl.lupe.core.PageTilesState
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.BoxWithConstraintsScope
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.tanh

// Decision 25: the phone doesn't redraw the FM-1's pictures. Where a knob picks from a list of names, these tiles stand in for it.

// ---- MOD's eleven routes, the pickers' tiles, the dense pages' card

@Composable
internal fun ModRoutes(routes: List<PageRoute>, picked: Int, colour: Color, onPick: (Int) -> Unit, modifier: Modifier) {
    val groups = listOf("LFO" to "LFO →", "ENV" to "ENV →", "SLOTS" to "SLOTS")
    // at split the room is small: the rows keep 36 dp and the list scrolls, rather than three slivers
    BoxWithConstraints(modifier.fillMaxSize()) {
    val squeezed = maxHeight < 140.dp
    Column(Modifier.fillMaxSize().then(if (squeezed) Modifier.verticalScroll(rememberScrollState()) else Modifier), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        groups.forEach { (key, head) ->
            val rows = routes.withIndex().filter { it.value.group == key }
            Row(if (squeezed) Modifier.height(36.dp).fillMaxWidth() else Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                BasicText(head, Modifier.size(width = 40.dp, height = 16.dp), style = LupeType.number.copy(fontSize = 11.sp, color = Tok.text2Raised))
                for (slot in 0 until 4) {
                    val r = rows.getOrNull(slot)
                    if (r == null) { Box(Modifier.weight(1f)); continue }
                    RouteTile(r.value.label, r.value.amount, r.value.empty, r.index == picked, colour, "${head.removeSuffix(" →")} to ${r.value.label}", Modifier.weight(1f).fillMaxSize()) { onPick(r.index) }
                }
            }
        }
    }
    }
}

@Composable
private fun RouteTile(label: String, amount: Int, empty: Boolean, picked: Boolean, colour: Color, desc: String, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(8.dp))
            .background(if (picked) colour.copy(alpha = 0.35f) else Tok.control)
            .then(if (picked) Modifier.drawWithOutline() else Modifier)
            .semantics(mergeDescendants = true) { contentDescription = "$desc, amount $amount" + if (picked) ", picked" else "" }
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick),
    ) {
        BasicText(label, Modifier.align(Alignment.TopStart).padding(start = 8.dp, top = 6.dp), style = LupeType.label.copy(color = if (empty) Tok.text2 else Tok.text), maxLines = 1)
        if (!empty && amount > 0) Box(Modifier.align(Alignment.BottomStart).padding(start = 8.dp, bottom = 6.dp).height(3.dp).fillMaxWidthFraction(amount / 127f * 0.7f).background(colour, RoundedCornerShape(2.dp)))
    }
}

private fun Modifier.fillMaxWidthFraction(f: Float) = this.then(Modifier.fillMaxWidth(f.coerceIn(0.05f, 1f)))
private fun Modifier.drawWithOutline(): Modifier = this.then(Modifier.drawWithContent {
    drawContent()
    drawRoundRect(Tok.text, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(8.dp.toPx()), style = Stroke(2.dp.toPx()))
})

@Composable
internal fun PickTiles(labels: List<String>, picked: Int, colour: Color, onPick: (Int) -> Unit, modifier: Modifier) {
    BoxWithConstraints(modifier.fillMaxSize()) {
    val rowH = if (maxHeight < 100.dp) 36.dp else 48.dp   // squeezed at split: shorter tiles, the list scrolls
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(if (rowH < 48.dp) 4.dp else 8.dp)) {
        labels.withIndex().chunked(4).forEach { row ->
            Row(Modifier.fillMaxWidth().height(rowH), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { (i, t) ->
                    val on = i == picked
                    Box(
                        Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(8.dp)).background(if (on) colour else Tok.control)
                            .semantics(mergeDescendants = true) { contentDescription = t + if (on) ", picked" else "" }
                            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onPick(i) },
                        contentAlignment = Alignment.Center,
                    ) { BasicText(t, style = LupeType.number.copy(fontSize = 16.sp, color = if (on) Tok.onColour else Tok.text), maxLines = 1) }
                }
                repeat(4 - row.size) { Box(Modifier.weight(1f)) }
            }
        }
    }
    }
}


/** What a page shows in place of a picture: tiles where knob 1 picks from a list of names (MOD's routes; LANES, SOUND, OPERATOR), or nothing. */
@Composable
fun PageTilesContent(t: PageTilesState, colour: Color, onPickRoute: (Int) -> Unit, onPickTile: (Int) -> Unit, modifier: Modifier = Modifier) {
    if (t.kind == "routes") ModRoutes(t.routes, t.picked, colour, onPickRoute, modifier) else PickTiles(t.labels, t.picked, colour, onPickTile, modifier)
}
