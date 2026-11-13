package com.scottgerstl.lupe.ui.sounds

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.CustomAccessibilityAction
import com.scottgerstl.lupe.ui.shell.MenuRow
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.core.EraseUser
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.ClearEntrySound
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PickPreset
import com.scottgerstl.lupe.core.PickUser
import com.scottgerstl.lupe.core.SaveSound
import com.scottgerstl.lupe.core.SoundsView
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.WideKey
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

private data class SlotConfirm(val slot: Int, val armedAt: Long, val erase: Boolean, val name: String = "")

/** A user slot's name from the track's: the core names tracks "Engine · Sound", and the slot should carry the sound (8 characters, as the FM-1 keeps). */
internal fun saveName(trackName: String) = trackName.substringAfter(" · ").trim().take(8).uppercase().ifEmpty { "SOUND" }

private const val USER = -1   // the left list's last entry: the FM-1's 32 user slots

/**
 * The Sounds browser, in the bottom half over the editor (board 66): from a track number held on Pads, a Mix row, or a
 * pad's hold menu. The engines the firmware offers down the left at 40 dp, then User (its 32 slots); the presets in two
 * columns at 40 dp. Tapping one puts the track on it at once, so you hear it; the tick marks what it plays. On a drum
 * track a pad's own sound (opened from its menu) overrides one pad (decision 15). Save puts the track's sound into a user
 * slot, asking in place over a used one. Done or Back closes it and the editor returns. All of it is the core's `sounds`
 * area and its intents; nothing here is a guess about what the FM-1 holds.
 */
