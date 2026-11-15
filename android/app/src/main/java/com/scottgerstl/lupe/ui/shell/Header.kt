package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

// DESIGN.md "The header is chrome, not content": the square key is the content's shape; the header uses words and rounds.

/**
 * A word with a ⌄ that opens a menu (the project, Loop): no box. The touch area is 48 dp tall and at least 48 wide; a
 * press fills a soft well behind the word, and keyboard focus rings it (2 dp, text on the page).
 */
@Composable
fun HeaderWord(onClick: () -> Unit, description: String, text: String, size: Int, primary: Boolean, modifier: Modifier = Modifier, sub: String? = null, textMax: Dp = 110.dp) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val focused by source.collectIsFocusedAsState()
    val fill = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else Dur.STATE)
    Box(
        modifier
            .defaultMinSize(48.dp, 48.dp)
            .semantics(mergeDescendants = true) { contentDescription = description; role = Role.Button }
            .clickable(interactionSource = source, indication = null, role = Role.Button, onClick = onClick)
            .drawBehind {
                val r = androidx.compose.ui.geometry.CornerRadius(8.dp.toPx())
                val inset = 4.dp.toPx()
                if (fill.value > 0f) drawRoundRect(Tok.control.copy(alpha = fill.value), Offset(0f, inset), Size(this.size.width, this.size.height - 2 * inset), r)
                if (focused) drawRoundRect(Tok.text, Offset(1.dp.toPx(), inset), Size(this.size.width - 2.dp.toPx(), this.size.height - 2 * inset), r, style = Stroke(2.dp.toPx()))
            }
            .padding(horizontal = 8.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                BasicText(text, Modifier.widthIn(max = textMax), style = LupeType.key.copy(fontSize = size.sp, lineHeight = (size * 1.2f).sp, color = if (primary) Tok.text else Tok.text2Raised), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                Spacer(Modifier.width(4.dp))
                Chevron(Tok.text2Raised)
            }
            if (sub != null) BasicText(sub, style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1)
        }
    }
}

/**
 * Record and Play: round, as the FM-1's buttons are. 40 dp across inside a 48 dp target. [lit] fills the circle in
 * [litColour] (REC red latched; white while playing); otherwise a ring in the outline token. A press dims the fill or
 * lays a soft white wash. Keyboard focus draws a 2 dp ring outside it.
 */
@Composable
fun RoundButton(onClick: () -> Unit, description: String, lit: Boolean, litColour: Color, role: Role = Role.Button, state: String? = null, content: @Composable (Color) -> Unit) {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val focused by source.collectIsFocusedAsState()
    val on = animatedFloat(if (lit) 1f else 0f, Dur.STATE)
    val wash = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100)
    Box(
        Modifier.size(48.dp)
            .semantics(mergeDescendants = true) { contentDescription = description; this.role = role; if (state != null) stateDescription = state }
            .clickable(interactionSource = source, indication = null, role = role, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.size(40.dp)
                .drawBehind {
                    val w = 2.dp.toPx()
                    drawCircle(litColour.copy(alpha = on.value))
                    drawCircle(Tok.outline.copy(alpha = 1f - on.value), radius = size.minDimension / 2 - w / 2, style = Stroke(w))
                    if (wash.value > 0f) drawCircle(Tok.text.copy(alpha = 0.14f * wash.value))
                    if (focused) drawCircle(Tok.text, radius = size.minDimension / 2 + 4.dp.toPx(), style = Stroke(2.dp.toPx()))
                },
            contentAlignment = Alignment.Center,
        ) { content(lerp(Tok.text, Tok.onColour, on.value)) }
    }
}
