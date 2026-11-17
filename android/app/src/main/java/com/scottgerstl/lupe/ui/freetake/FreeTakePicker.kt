package com.scottgerstl.lupe.ui.freetake

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.FreeTakeState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.TakeBarsPick
import com.scottgerstl.lupe.core.TakeDismissLanded
import com.scottgerstl.lupe.core.TakeDismissOffer
import com.scottgerstl.lupe.core.TakeFirstBeat
import com.scottgerstl.lupe.core.TakeGuessPick
import com.scottgerstl.lupe.core.TakeKeep
import com.scottgerstl.lupe.core.TakeListen
import com.scottgerstl.lupe.core.TakePicker
import com.scottgerstl.lupe.core.TakePutBack
import com.scottgerstl.lupe.core.TakeSetTempo
import com.scottgerstl.lupe.core.TakeStart
import com.scottgerstl.lupe.core.TakeUndo
import com.scottgerstl.lupe.ui.page.trackColour
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

// FREE TAKE on the phone (board 71): the FM-1's picker in the editor's place in the bottom half, the offer and the landing
// as a strip on the editor. Ported from ios/FM1/FreeTakePicker.swift (form A, Scott 2026-11-11). The four choices are
// Skiff's four knobs in words (taps, no drag); Listen is its PLAY, Put back its OCT-, Keep it its OCT+ (asked once more
// in place when it replaces a pattern). Every choice is a write the core refuses while read-only; the picker follows the
// FM-1's own answer, so a refused choice simply doesn't move.

@Composable
fun FreeTakePicker(state: FreeTakeState, core: LupeCore, modifier: Modifier = Modifier) {
    val p = state.picker ?: return
    val colour = trackColour(p.track)
    var confirming by remember(p.track) { mutableStateOf(false) }
    BoxWithConstraints(modifier.fillMaxSize()) {
        val tall = maxHeight > 560.dp
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Header(p, colour)
            Notes(p, colour, Modifier.fillMaxWidth().height(if (tall) 150.dp else 84.dp))
            // the choices scroll in the room between the notes and the keys at split; at bottom full they all show
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Choice("Tempo", "Skiff's guesses, the likeliest first") {
                    Segments("Tempo", p.guesses.mapIndexed { i, g -> g.bpm.toString() to (g.caption) }, p.guess, bpm = true) { core.send(TakeGuessPick(it)) }
                }
                Choice("Bars", null) { Segments("Bars", p.bars.map { it.toString() to "" }, p.barsIndex) { core.send(TakeBarsPick(it)) } }
                Choice("Where the 1 is", "which note is the first beat") { FirstBeat(p) { core.send(TakeFirstBeat(it)) } }
                Choice("Song tempo", if (p.externalClock) "on an external clock: the clock's" else "the song's ${p.tempoBefore} BPM before") {
                    Segments("Song tempo", listOf("Set to ${p.bpm}" to "", "Keep ${p.tempoBefore}" to ""), if (p.setsTempo) 0 else 1, enabled = listOf(!p.externalClock, true)) { core.send(TakeSetTempo(it == 0)) }
                }
            }
            Actions(p, confirming, { confirming = it }, core)
        }
    }
}

@Composable
private fun Header(p: TakePicker, colour: Color) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(8.dp)).background(colour), contentAlignment = Alignment.Center) {
            BasicText("${p.track}", style = LupeType.number.copy(fontSize = 18.sp, color = Tok.onColour))
        }
        Column(Modifier.semantics(mergeDescendants = true) { heading() }) {
            BasicText("Keep that take on T${p.track} ${p.trackName}", style = LupeType.title.copy(fontSize = 16.sp), maxLines = 1)
            BasicText(p.replaces, style = LupeType.small, maxLines = 2)
        }
    }
}

