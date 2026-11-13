package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * Pads · Timeline · Mix (DESIGN.md "The header is chrome, not content"): a left-aligned row of words, Barlow 17 semibold,
 * 24 dp apart. The tab showing is in text with a 3 dp white underline the width of its word that glides to the new tab
 * (200 ms, ease-out; with Reduce Motion the two underlines cross-fade instead). The others are in text2. A 1 dp hairline
 * (control) ends the header. The row is 36 dp tall and each word's whole height is its touch target; 24 dp of space
 * follows each word inside its target too.
 */
@Composable
fun Tabs(current: Tab, onPick: (Tab) -> Unit, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    // each word's left edge (in the row) and width, measured, so the underline can sit under it and travel
    var xs by remember { mutableStateOf(FloatArray(Tab.entries.size)) }
    var ws by remember { mutableStateOf(FloatArray(Tab.entries.size)) }
    var rowX by remember { mutableStateOf(0f) }
    val i = current.ordinal
    val ux by animatedFloat(xs[i], Dur.FINGER)
    val uw by animatedFloat(ws[i], Dur.FINGER)
    val lits = Tab.entries.map { animatedFloat(if (it == current) 1f else 0f, Dur.STATE) }
    Row(
        modifier.fillMaxWidth().height(36.dp).selectableGroup()
            .onGloballyPositioned { rowX = it.positionInWindow().x }
            .drawBehind {
                val h = 3.dp.toPx()
                drawRect(Tok.control, Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
                if (ws[i] <= 0f) return@drawBehind
                if (reduce) {
                    // nothing travels: each word's underline fades in or out where it stands
                    Tab.entries.forEach { t -> drawRect(Tok.text.copy(alpha = lits[t.ordinal].value), Offset(xs[t.ordinal], size.height - h), Size(ws[t.ordinal], h)) }
                } else drawRect(Tok.text, Offset(ux, size.height - h), Size(uw, h))
            },
    ) {
        Tab.entries.forEach { tab ->
            Box(
                Modifier
                    .height(36.dp)
                    .semantics(mergeDescendants = true) { role = Role.Tab; selected = tab == current; contentDescription = tab.name }
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onPick(tab) }
                    .padding(end = if (tab == Tab.entries.last()) 0.dp else 24.dp),
                contentAlignment = Alignment.Center,
            ) {
                BasicText(
                    tab.name,
                    Modifier.onGloballyPositioned { c ->
                        val x = c.positionInWindow().x - rowX; val w = c.size.width.toFloat()
                        if (xs[tab.ordinal] != x || ws[tab.ordinal] != w) {
                            xs = xs.copyOf().also { it[tab.ordinal] = x }; ws = ws.copyOf().also { it[tab.ordinal] = w }
                        }
                    },
                    style = LupeType.key.copy(fontSize = 17.sp, lineHeight = 20.sp, color = lerp(Tok.text2, Tok.text, lits[tab.ordinal].value)), maxLines = 1,
                )
            }
        }
    }
}
