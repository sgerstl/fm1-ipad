package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/** Which refusal shows: the core's latest, unless that one has been dismissed. Kept apart from the drawing so it can be tested. */
class RefusalModel {
    /** The [com.scottgerstl.lupe.core.CoreNotice.seq] that was dismissed, or that was already there when the screen opened. */
    var dismissed by mutableIntStateOf(-1)
    fun shows(seq: Int, text: String): Boolean = seq > 0 && text.isNotEmpty() && seq != dismissed
}

/**
 * What the FM-1 refused, in words: what happened and what to do (Scott, 2026-11-14). It rises at the foot of the page the action was taken
 * on, over the scenes row where Pads' own notices show, and over a sheet when one is up; it stays until ✕ (nothing here vanishes by
 * itself, and it carries no action: the words say what to do). It moves in and out (a short rise and a blend; with Reduce Motion the blend
 * only); a new refusal replaces the words in place. TalkBack is told as it arrives.
 */
@Composable
fun RefusalStrip(core: LupeCore, modifier: Modifier = Modifier) {
    val notice by core.notice.collectAsStateWithLifecycle()
    val reduce = LocalReduceMotion.current
    // a refusal from before this screen opened is not news
    val model = remember(core) { RefusalModel().also { it.dismissed = core.notice.value.seq } }
    val showing = model.shows(notice.seq, notice.text)
    // the words stay while the strip leaves
    var words by remember { mutableStateOf("") }
    if (showing) words = notice.text
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
        BasicText(words, Modifier.weight(1f).padding(vertical = 6.dp), style = LupeType.small.copy(color = Tok.text), maxLines = 3)
        Key({ model.dismissed = notice.seq }, "Dismiss", width = 44.dp, height = 44.dp, minTarget = 44.dp) { fg -> BasicText("✕", style = LupeType.key.copy(color = fg)) }
    }
}
