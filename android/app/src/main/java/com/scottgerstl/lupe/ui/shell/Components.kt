package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * The flat chiclet (tokens.chiclet): a top standing on a hard 2 dp base edge. Pressed, the top drops onto the
 * edge in 60 ms and comes back in 100 ms. [on] is a latched toggle (the primary look, blended in 150 ms).
 *
 * The touch target is at least 48 × 48 dp even where the drawn key is 44: the visible key sits centred in it.
 */
@Composable
fun Key(
    onClick: () -> Unit,
    description: String,
    modifier: Modifier = Modifier,
    width: Dp? = null,
    height: Dp = 44.dp,
    on: Boolean = false,
    enabled: Boolean = true,
    role: Role = Role.Button,
    state: String? = null,
    onLongClick: (() -> Unit)? = null,
    minTarget: Dp = 48.dp,
    /** Fill the width it is given (a Cancel under a confirm) instead of a fixed one: a key's width is never allowed to cut its label. */
    fill: Boolean = false,
    litTop: Color = Tok.primaryTop,
    litEdge: Color = Tok.primaryEdge,
    content: @Composable BoxScope.(Color) -> Unit,
) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val focused by source.collectIsFocusedAsState()
    val drop = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100, easing = androidx.compose.animation.core.LinearEasing)
    val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
    Box(
        modifier
            .defaultMinSize(minTarget, minTarget)
            .then(if (fill) Modifier else Modifier.width(maxOf(width ?: 44.dp, minTarget)))
            .semantics(mergeDescendants = true) {
                contentDescription = description
                this.role = role
                if (state != null) stateDescription = state
                if (!enabled) disabled()
            }
            .combinedClickable(
                interactionSource = source, indication = null, enabled = enabled, role = role,
                onClick = onClick, onLongClick = onLongClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        val fg = lerp(Tok.text, Tok.onColour, lit.value).let { if (enabled) it else Tok.text2 }
        Box(
            Modifier
                .then(if (fill) Modifier.fillMaxWidth() else Modifier.width(width ?: 44.dp))
                .height(height)
                .drawBehind {
                    val r = CornerRadius(Tok.CHICLET_RADIUS.dp.toPx())
                    val e = Tok.CHICLET_EDGE.dp.toPx()
                    drawRoundRect(lerp(Tok.chicletEdge, litEdge, lit.value), Offset(0f, e), size, r)
                    drawRoundRect(lerp(Tok.control, litTop, lit.value), Offset(0f, drop.value * e), size, r)
                    // keyboard focus: a 2 dp ring outside the key, text.primary on the page (well over 3:1)
                    if (focused) drawRoundRect(Tok.text, Offset(-3.dp.toPx(), -3.dp.toPx()), Size(size.width + 6.dp.toPx(), size.height + 6.dp.toPx() + e), CornerRadius(r.x + 3.dp.toPx()), style = Stroke(2.dp.toPx()))
                }
                .graphicsLayer { translationY = drop.value * Tok.CHICLET_EDGE.dp.toPx() },
            contentAlignment = Alignment.Center,
        ) { content(fg) }
    }
}

@Composable
fun KeyLabel(text: String, color: Color, modifier: Modifier = Modifier, style: TextStyle = LupeType.key) {
    BasicText(text, modifier, style.copy(color = color), maxLines = 1, overflow = TextOverflow.Ellipsis)
}

/** A label with a ⌄ after it, drawn (not a glyph), for the keys that open a menu. */
@Composable
fun MenuLabel(text: String, color: Color, sub: String? = null, textMax: Dp = 62.dp) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            KeyLabel(text, color, Modifier.widthIn(max = textMax))
            Spacer(Modifier.width(4.dp))
            Chevron(Tok.text2Raised.takeIf { color == Tok.text } ?: color)
        }
        if (sub != null) BasicText(sub, style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1)
    }
}

// ---- icons, drawn: one stroke width, one colour each, nothing from a symbol font

@Composable
fun Chevron(color: Color, modifier: Modifier = Modifier) =
    Canvas(modifier.size(10.dp, 6.dp)) {
        val p = Path().apply { moveTo(1.dp.toPx(), 1.dp.toPx()); lineTo(size.width / 2, size.height - 1.dp.toPx()); lineTo(size.width - 1.dp.toPx(), 1.dp.toPx()) }
        drawPath(p, color, style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }

fun DrawScope.playTriangle(color: Color) {
    val w = size.width; val h = size.height
    drawPath(Path().apply { moveTo(w * 0.1f, 0f); lineTo(w, h / 2); lineTo(w * 0.1f, h); close() }, color)
}

/** ▶ and ■, crossfading by [stop] (0 = play, 1 = stop). The shape carries the state, not only the key's colour. */
@Composable
fun PlayStopIcon(stop: Float, color: Color) =
    Canvas(Modifier.size(16.dp)) {
        if (stop < 1f) { drawContext.canvas.save(); playTriangle(color.copy(alpha = 1f - stop)); drawContext.canvas.restore() }
        if (stop > 0f) drawRoundRect(color.copy(alpha = stop), Offset(size.width * 0.1f, size.height * 0.1f), Size(size.width * 0.8f, size.height * 0.8f), CornerRadius(2.dp.toPx()))
    }

@Composable
fun Check(color: Color) =
    Canvas(Modifier.size(14.dp, 12.dp)) {
        val p = Path().apply { moveTo(1.dp.toPx(), size.height * 0.55f); lineTo(size.width * 0.38f, size.height - 1.dp.toPx()); lineTo(size.width - 1.dp.toPx(), 1.dp.toPx()) }
        drawPath(p, color, style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }

@Composable
fun Panel(modifier: Modifier = Modifier, radius: Dp = 12.dp, color: Color = Tok.panel, content: @Composable () -> Unit) =
    Box(modifier.clip(RoundedCornerShape(radius)).background(color)) { content() }

/** A key as wide as its row (Cancel under a confirm). 36 dp tall, the chiclet look. */
@Composable
fun WideKey(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val drop = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100, easing = androidx.compose.animation.core.LinearEasing)
    Box(
        modifier.fillMaxWidth().height(36.dp)
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = text }
            .combinedClickable(interactionSource = source, indication = null, role = Role.Button, onClick = onClick)
            .drawBehind {
                val r = CornerRadius(Tok.CHICLET_RADIUS.dp.toPx()); val e = Tok.CHICLET_EDGE.dp.toPx()
                drawRoundRect(Tok.chicletEdge, Offset(0f, e), Size(size.width, size.height - e), r)
                drawRoundRect(Tok.control, Offset(0f, drop.value * e), Size(size.width, size.height - e), r)
            },
        contentAlignment = Alignment.Center,
    ) { KeyLabel(text, Tok.text) }
}