@Composable
fun SoundsBrowser(core: LupeCore, request: SoundsRequest, onDone: () -> Unit, modifier: Modifier = Modifier) {
    BackHandler { onDone() }
    val s by core.sounds.collectAsStateWithLifecycle()
    val colour = Tok.track[(request.track - 1).coerceAtLeast(0) % Tok.track.size]
    val haptic = LocalHapticFeedback.current
    val padMode = request.pad != null
    val engines = s.engines.filter { it.offered }
    // what the left list shows: an engine (the core's `viewing`) or User; Save also opens User, to choose a slot
    var userView by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    // a user slot asked about in place: to be replaced by Save, or erased (from its hold menu)
    var confirmSlot by remember { mutableStateOf<SlotConfirm?>(null) }
    // the name for a Save, asked in place once a slot is chosen (it defaults to the sound's own name)
    var naming by remember { mutableStateOf<Int?>(null) }
    val viewing = if (userView) USER else s.viewing
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().height(40.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.size(10.dp).background(colour, RoundedCornerShape(5.dp)))
            BasicText(
                if (padMode) "Sound for pad ${request.pad} on track ${request.track}" else if (saving) "Save ${s.trackName.ifEmpty { "this sound" }} to a user slot" else "Choose a sound for track ${request.track}",
                Modifier.weight(1f).semantics { heading() }, style = LupeType.key.copy(fontSize = 15.sp), maxLines = 1,
            )
            if (!padMode) Key({ saving = !saving; userView = saving; confirmSlot = null; naming = null }, if (saving) "Stop saving" else "Save this sound to a user slot", width = 56.dp, height = 32.dp, minTarget = 40.dp, on = saving, role = Role.Switch) { fg -> KeyLabel("Save", fg) }
            Key(onDone, "Done: keep this sound and go back", width = 64.dp, height = 32.dp, minTarget = 40.dp) { fg -> KeyLabel("Done", fg) }
        }
        Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LazyColumn(Modifier.width(112.dp).fillMaxHeight(), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 28.dp)) {
                items(engines.map { it.index } + USER) { e ->
                    val name = if (e == USER) "USER" else engines.first { it.index == e }.name
                    val on = e == viewing
                    val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                    Box(
                        Modifier.fillMaxWidth().height(40.dp)
                            .drawBehind { if (lit.value > 0f) { drawRect(Tok.well.copy(alpha = lit.value)); drawRect(colour.copy(alpha = lit.value), size = Size(3.dp.toPx(), size.height)) } }
                            .semantics(mergeDescendants = true) { role = Role.Tab; selected = on; contentDescription = "${name.lowercase().replaceFirstChar { it.uppercase() }} sounds" }
                            .pointerInput(e, saving) { detectTapGestures { if (e == USER) userView = true else if (!saving) { userView = false; core.send(SoundsView(e)) } } }
                            .padding(start = 12.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) { BasicText(name, style = LupeType.key.copy(fontSize = 13.sp, letterSpacing = 0.4.sp, color = lerp(Tok.text2, Tok.text, lit.value)), maxLines = 1) }
                }
            }
            Column(Modifier.weight(1f).fillMaxHeight()) {
                LupeCrossfade(viewing, Modifier.weight(1f).fillMaxWidth(), Dur.STATE) { v ->
                    if (v == USER) LazyVerticalGrid(GridCells.Fixed(2), Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        itemsIndexed(s.user) { _, u ->
                            Tile(
                                text = if (u.used) u.name else "${u.slot + 1} · empty", current = u.current, dim = !u.used && !saving, colour = colour,
                                description = "User slot ${u.slot + 1}, " + if (u.used) u.name else "empty", state = if (u.current) "Playing on this track" else "",
                                // held: its menu beside the finger, Erase asked in place (a used slot only)
                                menu = if (u.used) { close -> MenuRow("Erase user slot ${u.slot + 1}…", { close(); confirmSlot = SlotConfirm(u.slot, System.currentTimeMillis(), true) }) } else null,
                                actionLabel = if (u.used) "Erase user slot ${u.slot + 1}" else null,
                                onAction = { confirmSlot = SlotConfirm(u.slot, System.currentTimeMillis(), true) },
                            ) {
                                haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
                                when {
                                    saving -> { naming = u.slot; confirmSlot = null }
                                    u.used -> core.send(PickUser(u.slot))
                                }
                            }
                        }
                    } else LazyVerticalGrid(GridCells.Fixed(2), Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        itemsIndexed(s.presets) { i, p ->
                            val current = if (padMode) s.entrySound?.let { it.kind == "preset" && it.engine == s.viewing && it.preset == p.index } == true else p.current
                            Tile(p.name, current, false, colour, p.name.lowercase().replaceFirstChar { it.uppercase() }, if (current) "Playing on this ${if (padMode) "pad" else "track"}" else "") {
                                haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
                                core.send(PickPreset(s.viewing, p.index))
                            }
                        }
                    }
                }
                // the name for a Save: a text field in place, the sound's own name filled in; Save, then (over a used slot) the confirm
                LupeCrossfade(naming, Modifier.fillMaxWidth().padding(top = 4.dp)) { slot ->
                    if (slot != null) {
                        var text by remember(slot) { mutableStateOf(saveName(s.trackName)) }
                        val used = s.user.getOrNull(slot)?.used == true
                        val go = { val n = text.trim().take(8).uppercase().ifEmpty { saveName(s.trackName) }
                            if (used) confirmSlot = SlotConfirm(slot, System.currentTimeMillis(), false, n) else { core.send(SaveSound(slot, n)); saving = false }
                            naming = null }
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            androidx.compose.foundation.text.BasicTextField(
                                text, { text = it.take(8) }, Modifier.weight(1f).background(Tok.well, RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 12.dp)
                                    .semantics { contentDescription = "Name for user slot ${slot + 1}" },
                                textStyle = LupeType.key.copy(fontSize = 15.sp), singleLine = true, cursorBrush = androidx.compose.ui.graphics.SolidColor(Tok.text),
                                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = androidx.compose.ui.text.input.ImeAction.Done, capitalization = androidx.compose.ui.text.input.KeyboardCapitalization.Characters),
                                keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { go() }),
                            )
                            Key({ go() }, "Save into user slot ${slot + 1} under this name", width = 56.dp, height = 36.dp, minTarget = 48.dp, on = true) { fg -> KeyLabel("Save", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                            Key({ naming = null }, "Cancel naming", width = 68.dp, height = 36.dp, minTarget = 48.dp) { fg -> KeyLabel("Cancel", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                        }
                    }
                }
                // a Save over a used user slot, or an Erase, asked in place: names the slot; taps are ignored for the first 0.4 s
                LupeCrossfade(confirmSlot, Modifier.fillMaxWidth().padding(top = 4.dp)) { c ->
                    if (c != null) Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        val u = s.user.getOrNull(c.slot)
                        val slotWords = "user slot ${c.slot + 1}${u?.name?.takeIf { it.isNotEmpty() }?.let { " ($it)" } ?: ""}"
                        val words = if (c.erase) "Erase $slotWords? It can't be undone." else "Replace $slotWords with this sound?"
                        val go = {
                            if (c.erase) core.send(EraseUser(c.slot, confirmed = true))
                            else { core.send(SaveSound(c.slot, c.name.ifBlank { saveName(s.trackName) }, confirmed = true)); saving = false }
                            confirmSlot = null
                        }
                        Box(
                            Modifier.fillMaxWidth().drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                                .semantics(mergeDescendants = true) {
                                    role = Role.Button; contentDescription = "Confirm: $words"
                                    onClick { if (System.currentTimeMillis() - c.armedAt > 400) { go(); true } else false }
                                }
                                .pointerInput(c) { detectTapGestures { if (System.currentTimeMillis() - c.armedAt > 400) go() } }
                                .padding(10.dp),
                        ) { BasicText(words, style = LupeType.key.copy(fontSize = 13.sp)) }
                        WideKey("Cancel", { confirmSlot = null })
                    }
                }
                if (padMode && s.entrySound != null) WideKey("Use the track's own sound", { core.send(ClearEntrySound) }, Modifier.padding(top = 4.dp))
                BasicText(
                    s.refusal ?: when {
                        saving -> "Pick a user slot to save into"
                        padMode -> "Tap a sound for pad ${request.pad} · Done keeps it"
                        else -> "Tap a preset to hear it on the track · Done keeps it"
                    },
                    Modifier.padding(top = 6.dp), style = LupeType.small.copy(fontSize = 12.sp, color = if (s.refusal != null) Tok.text else Tok.text2Raised), maxLines = 2,
                )
            }
        }
    }
}

