package com.scottgerstl.lupe.ui.page

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PageFamilies
import com.scottgerstl.lupe.core.PageLock
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.SetParam
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

/** The track's colour: the boards' six (Tok.track). */
fun trackColour(track: Int): Color = Tok.track[((track - 1) % 6 + 6) % 6]

/** The six families the phone shows dials for; anything else on the FM-1's screen (GLO, SAVE, SEQ) has its own place. */
fun isSoundFamily(family: String?) = family in PageFamilies

/**
 * A sound page on the phone (decisions 25, 27 and 28): the header line and the four dials. The FM-1 has the detail and drives the
 * navigation; this is what its four knobs turn now, labelled as it labels them. Tiles (where a knob picks from names) are drawn
 * beside it by whoever places it ([PageTilesContent]). While a step is held the header gives way to the lock banner.
 * [notice] is the Labs "held here" line, shown in the header's place of the track line.
 */
@Composable
fun SoundDials(page: PageState, core: LupeCore, modifier: Modifier = Modifier, notice: String? = null, inline: Boolean = false) {
    val colour = trackColour(page.track)
    // the value each control had when this page opened, for double-tap to put it back (not a factory default: the FM-1 has none per sound)
    val opened = remember(page.track, page.page, page.family) { mutableMapOf<Int, Int>() }
    // a kit's shorter panel: the header sits beside the dials instead of over them
    if (inline) {
        Row(modifier, verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.width(136.dp).semantics(mergeDescendants = true) { heading() }) {
                val at = page.pages.indexOfFirst { it.index == page.page }
                BasicText(page.family + if (at >= 0) " ${at + 1}/${page.pages.size}" else "", style = LupeType.key.copy(color = Tok.text2Raised), maxLines = 1)
                BasicText(page.lock?.text ?: page.title.ifEmpty { page.pages.getOrNull(at)?.title.orEmpty() }, style = LupeType.key, maxLines = 1)
                BasicText(notice ?: page.window?.let { "${it.title} · ${it.index + 1} of ${it.count}" } ?: "${page.track} ${page.trackName}", style = LupeType.small, maxLines = 1)
            }
            Box(Modifier.weight(1f)) {
                if (page.controls.any { it != null }) PageControlsRow(page.controls, colour, if (page.turned >= 0 && page.turnSeq > 0) page.turned else -1, page.turnSeq,
                    opened = { slot, c -> opened.getOrPut(slot) { c.raw } }, onSet = { slot, v -> core.send(SetParam(slot, v)) })
                else BasicText("Set this page on the FM-1.", style = LupeType.small.copy(color = Tok.text2Raised))
            }
        }
        return
    }
    Column(modifier) {
        Box(Modifier.fillMaxWidth().height(32.dp)) {
            LupeCrossfade(page.lock, Modifier.fillMaxSize(), Dur.STATE) { lock -> if (lock == null) PageHeader(page, colour, notice) else LockBanner(lock, colour) }
        }
        Spacer(Modifier.height(4.dp))
        if (page.controls.any { it != null }) PageControlsRow(
            page.controls, colour, if (page.turned >= 0 && page.turnSeq > 0) page.turned else -1, page.turnSeq,
            opened = { slot, c -> opened.getOrPut(slot) { c.raw } },
            onSet = { slot, v -> core.send(SetParam(slot, v)) },
        ) else BasicText("Set this page on the FM-1.", Modifier.padding(horizontal = 4.dp, vertical = 8.dp), style = LupeType.small.copy(color = Tok.text2Raised))
    }
}

/**
 * The only page label (decision 27): the family and the page's place in grey, then the page's name in text weight ("FX 2/7 DELAY"), the
 * FM-1's names; a sheet's own title ("OPERATOR 4") stands as its name, with the window it is in after it (read-only: the FM-1's SELECT
 * moves it). The track line is at the right, or the held notice.
 */
@Composable
private fun PageHeader(page: PageState, colour: Color, notice: String?) {
    val at = page.pages.indexOfFirst { it.index == page.page }
    val place = page.family + if (at >= 0) " ${at + 1}/${page.pages.size}" else ""
    val name = page.title.ifEmpty { page.pages.getOrNull(at)?.title.orEmpty() }
    Row(Modifier.fillMaxSize().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.semantics(mergeDescendants = true) { heading(); contentDescription = "$place $name" }) {
            BasicText(place, style = LupeType.key.copy(color = Tok.text2Raised), maxLines = 1)
            if (name.isNotEmpty()) BasicText(" $name", style = LupeType.key, maxLines = 1)
        }
        page.window?.let { w -> BasicText("  ${w.title} · ${w.index + 1} of ${w.count}", style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1) }
        Spacer(Modifier.weight(1f))
        if (notice != null) BasicText(notice, style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised), maxLines = 1)
        else Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(8.dp).clip(CircleShape).background(colour))
            Spacer(Modifier.width(6.dp))
            BasicText("${page.track} ${page.trackName}", style = LupeType.small, maxLines = 1)
        }
    }
}

/** "Locking to step 6 · held on the FM-1" in the header's place, or "Not lockable", or "Keys: SCALE". */
@Composable
private fun LockBanner(lock: PageLock, colour: Color) {
    Row(
        Modifier.fillMaxSize().padding(vertical = 2.dp).clip(RoundedCornerShape(8.dp)).background(lerp(Tok.page, colour, 0.28f)).padding(horizontal = 12.dp)
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (lock.locking) { Diamond(colour); Spacer(Modifier.width(8.dp)) }
        BasicText(lock.text, style = LupeType.key.copy(color = Tok.text), maxLines = 1)
        Spacer(Modifier.weight(1f))
        lock.note?.let { BasicText(it, style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1) }
    }
}
