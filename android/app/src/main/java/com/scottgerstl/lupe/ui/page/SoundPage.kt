package com.scottgerstl.lupe.ui.page

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.Divider
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PageFamilies
import com.scottgerstl.lupe.core.PageLock
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.PickPage
import com.scottgerstl.lupe.core.PickRoute
import com.scottgerstl.lupe.core.PickTile
import com.scottgerstl.lupe.core.SetParam
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/** The track's colour: the boards' six (Tok.track). */
fun trackColour(track: Int): Color = Tok.track[((track - 1) % 6 + 6) % 6]

/**
 * The bottom half while the FM-1 is on a sound page (design/phone-sound-pages.md; boards 55, 59–63). Top to bottom:
 * the family keys, the page row (or the lock banner), the graph panel, the four controls. The controls are fixed
 * in size and sit at the bottom, so at bottom full the graph takes all the extra height and the controls stay
 * where the thumb found them at split.
 */
@Composable
fun SoundPage(page: PageState, core: LupeCore, modifier: Modifier = Modifier) {
    val colour = trackColour(page.track)
    // the value each control had when this page opened, for double-tap to put it back (not a factory default: the FM-1 has none per sound)
    val opened = remember(page.track, page.page, page.family) { mutableMapOf<Int, Int>() }
    // the FM-1's knob lights its control; a new page starts with nothing lit
    val hot = remember { mutableStateOf(-1) }

    Column(modifier.fillMaxSize()) {
        FamilyRow(page.family, colour) { core.send(PickPage(it)) }
        Box(Modifier.fillMaxWidth().height(44.dp)) {
            LupeCrossfade(page.lock, Modifier.fillMaxSize(), Dur.STATE) { lock ->
                if (lock == null) PageRow(page, colour) { core.send(PickPage(page.family, it)) } else LockBanner(lock, colour)
            }
        }
        // the graph panel takes what is left
        Box(
            Modifier.weight(1f).fillMaxWidth().padding(vertical = 4.dp).clip(RoundedCornerShape(12.dp)).background(Tok.panel),
        ) {
            val g = page.graph
            Box(Modifier.fillMaxSize().padding(start = 12.dp, end = 12.dp, top = 30.dp, bottom = 10.dp)) {
                LupeCrossfade(page.page to page.family, Modifier.fillMaxSize(), Dur.STATE) { _ ->
                    GraphContent(
                        g, colour, if (litNow(page)) page.turned else -1,
                        onSet = { slot, v -> core.send(SetParam(slot, v)) },
                        onPickRoute = { core.send(PickRoute(it)) }, onPickTile = { core.send(PickTile(it)) },
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
            TrackLine(page, colour, Modifier.align(Alignment.TopStart).padding(start = 12.dp, top = 8.dp))
            if (g.side != null && g.kind in setOf(com.scottgerstl.lupe.core.GraphKind.Scale, com.scottgerstl.lupe.core.GraphKind.Arp)) {
                BasicText(g.side!!, Modifier.align(Alignment.TopEnd).padding(end = 12.dp, top = 8.dp), style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1)
            }
            if (g.kind == com.scottgerstl.lupe.core.GraphKind.Drive && g.caption != null) DriveName(g.caption!!, g.side, colour)
        }
        // the dense pages have no controls (four empty wells): their picture takes the height instead
        if (page.controls.any { it != null }) PageControlsRow(
            page.controls, colour, page.turned, page.turnSeq,
            opened = { slot, c -> opened.getOrPut(slot) { c.raw } },
            onSet = { slot, v -> core.send(SetParam(slot, v)) },
        )
    }
}

// "lit" = the FM-1 turned it just now. The page area carries only the counter, so the graph is told which knob until the next page.
private fun litNow(page: PageState) = page.turned >= 0 && page.turnSeq > 0

@Composable
private fun DriveName(name: String, side: String?, colour: Color) {
    // DRIVE's board 59: the type's name large to the right of the curve, its numbers under it
    Column(Modifier.fillMaxSize().padding(end = 24.dp), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.Center) {
        BasicText(name, style = LupeType.number.copy(color = Tok.text))
        if (side != null) BasicText(side, style = LupeType.small.copy(color = Tok.text2Raised))
    }
}

@Composable
private fun TrackLine(page: PageState, colour: Color, modifier: Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(colour))
        Spacer(Modifier.width(6.dp))
        BasicText("${page.track} ${page.trackName}", style = LupeType.small, maxLines = 1)
    }
}

@Composable
private fun FamilyRow(family: String, colour: Color, onPick: (String) -> Unit) {
    val edge = lerp(colour, Color.Black, 0.45f)
    BoxWithConstraints(Modifier.fillMaxWidth().height(48.dp)) {
        val gap = 4.dp
        val w = (maxWidth - gap * (PageFamilies.size - 1)) / PageFamilies.size
        Row(Modifier.selectableGroup(), horizontalArrangement = Arrangement.spacedBy(gap), verticalAlignment = Alignment.CenterVertically) {
            PageFamilies.forEach { f ->
                Key(
                    onClick = { onPick(f) }, description = "$f page family", width = w, height = 36.dp, on = f == family,
                    role = Role.Tab, state = if (f == family) "Selected" else null, litTop = colour, litEdge = edge,
                ) { fg -> KeyLabel(f, fg) }
            }
        }
    }
}

/** The family's pages in the FM-1's order. It scrolls when they don't fit (FX, and EDIT on a drum track), keeps the current page in view, and fades at a cut edge. */
@Composable
private fun PageRow(page: PageState, colour: Color, onPick: (Int) -> Unit) {
    val reduce = LocalReduceMotion.current
    val state = rememberLazyListState()
    val density = LocalDensity.current
    val at = page.pages.indexOfFirst { it.index == page.page }
    LaunchedEffect(page.page, page.pages.size) {
        if (at < 0) return@LaunchedEffect
        val vis = state.layoutInfo.visibleItemsInfo.firstOrNull { it.index == at }
        val vp = state.layoutInfo
        val fully = vis != null && vis.offset >= 0 && vis.offset + vis.size <= vp.viewportEndOffset - vp.afterContentPadding
        if (!fully) {
            // park it with the one before peeking in, so you can see where you came from
            val off = -with(density) { 56.dp.roundToPx() }
            if (reduce) state.scrollToItem(at, off.coerceAtMost(0)) else state.animateScrollToItem(at, off.coerceAtMost(0))
        }
    }
    Box(Modifier.fillMaxSize()) {
        LazyRow(state = state, modifier = Modifier.fillMaxSize().selectableGroup(), verticalAlignment = Alignment.CenterVertically) {
            itemsIndexed(page.pages) { _, r ->
                val on = r.index == page.page
                val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                Box(
                    Modifier.fillMaxHeight().padding(horizontal = 4.dp)
                        .semantics(mergeDescendants = true) { role = Role.Tab; selected = on; contentDescription = "${r.title} page" }
                        .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onPick(r.index) }
                        .padding(horizontal = 8.dp)
                        .drawBehind {
                            // the current page's underline grows from the middle (a drawn bar; it needs no width from a scrolling row)
                            val w = size.width * lit.value
                            drawRect(Tok.text, Offset((size.width - w) / 2, size.height - 8.dp.toPx()), Size(w, 2.dp.toPx()))
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    BasicText(r.title, style = LupeType.key.copy(color = lerp(Tok.text2, Tok.text, lit.value)), maxLines = 1)
                }
            }
        }
        // the fade says there is more
        if (state.canScrollForward) Box(Modifier.align(Alignment.CenterEnd).width(28.dp).fillMaxHeight().background(Brush.horizontalGradient(listOf(Color.Transparent, Tok.page))))
        if (state.canScrollBackward) Box(Modifier.align(Alignment.CenterStart).width(28.dp).fillMaxHeight().background(Brush.horizontalGradient(listOf(Tok.page, Color.Transparent))))
    }
}

/** "Locking to step 6 · held on the FM-1" in the page row's place (board 61), or "Not lockable", or "Keys: SCALE". */
@Composable
private fun LockBanner(lock: PageLock, colour: Color) {
    Box(Modifier.fillMaxSize().padding(vertical = 4.dp)) {
        Row(
            Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)).background(lerp(Tok.page, colour, 0.28f)).padding(horizontal = 12.dp)
                .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (lock.locking) { Diamond(colour); Spacer(Modifier.width(8.dp)) }
            BasicText(lock.text, style = LupeType.key.copy(color = Tok.text), maxLines = 1)
            Spacer(Modifier.weight(1f))
            lock.note?.let { BasicText(it, style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1) }
        }
    }
}