/** The take's notes as the FM-1 placed them: the track's own steps over the picker's bars, bar lines strong, each note a block in the track's colour. */
@Composable
private fun Notes(p: TakePicker, colour: Color, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val desc = "The take's notes: " + if (p.notes.isEmpty()) "none yet" else "${p.notes.size} notes over ${p.length / 16} bar${if (p.length / 16 == 1) "" else "s"}"
    Canvas(modifier.clip(RoundedCornerShape(12.dp)).background(Tok.well).semantics { contentDescription = desc }) {
        val len = p.length.coerceAtLeast(1)
        val w = size.width - 24.dp.toPx(); val h = size.height - 28.dp.toPx(); val sw = w / len
        for (k in 0..len) {
            val x = 12.dp.toPx() + k * sw
            val bar = k % 16 == 0
            drawRect(if (bar) Tok.text3 else if (k % 4 == 0) Tok.lifted else Tok.stepEmpty, Offset(x, 6.dp.toPx()), Size((if (bar) 2 else 1).dp.toPx(), h))
        }
        val lo = (p.notes.minOfOrNull { it.pitch } ?: 60) - 2; val hi = (p.notes.maxOfOrNull { it.pitch } ?: 72) + 2
        val rows = (hi - lo).coerceAtLeast(1)
        for (n in p.notes) {
            val bh = (h / rows).coerceIn(6.dp.toPx(), 12.dp.toPx())
            drawRoundRect(colour, Offset(12.dp.toPx() + n.step * sw + 1.dp.toPx(), 6.dp.toPx() + (hi - n.pitch).toFloat() / rows * (h - 10.dp.toPx())), Size(maxOf(4.dp.toPx(), n.len * sw - 2.dp.toPx()), bh), CornerRadius(3.dp.toPx()))
        }
        for (b in 0 until maxOf(1, (len + 15) / 16)) {
            val r = tm.measure("${b + 1}", LupeType.label.copy(color = Tok.text2Raised))
            drawText(r, topLeft = Offset(14.dp.toPx() + b * 16 * sw, size.height - r.size.height - 4.dp.toPx()))
        }
    }
}

@Composable
private fun Choice(label: String, help: String?, body: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.clearAndSetSemantics { }) {
            BasicText(label, style = LupeType.label.copy(color = Tok.text, fontSize = 13.sp))
            if (help != null) BasicText(help, style = LupeType.small.copy(fontSize = 13.sp))
        }
        body()
    }
}

/** One of several, with a caption under each where there is one (the tempo guesses: half, guess, double). */
@Composable
private fun Segments(label: String, options: List<Pair<String, String>>, selected: Int, bpm: Boolean = false, enabled: List<Boolean> = emptyList(), onSelect: (Int) -> Unit) {
    Row(
        Modifier.clip(RoundedCornerShape(12.dp)).background(Tok.well).padding(4.dp).semantics { contentDescription = label },
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEachIndexed { i, (text, caption) ->
            val on = i == selected
            val ok = enabled.getOrElse(i) { true }
            Column(
                Modifier.widthIn(min = 64.dp).heightIn(min = 48.dp).clip(RoundedCornerShape(8.dp)).background(if (on) Tok.lifted else Color.Transparent)
                    .semantics(mergeDescendants = true) {
                        role = Role.RadioButton; this.selected = on
                        contentDescription = (if (bpm) "$text BPM" else text) + (if (caption.isNotEmpty()) ", $caption" else "")
                    }
                    .clickable(enabled = ok, interactionSource = remember { MutableInteractionSource() }, indication = null) { onSelect(i) }
                    .padding(horizontal = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                val ink = if (!ok) Tok.text3 else if (on) Tok.text else Tok.text2Raised
                BasicText(text, style = LupeType.number.copy(fontSize = 15.sp, color = ink), maxLines = 1)
                if (caption.isNotEmpty()) BasicText(caption, style = LupeType.small.copy(fontSize = 11.sp, color = ink), maxLines = 1)
            }
        }
    }
}

/** ‹ note n of m ›: taps, no drag (WCAG 2.5.7); TalkBack adjusts it up and down. */
@Composable
private fun FirstBeat(p: TakePicker, set: (Int) -> Unit) {
    val n = p.firstBeat; val m = p.firstBeats.coerceAtLeast(1)
    Row(
        Modifier.semantics(mergeDescendants = true) {
            contentDescription = "Where the 1 is"; stateDescription = "note ${n + 1} of $m"
            progressBarRangeInfo = ProgressBarRangeInfo(n.toFloat(), 0f..(m - 1).toFloat(), maxOf(0, m - 2))
            customActions = listOf(
                CustomAccessibilityAction("Later note") { if (n < m - 1) { set(n + 1); true } else false },
                CustomAccessibilityAction("Earlier note") { if (n > 0) { set(n - 1); true } else false },
            )
        },
        horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        TakeKey("‹", Modifier.width56(), enabled = n > 0, label = "Earlier note") { set(n - 1) }
        BasicText("note ${n + 1} of $m", Modifier.widthIn(min = 112.dp), style = LupeType.number.copy(fontSize = 15.sp, color = Tok.text))
        TakeKey("›", Modifier.width56(), enabled = n < m - 1, label = "Later note") { set(n + 1) }
    }
}

private fun Modifier.width56() = this.then(Modifier.widthIn(min = 56.dp))

@Composable
private fun Actions(p: TakePicker, confirming: Boolean, setConfirming: (Boolean) -> Unit, core: LupeCore) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        if (confirming && p.confirm != null) {
            TakeKey("Cancel") { setConfirming(false) }
            TakeKey(p.confirm, Modifier.weight(1f), outline = true, hint = "The pattern it replaces goes; Undo on the landing strip brings it back") { setConfirming(false); core.send(TakeKeep) }
        } else {
            TakeKey(if (p.playing) "■ Stop" else "▶ Listen") { core.send(TakeListen) }
            TakeKey("↶ Put back") { setConfirming(false); core.send(TakePutBack) }
            Box(Modifier.weight(1f))
            TakeKey("Keep it", primary = true) { if (p.confirm == null) core.send(TakeKeep) else setConfirming(true) }
        }
    }
}