/** A preset (or a user slot): 40 dp, two to a row; the one playing is tinted in the track's colour with a ring and a tick. A held tile can open a menu beside the finger. */
@Composable
private fun Tile(
    text: String, current: Boolean, dim: Boolean, colour: androidx.compose.ui.graphics.Color, description: String, state: String,
    menu: (@Composable (close: () -> Unit) -> Unit)? = null, actionLabel: String? = null, onAction: () -> Unit = {}, onTap: () -> Unit,
) {
    val lit = animatedFloat(if (current) 1f else 0f, Dur.STATE)
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    Box(Modifier.fillMaxWidth().height(40.dp)) {
        Box(
            Modifier.matchParentSize().clip(RoundedCornerShape(8.dp))
                .background(lerp(Tok.control, lerp(Tok.page, colour, 0.35f), lit.value))
                .drawBehind { if (lit.value > 0f) drawRoundRect(Tok.text.copy(alpha = lit.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx())) }
                .semantics(mergeDescendants = true) {
                    role = Role.Button; contentDescription = description; stateDescription = state; onClick { onTap(); true }
                    // every hold has a non-hold way in (WCAG 2.5.7)
                    if (actionLabel != null) customActions = listOf(CustomAccessibilityAction(actionLabel) { onAction(); true })
                }
                .pointerInput(onTap, menu != null) { detectTapGestures(onTap = { onTap() }, onLongPress = { at -> if (menu != null) menuAt = at }) }
                .padding(horizontal = 10.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            BasicText(text, style = LupeType.key.copy(fontSize = 13.sp, letterSpacing = 0.3.sp, color = if (dim) Tok.text2Raised else Tok.text), maxLines = 1)
            if (current) Canvas(Modifier.align(Alignment.CenterEnd).size(14.dp, 12.dp)) {
                val path = Path().apply { moveTo(1.dp.toPx(), size.height * 0.55f); lineTo(size.width * 0.38f, size.height - 1.dp.toPx()); lineTo(size.width - 1.dp.toPx(), 1.dp.toPx()) }
                drawPath(path, Tok.text, style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
        }
        if (menu != null) LupeMenu(menuAt != null, { menuAt = null }, width = 232.dp, at = menuAt) { menu { menuAt = null } }
    }
}