/**
 * Following the FM-1 never hides what it opened: when it opens a sound page while the divider is at top only, the
 * divider glides to split; when the FM-1 goes back to SEQ it goes back, unless the person has moved it since (map,
 * open question 5). The core could do this itself; it is here so the fake behaves the same.
 */
@Composable
fun FollowFm1Divider(shell: ShellState, core: LupeCore) {
    var prev by remember { mutableStateOf(shell.bottom.kind) }
    var auto by remember { mutableStateOf(false) }
    LaunchedEffect(shell.bottom.kind) {
        val k = shell.bottom.kind
        if (k == prev) return@LaunchedEffect
        if (k == BottomKind.Page && shell.divider == Divider.Top) { auto = true; core.send(Intent.SetDivider(Divider.Split)) }
        else if (k == BottomKind.Editor) { if (auto && shell.divider == Divider.Split) core.send(Intent.SetDivider(Divider.Top)); auto = false }
        prev = k
    }
    LaunchedEffect(shell.divider) { if (shell.divider != Divider.Split) auto = false }
}

/** The bottom half's slot for a Page: the sound page for the six families; anything else (P5's Sounds, Patterns, Projects) keeps the placeholder. */
@Composable
fun SoundOrPlaceholder(bottom: com.scottgerstl.lupe.core.BottomPage, core: LupeCore, modifier: Modifier = Modifier) {
    val page by core.page.collectAsStateWithLifecycle()
    if (bottom.family in PageFamilies) SoundPage(page, core, modifier)
    else com.scottgerstl.lupe.ui.shell.BottomPlaceholder(bottom, modifier)
}
