package com.scottgerstl.lupe.ui.patterns

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.ClearPatterns
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PatternPicture
import com.scottgerstl.lupe.core.PatternsOpen
import com.scottgerstl.lupe.core.PoolPattern
import com.scottgerstl.lupe.core.padName
import com.scottgerstl.lupe.core.usesText
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.LupeSheet
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * The Patterns sheet (decision 38, board 79): the FM-1's 64 pattern numbers, shared by every saved project. Kept patterns as cards; white and
 * grey because the pool is global, the track colour only on a pattern's uses. Browse, Select (only the unused ones can be picked, then one
 * confirm in place, red only on its key) or Pick (put a kept pattern on an empty pad). While playing the pictures wait for a stop (length bars
 * instead) and so does clearing. The FM-1's answers come back through the notice strip.
 */
@Composable
fun PatternsSheet(core: LupeCore) {
    val host = LocalSheetHost.current
    val visible = host.open == SheetKind.Patterns
    val pool by core.patterns.collectAsStateWithLifecycle()
    val pics by core.patternPictures.collectAsStateWithLifecycle()
    val top by core.top.collectAsStateWithLifecycle()
    // the stored notes are read only while the sheet is open (stopped only; never stops playback)
    var told by remember { mutableStateOf(false) }
    LaunchedEffect(visible) { if (visible != told) { told = visible; core.send(PatternsOpen(visible)) } }
    // what the sheet was opened for stays while it leaves
    var pick by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    if (visible) pick = host.patternsPick
    LupeSheet(visible, "Patterns", { host.close() }, fixed = 380.dp, showTitle = false) {
        PatternsBody(core, pool, pics.pictures, top.playing, pick, onClose = { host.close() })
    }
}