@Composable
fun TakeKey(text: String, modifier: Modifier = Modifier, primary: Boolean = false, outline: Boolean = false, enabled: Boolean = true, label: String? = null, hint: String? = null, onClick: () -> Unit) {
    Box(
        modifier.heightIn(min = 48.dp).clip(RoundedCornerShape(8.dp)).background(if (primary) Tok.text else Tok.control)
            .then(if (outline) Modifier.border(3.dp, Tok.rec, RoundedCornerShape(8.dp)) else Modifier)
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = label ?: text; if (hint != null) stateDescription = hint }
            .clickable(enabled = enabled, interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick)
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) { BasicText(text, style = LupeType.label.copy(fontSize = 15.sp, color = if (primary) Tok.onColour else if (enabled) Tok.text else Tok.text3), maxLines = 1) }
}

// ---------------------------------------------------------------- the strip on the editor: the offer, the landing

/** A phrase heard on the FM-1, offered; after Keep it, what it became, with the FM-1's own undo. Sits at the top of the editor. */
@Composable
fun TakeStrips(state: FreeTakeState, core: LupeCore, modifier: Modifier = Modifier, showOffer: Boolean = true) {
    // the offer shows here only when Settings › Offer played phrases is Pop-up (Scott, 2026-11-18); Chip puts it by Record, Off nowhere
    val offer = state.offer?.takeIf { showOffer }; val landed = state.landed
    if (offer == null && landed == null) return
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (offer != null) Tok.outline else Tok.lifted).padding(start = 10.dp, end = 2.dp, top = 4.dp, bottom = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        val track = offer?.track ?: landed!!.track
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(8.dp)).background(trackColour(track)), contentAlignment = Alignment.Center) {
            BasicText("$track", style = LupeType.number.copy(fontSize = 18.sp, color = Tok.onColour))
        }
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) { }) {
            if (offer != null) {
                BasicText("You played ${offer.notes} note${if (offer.notes == 1) "" else "s"} on T${offer.track} ${offer.trackName}", style = LupeType.label.copy(fontSize = 14.sp, color = Tok.text), maxLines = 1)
                BasicText(if (offer.refused) "The FM-1 found nothing to take; it says why on its screen" else if (offer.canStart) "Keep that opens Skiff's picker here" else "Press SHIFT + SAVE on the FM-1 to keep it", style = LupeType.small, maxLines = 1)
            } else landed!!.let {
                BasicText(if (it.undone) "Undone on T${it.track} ${it.trackName}" else "Kept on T${it.track} ${it.trackName}", style = LupeType.label.copy(fontSize = 14.sp, color = Tok.text), maxLines = 1)
                BasicText("${it.length} steps at ${it.bpm} BPM" + if (it.undoFromHere) " · ${if (it.undone) "Redo brings it back" else "Undo goes back"}" else " · SAVE held, then OCT− undoes it on the FM-1", style = LupeType.small, maxLines = 1)
            }
        }
        if (offer != null && offer.canStart) TakeKey("Keep that", primary = true) { core.send(TakeStart) }
        if (landed != null && offer == null && landed.undoFromHere) TakeKey(if (landed.undone) "Redo" else "Undo") { core.send(TakeUndo) }
        Box(
            Modifier.size(48.dp).semantics { role = Role.Button; contentDescription = if (offer != null) "Let it go" else "Dismiss" }
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { core.send(if (offer != null) TakeDismissOffer else TakeDismissLanded) },
            contentAlignment = Alignment.Center,
        ) { BasicText("✕", style = LupeType.label.copy(fontSize = 16.sp, color = Tok.text2Raised)) }
    }
}
