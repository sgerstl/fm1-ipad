package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.ClearedPad
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.UndoClear
import com.scottgerstl.lupe.core.clearedWords
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.delay

/** How long the strip stays once a pad has been cleared. The core keeps the pattern ten seconds, and the pad's menu offers "Undo clear" for all of them. */
const val UNDO_STRIP_MS = 6000L

/**
 * A pad was cleared without asking (batch item 13): "Cleared T2 pad F · pattern 07" with an Undo key, for a few seconds. It is not the only way
 * back: the cleared pad's menu has "Undo clear" until the core's ten seconds end. It rises as the notice strip does (a short rise and a blend;
 * with Reduce Motion the blend only) and is dismissed by ✕ or its time.
 */
@Composable
fun UndoStrip(core: LupeCore, modifier: Modifier = Modifier) {
    val pads by core.pads.collectAsStateWithLifecycle()
    val reduce = LocalReduceMotion.current
    val last: ClearedPad? = pads.clearUndo.lastOrNull()
    // the clear it was dismissed for, or timed out on: a newer clear shows again
    var gone by remember { mutableStateOf<ClearedPad?>(core.pads.value.clearUndo.lastOrNull()) }
    LaunchedEffect(last) { if (last != null && last != gone) { delay(UNDO_STRIP_MS); gone = last } }
    val showing = last != null && last != gone
    var words by remember { mutableStateOf("") }
    if (last != null) words = clearedWords(last)
    val t = animatedFloat(if (showing) 1f else 0f, if (showing) Dur.EXIT else Dur.STATE, if (showing) EaseOut else EaseIn)
    if (t.value <= 0.001f) return
    Row(
        modifier.fillMaxWidth().defaultMinSize(minHeight = 44.dp)
            .graphicsLayer { alpha = t.value; if (!reduce) translationY = (1f - t.value) * 24.dp.toPx() }
            .background(Tok.held, RoundedCornerShape(8.dp))
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite }
            .padding(start = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(words, Modifier.weight(1f).padding(vertical = 6.dp), style = LupeType.small.copy(color = Tok.text), maxLines = 2)
        Key({ last?.let { core.send(UndoClear(it.track, it.entry)); gone = it } }, "Undo clear", width = 72.dp, height = 32.dp, minTarget = 44.dp, on = true) { fg -> KeyLabel("Undo", fg) }
        Key({ gone = last }, "Dismiss", width = 44.dp, height = 44.dp, minTarget = 44.dp) { fg -> BasicText("✕", style = LupeType.key.copy(color = fg)) }
    }
}