@Composable
private fun PatternsBody(core: LupeCore, pool: com.scottgerstl.lupe.core.PatternsState, pictures: List<PatternPicture>, playing: Boolean, pick: Pair<Int, Int>?, onClose: () -> Unit) {
    var filter by remember { mutableStateOf(PatternFilter.All) }
    var mode by remember { mutableStateOf(PatternMode.Browse) }
    val picked = remember { mutableStateListOf<Int>() }
    var confirming by remember { mutableStateOf(false) }
    var armedAt by remember { mutableStateOf(0L) }
    var why by remember { mutableStateOf<String?>(null) }
    val effective = if (pick != null) PatternMode.Pick else mode
    val shown = pool.filtered(if (pick != null) PatternFilter.All else filter)
    val waits = playing || pool.picturesWaitForStop

    Column(Modifier.fillMaxSize()) {
        // ---- the header: the title and counts, the filters, Select and Clear N unused…, the close key
        Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            BasicText(if (pick != null) "Put a pattern on ${padName(pick.first, pick.second)}" else "Patterns", Modifier.semantics { heading() }, style = LupeType.title.copy(fontSize = 17.sp))
            BasicText(pool.countsText(), style = LupeType.small.copy(fontSize = 13.sp))
            if (pick == null) Filters(filter) { filter = it }
            Spacer(Modifier.weight(1f))
            if (pick == null) {
                if (mode == PatternMode.Browse) {
                    Key({ mode = PatternMode.Select; picked.clear(); confirming = false; why = null }, "Select patterns to clear", width = 80.dp, height = 32.dp, minTarget = 44.dp, enabled = !waits && pool.unused > 0) { fg -> KeyLabel("Select", fg) }
                    if (pool.unused > 0) Key({
                        mode = PatternMode.Select; picked.clear(); picked.addAll(pool.patterns.filter { it.unused }.map { it.number }); confirming = true; armedAt = System.currentTimeMillis(); why = null
                    }, "Clear ${pool.unused} unused patterns", width = 156.dp, height = 32.dp, minTarget = 44.dp, enabled = !waits) { fg -> KeyLabel("Clear ${pool.unused} unused…", fg) }
                } else Key({ mode = PatternMode.Browse; picked.clear(); confirming = false; why = null }, "Done selecting", height = 32.dp, minTarget = 44.dp) { fg -> KeyLabel("Done", fg) }
            }
            Key(onClose, "Close Patterns", width = 40.dp, height = 32.dp, minTarget = 44.dp) { fg -> BasicText("✕", style = LupeType.key.copy(color = fg)) }
        }
        // ---- the cards
        Box(Modifier.weight(1f).fillMaxWidth().padding(top = 8.dp)) {
            if (shown.isEmpty()) BasicText(if (filter == PatternFilter.Unused) "No pattern is unused. Saved projects may hold the rest." else "Nothing here yet.",
                Modifier.align(Alignment.Center), style = LupeType.body)
            else LazyVerticalGrid(GridCells.Fixed(8), Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                items(shown, key = { it.number }) { p ->
                    val on = p.number in picked
                    PatternCard(
                        p, pictureFor(p.number, pictures), pool.picturesLoading && !waits, effective, selected = on,
                        dim = effective == PatternMode.Select && !p.unused,
                    ) {
                        when (effective) {
                            PatternMode.Pick -> { core.send(Intent.PadSet(pick!!.first, pick.second, p.number)); onClose() }
                            PatternMode.Select -> if (p.unused) { if (on) picked.remove(p.number) else picked.add(p.number); confirming = false; why = null } else why = usedWhere(p)
                            PatternMode.Browse -> why = if (p.unused) "Pattern ${num(p.number)} is unused: nothing on the FM-1 uses it." else "Pattern ${num(p.number)} is used by ${usesText(p.here).ifEmpty { "a saved project" }}."
                        }
                    }
                }
            }
        }
        // ---- the foot: a note, the picked count, or the confirm in place
        LupeCrossfade(Triple(confirming && picked.isNotEmpty() && effective == PatternMode.Select, effective, if (waits) 1 else 0), Modifier.fillMaxWidth().padding(top = 8.dp)) { (asking, m, wait) ->
            when {
                asking -> Row(Modifier.fillMaxWidth().background(Tok.well, RoundedCornerShape(10.dp)).padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Column(Modifier.weight(1f)) {
                        BasicText(clearQuestion(picked.size), style = LupeType.key.copy(fontSize = 14.sp))
                        BasicText(clearNumbers(picked.toList()), style = LupeType.small.copy(fontSize = 13.sp), maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                    Key({ confirming = false }, "Keep them", height = 32.dp, minTarget = 44.dp) { fg -> KeyLabel("Keep", fg) }
                    // red only on the confirm key; it ignores taps for 0.4 s (DESIGN.md: destructive actions confirm in place)
                    Box(
                        Modifier.height(44.dp)
                            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Confirm: ${clearQuestion(picked.size)} ${clearNumbers(picked.toList())}" }
                            .pointerInput(armedAt, picked.size) { detectTapGestures { if (System.currentTimeMillis() - armedAt > 400) {
                                core.send(ClearPatterns(picked.toList().sorted(), confirmed = true)); picked.clear(); confirming = false; mode = PatternMode.Browse
                            } } },
                        contentAlignment = Alignment.Center,
                    ) { BasicText("Clear ${picked.size}", Modifier.height(32.dp).clip(RoundedCornerShape(8.dp)).background(Tok.rec).padding(horizontal = 14.dp).wrapContentHeight(Alignment.CenterVertically),
                        style = LupeType.key.copy(fontSize = 14.sp, color = Tok.onColour)) }
                }
                m == PatternMode.Select -> Row(Modifier.fillMaxWidth().background(Tok.well, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    BasicText(why ?: "${picked.size} picked · only unused patterns can be cleared; tap a used one to see where it's used", Modifier.weight(1f), style = LupeType.body.copy(fontSize = 14.sp), maxLines = 2, overflow = TextOverflow.Ellipsis)
                    if (picked.isNotEmpty()) Key({ confirming = true; armedAt = System.currentTimeMillis(); why = null }, "Clear ${picked.size} patterns", height = 32.dp, minTarget = 44.dp, enabled = !waits) { fg -> KeyLabel("Clear ${picked.size}…", fg) }
                }
                m == PatternMode.Pick -> Note("The pad then plays the same pattern as its other users: an edit to one is an edit to all.")
                wait == 1 -> Note(why ?: "Pictures and clearing wait for a stop: stop the song to load the pictures and to clear patterns.")
                why != null -> Note(why!!)
                else -> Spacer(Modifier.height(1.dp))
            }
        }
    }
}

/** A quiet note under the cards. */
@Composable
private fun Note(text: String) =
    BasicText(text, Modifier.fillMaxWidth().background(Tok.well, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 8.dp), style = LupeType.body.copy(fontSize = 14.sp), maxLines = 2, overflow = TextOverflow.Ellipsis)

/** The three filters as words in a well, the chosen one raised (blending over 150 ms). */
@Composable
private fun Filters(selected: PatternFilter, onPick: (PatternFilter) -> Unit) {
    Row(Modifier.background(Tok.well, RoundedCornerShape(8.dp)).padding(2.dp)) {
        PatternFilter.entries.forEach { f ->
            val on = animatedFloat(if (f == selected) 1f else 0f, Dur.STATE)
            Box(
                Modifier.height(32.dp).clip(RoundedCornerShape(6.dp)).background(lerp(Color.Transparent, Tok.lifted, on.value))
                    .semantics(mergeDescendants = true) { role = Role.RadioButton; this.selected = f == selected; contentDescription = "Show ${f.label.lowercase()} patterns" }
                    .pointerInput(f) { detectTapGestures { onPick(f) } }
                    .padding(horizontal = 10.dp),
                contentAlignment = Alignment.Center,
            ) { BasicText(f.label, style = LupeType.key.copy(fontSize = 13.sp, color = lerp(Tok.text2, Tok.text, on.value))) }
        }
    }
}

/**
 * One kept pattern: its number, its length, a picture of its notes in its first user's track colour (length bars while the pictures wait, and
 * when it has none), and where this project uses it ("T2 A · T4 C", the track in its own colour; a dot when saved projects use it too). An
 * unused one is dashed and says so. In Select mode a used one dims and an unused one has a check.
 */
@Composable
private fun PatternCard(p: PoolPattern, pic: PatternPicture?, loading: Boolean, mode: PatternMode, selected: Boolean, dim: Boolean, onTap: () -> Unit) {
    val col = firstUserTrack(p)?.let { Tok.track[(it - 1).coerceAtLeast(0) % Tok.track.size] } ?: Tok.text3
    val desc = "Pattern ${num(p.number)}, ${p.len} steps, " + (if (p.unused) "unused" else "used by ${usesText(p.here).ifEmpty { "a saved project" }}") + (if (p.saved && p.here.isNotEmpty()) ", also in saved projects" else "")
    Box(
        Modifier.height(88.dp).alpha(if (dim) 0.38f else 1f)
            .drawBehind {
                val r = CornerRadius(8.dp.toPx())
                if (p.unused) drawRoundRect(Tok.outline, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(7.25.dp.toPx()),
                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.dp.toPx()))))
                else drawRoundRect(Tok.control, cornerRadius = r)
                if (selected) drawRoundRect(Tok.text, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
            }
            .semantics(mergeDescendants = true) {
                role = if (mode == PatternMode.Select && p.unused) Role.Checkbox else Role.Button
                contentDescription = desc
                if (mode == PatternMode.Select && p.unused) stateDescription = if (selected) "Picked" else "Not picked"
            }
            .pointerInput(p.number, mode) { detectTapGestures { onTap() } }
            .padding(horizontal = 6.dp, vertical = 5.dp),
    ) {
        Column(Modifier.fillMaxSize()) {
            BasicText(num(p.number), style = LupeType.number.copy(fontSize = 17.sp, lineHeight = 18.sp))
            Canvas(Modifier.weight(1f).fillMaxWidth().padding(vertical = 3.dp)) { drawThumb(p, pic, loading, col) }
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (p.saved && !p.unused) Box(Modifier.padding(end = 3.dp).size(6.dp).background(Tok.text2, androidx.compose.foundation.shape.CircleShape))
                if (p.unused) BasicText("unused", style = LupeType.small.copy(fontSize = 10.sp, lineHeight = 12.sp), maxLines = 1)
                else Uses(p)
            }
        }
        BasicText("${p.len}", Modifier.align(Alignment.TopEnd), style = LupeType.small.copy(fontSize = 10.sp, lineHeight = 12.sp))
        if (mode == PatternMode.Select && p.unused) Box(
            Modifier.align(Alignment.BottomEnd).size(16.dp)
                .background(if (selected) Tok.text else Color.Transparent, androidx.compose.foundation.shape.CircleShape)
                .drawBehind { if (!selected) drawCircle(Tok.text2, size.minDimension / 2 - 0.75.dp.toPx(), style = Stroke(1.5.dp.toPx())) },
            contentAlignment = Alignment.Center,
        ) { if (selected) BasicText("✓", style = LupeType.key.copy(fontSize = 11.sp, color = Tok.onColour)) }
    }
}

