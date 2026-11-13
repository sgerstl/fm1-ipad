package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * Pads · Timeline · Mix: a 36 dp well with 3 dp inside it, the chosen tab a raised key. Each tab's whole 36 dp
 * height is its touch target (30 dp drawn). The chosen look blends in over 150 ms; it doesn't jump.
 */
@Composable
fun Tabs(current: Tab, onPick: (Tab) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().height(36.dp).background(Tok.well, RoundedCornerShape(10.dp)).selectableGroup(),
    ) {
        Tab.entries.forEach { tab ->
            val lit = animatedFloat(if (tab == current) 1f else 0f, Dur.STATE)
            Box(
                Modifier
                    .weight(1f).fillMaxHeight()
                    .semantics(mergeDescendants = true) { role = Role.Tab; selected = tab == current; contentDescription = tab.name }
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onPick(tab) }
                    .padding(3.dp)
                    .drawBehind {
                        val r = CornerRadius(8.dp.toPx())
                        drawRoundRect(Tok.chicletEdge.copy(alpha = lit.value), Offset(0f, 2.dp.toPx()), size.copy(height = size.height - 2.dp.toPx()), r)
                        drawRoundRect(Tok.control.copy(alpha = lit.value), Offset.Zero, size.copy(height = size.height - 2.dp.toPx()), r)
                    },
                contentAlignment = Alignment.Center,
            ) {
                BasicText(tab.name, style = LupeType.key.copy(color = lerp(Tok.text2, Tok.text, lit.value)))
            }
        }
    }
}
