package com.scottgerstl.lupe.ui.shell

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
 * A connected group (spec 3.4): segments 2 apart; the selected one a full pill in `text` with `onColour` ink (SemiBold), the rest `control` with
 * grey ink, inner corners [Shape.key] and the outer ends round. Used for the tabs and pagers. Each segment's target is at least 48 tall even when
 * drawn at 36 or 40. [selected] −1 selects none.
 */
@Composable
fun SegmentGroup(
    labels: List<String>, selected: Int, onPick: (Int) -> Unit, modifier: Modifier = Modifier, height: Dp = 40.dp, padH: Dp = 16.dp,
    role: Role = Role.Tab, descriptions: List<String> = labels, fontSize: Int = 16, minWidth: Dp = 0.dp,
) {
    Row(modifier.selectableGroup(), horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
        labels.forEachIndexed { i, label ->
            Segment(label, descriptions[i], i == selected, first = i == 0, last = i == labels.lastIndex, height = height, padH = padH, role = role,
                fontSize = fontSize, minWidth = minWidth) { onPick(i) }
        }
    }
}

@Composable
private fun Segment(label: String, description: String, on: Boolean, first: Boolean, last: Boolean, height: Dp, padH: Dp, role: Role, fontSize: Int, minWidth: Dp, onClick: () -> Unit) {
    val reduce = LocalReduceMotion.current
    val m = hybridMotion
    val source = remember { MutableInteractionSource() }
    val focused by source.collectIsFocusedAsState()
    // shape on the spring, colour eased (spec §5: effects never bounce)
    val shape by springFloat(if (on) 1f else 0f, m.fingerMs, m.bounce, spring = !reduce)
    val lit by animatedFloat(if (on) 1f else 0f, Dur.STATE)
    Box(
        Modifier.defaultMinSize(minHeight = 48.dp, minWidth = minWidth)
            .semantics(mergeDescendants = true) { this.role = role; selected = on; contentDescription = description }
            .clickable(interactionSource = source, indication = null, role = role, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.height(height).defaultMinSize(minWidth = minWidth)
                .drawBehind {
                    val pill = size.height / 2
                    val inner = Shape.key.toPx()
                    // with Reduce Motion nothing changes size in flight: the shape lands where it belongs
                    val s = if (reduce) (if (on) 1f else 0f) else shape.coerceIn(0f, 1.2f)
                    fun r(outer: Boolean) = if (outer) pill else inner + (pill - inner) * s
                    segmentShape(lerp(Tok.control, Tok.text, lit), r(first), r(last))
                    if (focused) drawRoundRect(Tok.text, Offset(-3.dp.toPx(), -3.dp.toPx()), Size(size.width + 6.dp.toPx(), size.height + 6.dp.toPx()), CornerRadius(pill + 3.dp.toPx()), style = Stroke(2.dp.toPx()))
                }
                .padding(horizontal = padH),
            contentAlignment = Alignment.Center,
        ) {
            BasicText(
                label, maxLines = 1,
                style = LupeType.key.copy(fontSize = fontSize.sp, lineHeight = (fontSize * 1.2f).sp, color = lerp(Tok.text2, Tok.onColour, lit),
                    fontWeight = if (on) FontWeight.SemiBold else FontWeight.Normal),
            )
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