/** "T2 A · T4 C": each track's own colour on its "T2", the pad letter in grey. */
@Composable
private fun Uses(p: PoolPattern) {
    val text = androidx.compose.ui.text.buildAnnotatedString {
        p.here.forEachIndexed { i, u ->
            if (i > 0) append(" · ")
            pushStyle(androidx.compose.ui.text.SpanStyle(color = Tok.track[(u.track - 1).coerceAtLeast(0) % Tok.track.size])); append("T${u.track}"); pop()
            append(" ${'A' + u.entry}")
        }
        if (p.here.isEmpty()) append("saved project")
    }
    BasicText(text, style = LupeType.small.copy(fontSize = 10.sp, lineHeight = 12.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
}

/** The thumbnail: the pattern's notes (or drum hits) across its steps, one small mark a step; else a quiet bar as long as the pattern. */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawThumb(p: PoolPattern, pic: PatternPicture?, loading: Boolean, colour: Color) {
    val marks = pic?.let { stepMarks(it) }
    if (pic != null && marks != null) {
        val len = pic.len.coerceAtLeast(1); val step = size.width / len; val h = 3.dp.toPx().coerceAtMost(size.height / 4)
        marks.forEach { (i, y) -> drawRoundRect(colour, Offset(i * step, (size.height - h) * y), Size((step * 0.8f).coerceAtLeast(1.dp.toPx()), h), CornerRadius(0.6.dp.toPx())) }
    } else {
        // length bars: one bar along the foot, as long as the pattern is of a four-bar 64, with a tick at each 16 steps; quieter while it is being read
        val a = if (loading) 0.5f else 1f
        val w = size.width * (p.len.coerceIn(1, 64) / 64f); val bh = 5.dp.toPx()
        drawRoundRect(Color(0xFF3A3A42).copy(alpha = a), Offset(0f, size.height - bh), Size(w, bh), CornerRadius(1.dp.toPx()))
        for (k in 1 until (p.len / 16).coerceAtMost(4)) drawLine(Tok.page, Offset(size.width * k * 16 / 64f, size.height - bh), Offset(size.width * k * 16 / 64f, size.height), 1.dp.toPx(), StrokeCap.Butt)
    }
}
