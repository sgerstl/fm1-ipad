package com.scottgerstl.lupe.ui.projects

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PhoneProject
import com.scottgerstl.lupe.core.PhoneProjectStore
import com.scottgerstl.lupe.core.PlayingNow
import com.scottgerstl.lupe.core.PlayingSource
import com.scottgerstl.lupe.core.PoolLine
import com.scottgerstl.lupe.core.ProjectLoad
import com.scottgerstl.lupe.core.ProjectRename
import com.scottgerstl.lupe.core.ProjectSave
import com.scottgerstl.lupe.core.ProjectSaveAs
import com.scottgerstl.lupe.core.ProjectsState
import com.scottgerstl.lupe.core.poolLine
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.LocalMessages
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.ui.shell.MenuRow
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.LupeSheet
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import java.io.File
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** One of the FM-1's four project slots, as the sheet draws it. */
data class ProjectSlotUi(val index: Int, val name: String, val saved: String, val current: Boolean = false, val empty: Boolean = false)

/** What the sheet shows and can ask for. The core's `projects` area feeds it; every action is an intent. */
data class ProjectsUi(
    val slots: List<ProjectSlotUi>,
    /** The playing project's changes since its last save, in words ("Night Drive's changes since 22:40"), or null when there are none. */
    val changes: String? = null,
)

class ProjectActions(
    /** [confirmed]: the person has seen what a load would lose (the core refuses an unconfirmed load over changes). */
    val load: (slot: Int, confirmed: Boolean) -> Unit,
    /** Save over the music's own slot: only [confirmed] (it replaces what the slot held). */
    val save: (confirmed: Boolean) -> Unit,
    /** [confirmed]: over a used slot the core refuses unless the person has seen what it replaces. */
    val saveAs: (slot: Int, name: String, confirmed: Boolean) -> Unit,
    val rename: (slot: Int, name: String) -> Unit,
)

/** Everything the sheet needs: the FM-1's slots and their actions, the phone's projects, what's playing, and the pool line. */
class ProjectsScreen(val ui: ProjectsUi, val actions: ProjectActions, val phone: ProjectsController, val playing: PlayingNow, val pool: PoolLine?, val busyOnFm1: Boolean)

private sealed interface Pending {
    /** Load [slot] over the playing project's unsaved changes: confirmed in place. */
    data class Load(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** Save over the playing project's own slot: replaces what it held. */
    data class Save(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** Save the playing project into a used slot: replaces that project. */
    data class SaveAs(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** The name field in place: a Rename, or (with [save]) the name for Save here, defaulting to the playing project's. */
    data class Rename(val slot: ProjectSlotUi, val save: Boolean = false) : Pending
    /** Save to › This phone: the name field under Playing now. */
    data object NamePhone : Pending
    /** Copy an FM-1 slot to the phone: what happens to the playing music is said first. */
    data class Copy(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** Open a phone project over unsaved work (a safety copy is kept). */
    data class Open(val file: PhoneProject, val armedAt: Long) : Pending
    data class Delete(val file: PhoneProject, val armedAt: Long) : Pending
    data class RenameFile(val file: PhoneProject) : Pending
}

/** Taps on a confirm are ignored this long after it shows (DESIGN.md: a double tap can't go through it). */
private const val ARM_MS = 400L

/**
 * Projects, from the FM-1 key's menu (board 67). At the top, what's playing and where it came from, with Save (back to there) and Save to (this
 * phone, or an FM-1 slot). Then the FM-1's four slots (Load, ⋯ Rename, Copy to phone) with the pattern pool's line, and the projects on this
 * phone (Open, ⋯ Rename, Duplicate, Delete). Anything that loses work asks in place (DESIGN.md: it names what goes, and ignores taps for 0.4 s).
 * Results and refusals go to the app strip (DESIGN.md, messages); a job's progress shows in Playing now.
 */
@Composable
fun ProjectsSheet(screen: ProjectsScreen) {
    val ui = screen.ui; val actions = screen.actions; val phone = screen.phone; val playing = screen.playing
    val host = LocalSheetHost.current
    var pending by remember { mutableStateOf<Pending?>(null) }
    val open = host.open == SheetKind.Projects
    if (!open && pending != null) pending = null
    val fm1 = ui.slots.isNotEmpty()
    val idle = phone.busy == null && !screen.busyOnFm1
    // a load or save on a slot: the music lives there now (ProjectsController.leftPhone)
    val slotActions = remember(actions, phone) {
        ProjectActions(
            load = { s, c -> phone.leftPhone(); actions.load(s, c) },
            save = { c -> phone.leftPhone(); actions.save(c) },
            saveAs = { s, n, c -> phone.leftPhone(); actions.saveAs(s, n, c) },
            rename = actions.rename,
        )
    }
    LupeSheet(open, "Projects", { host.close() }) {
        PlayingRow(playing, phone.busy, fm1, idle, ui, setPending = { pending = it }, saveHome = {
            when (playing.source) {
                PlayingSource.Phone -> phone.saveOver(playing.projectId!!)
                PlayingSource.Slot -> ui.slots.firstOrNull { it.index == (playing.slot ?: -1) + 1 }?.let { pending = Pending.Save(it, System.currentTimeMillis()) }
                PlayingSource.New -> {}
            }
        })
        LupeCrossfade(pending == Pending.NamePhone, Modifier.fillMaxWidth()) { naming ->
            if (naming) Box(Modifier.padding(top = 8.dp)) {
                NameField(phone.nextName(), "Name for the project on this phone", 40, "Save", "Save on this phone", { pending = null }) {
                    phone.saveToPhone(it); pending = null
                }
            }
        }

        SectionHead("On the FM-1")
        screen.pool?.let { p ->
            BasicText(p.text, Modifier.padding(bottom = 8.dp).semantics { contentDescription = p.spoken }, style = LupeType.small.copy(fontSize = 13.sp))
        }
        if (!fm1) BasicText("Plug in the FM-1 to see its four project slots.", Modifier.padding(bottom = 8.dp), style = LupeType.small.copy(fontSize = 13.sp))
        // the firmware's own rule (skiff-sim, 2026-11-17): a slot names pool patterns, it doesn't keep copies
        else BasicText("Skiff keeps 4 projects on the FM-1. A slot keeps the arrangement but shares its patterns with what's playing, so editing a pattern changes every slot that uses it. A project on this phone keeps its own copy. Loading stops the FM-1.",
            Modifier.padding(bottom = 8.dp), style = LupeType.small.copy(fontSize = 13.sp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            ui.slots.forEach { slot ->
                Column {
                    SlotRow(slot, playing, pending, { pending = it }, ui, slotActions, idle, { phone.copyToPhone(slot.index - 1) }) { host.close() }
                    LupeCrossfade((pending as? Pending.Copy)?.takeIf { it.slot.index == slot.index }, Modifier.fillMaxWidth()) { p ->
                        if (p != null) ConfirmInPlace(copyWords(p.slot, playing), p.armedAt, { phone.copyToPhone(p.slot.index - 1); pending = null }, { pending = null })
                    }
                }
            }
        }
        // a Save over the playing project's own slot replaces what the slot held: asked in place too
        LupeCrossfade(pending as? Pending.Save, Modifier.fillMaxWidth().padding(top = 8.dp)) { p ->
            if (p != null) ConfirmInPlace("Save over P${p.slot.index} ${p.slot.name}? It replaces what the slot held.", p.armedAt,
                { slotActions.save(true); pending = null }, { pending = null })
        }
        // Save as over a used slot names the project it replaces
        LupeCrossfade(pending as? Pending.SaveAs, Modifier.fillMaxWidth().padding(top = 8.dp)) { p ->
            if (p != null) ConfirmInPlace("Replace P${p.slot.index} ${p.slot.name} with ${playing.name}? ${p.slot.name} is gone.", p.armedAt,
                { slotActions.saveAs(p.slot.index, playing.name.ifEmpty { "Project ${p.slot.index}" }, true); pending = null }, { pending = null })
        }
        // a Load that would lose changes: a red-outlined row naming what goes, Save first and Cancel
        LupeCrossfade(pending as? Pending.Load, Modifier.fillMaxWidth().padding(top = 8.dp)) { p ->
            if (p != null) ConfirmInPlace("Load P${p.slot.index} ${p.slot.name}? ${ui.changes ?: "Your changes"} go.", p.armedAt,
                { slotActions.load(p.slot.index, true); pending = null; host.close() }, { pending = null }) {
                // Save first writes the playing project, then loads the other
                Key({ slotActions.save(true); slotActions.load(p.slot.index, true); pending = null; host.close() }, "Save the playing project first, then load ${p.slot.name}",
                    Modifier.weight(1f), height = 44.dp, fill = true) { fg -> KeyLabel("Save first", fg) }
            }
        }

        SectionHead("On this phone")
        BasicText("No limit. Patterns go with each project; user sounds and samples stay on the FM-1. Saving or opening stops the FM-1.",
            Modifier.padding(bottom = 8.dp), style = LupeType.small.copy(fontSize = 13.sp))
        if (phone.files.isEmpty()) {
            BasicText("Nothing saved on this phone yet. Use Save to, then This phone.", Modifier.padding(vertical = 8.dp), style = LupeType.body.copy(fontSize = 14.sp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            phone.files.forEach { f -> FileBlock(f, phone, playing, pending, { pending = it }, fm1, idle) }
        }
        if (phone.safetyCopies.isNotEmpty()) {
            SectionHead("Safety copies")
            BasicText("Lupe keeps one before it opens something over unsaved work, and keeps the last ${PhoneProjectStore.KEPT_SAFETY_COPIES}. Rename one to keep it as a project.",
                Modifier.padding(bottom = 8.dp), style = LupeType.small.copy(fontSize = 13.sp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                phone.safetyCopies.forEach { f -> FileBlock(f, phone, playing, pending, { pending = it }, fm1, idle) }
            }
        }
    }
}

/** Copy to phone needs no question when the slot is the music already and nothing changed: nothing is saved or put back. */
internal fun copyNeedsAsking(slotIndex0: Int, p: PlayingNow): Boolean = !(p.source == PlayingSource.Slot && p.slot == slotIndex0 && !p.changed)

/** What Copy to phone does to the playing music, said before it starts. */
internal fun copyWords(slot: ProjectSlotUi, p: PlayingNow): String {
    val tag = "P${slot.index}"
    val steps = when (p.source) {
        PlayingSource.Phone -> if (p.changed) "Lupe keeps a safety copy of your changes, loads $tag, copies it, then puts your changes back."
            else "Lupe loads $tag, copies it, then opens ${p.name} again."
        PlayingSource.Slot -> if (p.changed) "Lupe keeps a safety copy of your changes, loads $tag, copies it, then puts your changes back."
            else "Lupe loads $tag, copies it, then loads P${p.slot!! + 1} again."
        PlayingSource.New -> "Lupe keeps a safety copy of what's playing, loads $tag, copies it, then puts the music back."
    }
    return "Copy $tag ${slot.name} to this phone? $steps The FM-1 stops."
}

@Composable
private fun SectionHead(title: String) =
    BasicText(title, Modifier.padding(top = 24.dp, bottom = 6.dp).semantics { heading() }, style = LupeType.label.copy(letterSpacing = 0.5.sp))

/** What's playing: its name, where it came from and whether it changed; Save back to there, and Save to anywhere. Progress shows here too. */
@Composable
private fun PlayingRow(p: PlayingNow, busy: ProjectsBusy?, fm1: Boolean, idle: Boolean, ui: ProjectsUi, setPending: (Pending?) -> Unit, saveHome: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().defaultMinSize(minHeight = 72.dp)
            .clip(RoundedCornerShape(10.dp)).background(Tok.lifted)
            .padding(start = 14.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Column(
            Modifier.weight(1f).semantics(mergeDescendants = true) {
                contentDescription = if (!fm1) "Playing now: nothing, the FM-1 isn't connected"
                    else "Playing now: ${p.name}. " + p.line.replace(" · changed since", ", changed since it was saved") + (busy?.let { ". ${it.label}" } ?: "")
            },
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            BasicText("Playing now", style = LupeType.label)
            BasicText(if (fm1) p.name else "No FM-1", style = LupeType.key.copy(fontSize = 16.sp), maxLines = 1)
            LupeCrossfade(busy?.label ?: if (fm1) p.line else "Plug in the FM-1 to save or open a project") { line ->
                BasicText(line, style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1)
            }
            busy?.progress?.let { Progress(it) }
        }
        if (fm1 && p.source != PlayingSource.New) {
            Key(saveHome, "Save ${p.name} to ${p.sourceText}", width = 68.dp, height = 36.dp, minTarget = 48.dp, enabled = idle) { fg ->
                KeyLabel("Save", fg, style = LupeType.key.copy(fontSize = 13.sp))
            }
        }
        Box {
            Key({ menu = true }, "Save to: this phone, or an FM-1 slot", width = 88.dp, height = 36.dp, minTarget = 48.dp, enabled = fm1 && idle) { fg ->
                KeyLabel("Save to…", fg, style = LupeType.key.copy(fontSize = 13.sp))
            }
            LupeMenu(menu, { menu = false }, alignEnd = true, width = 260.dp) {
                MenuRow("This phone…", { menu = false; setPending(Pending.NamePhone) }, sub = "No limit. The patterns go with it")
                ui.slots.forEach { s ->
                    MenuRow("FM-1 P${s.index} · ${if (s.empty) "Empty" else s.name}", {
                        menu = false
                        val now = System.currentTimeMillis()
                        setPending(when { s.empty -> Pending.Rename(s, save = true); s.current -> Pending.Save(s, now); else -> Pending.SaveAs(s, now) })
                    }, sub = if (s.empty) "Save here" else "Replaces it")
                }
            }
        }
    }
}

/** A write's progress: a 4 dp bar, the fill gliding to each new value. */
@Composable
private fun Progress(v: Float) {
    val shown = animatedFloat(v.coerceIn(0f, 1f), Dur.STATE)
    Box(
        Modifier.padding(top = 4.dp).fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(Tok.well)
            .semantics { progressBarRangeInfo = ProgressBarRangeInfo(v.coerceIn(0f, 1f), 0f..1f) },
    ) { Box(Modifier.fillMaxHeight().fillMaxWidth(shown.value).background(Tok.text, RoundedCornerShape(2.dp))) }
}

/** A confirm in place: a red-outlined button naming what happens, live after 0.4 s; then [extra] keys and Cancel. */
@Composable
private fun ConfirmInPlace(words: String, armedAt: Long, confirm: () -> Unit, cancel: () -> Unit, extra: (@Composable RowScope.() -> Unit)? = null) {
    Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(
            Modifier.fillMaxWidth()
                .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                .semantics(mergeDescendants = true) {
                    role = Role.Button; contentDescription = "Confirm: $words"
                    onClick { if (System.currentTimeMillis() - armedAt > ARM_MS) { confirm(); true } else false }
                }
                .pointerInput(armedAt) { detectTapGestures { if (System.currentTimeMillis() - armedAt > ARM_MS) confirm() } }
                .padding(14.dp),
        ) { BasicText(words, style = LupeType.key) }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            extra?.invoke(this)
            Key(cancel, "Cancel", Modifier.weight(1f), height = 44.dp, fill = true) { fg -> KeyLabel("Cancel", fg) }
        }
    }
}

@Composable
private fun SlotRow(
    slot: ProjectSlotUi, playing: PlayingNow, pending: Pending?, setPending: (Pending?) -> Unit, ui: ProjectsUi, actions: ProjectActions, idle: Boolean,
    copyNow: () -> Unit, closeSheet: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    val renaming = (pending as? Pending.Rename)?.slot?.index == slot.index
    Row(
        Modifier.fillMaxWidth().defaultMinSize(minHeight = 64.dp)
            .clip(RoundedCornerShape(10.dp)).background(if (slot.current) Tok.lifted else Tok.control)
            .drawBehind { if (slot.current) drawRect(Tok.text, size = androidx.compose.ui.geometry.Size(3.dp.toPx(), size.height)) }
            .padding(start = 14.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        BasicText("${slot.index}", Modifier.width(22.dp), style = LupeType.number.copy(fontSize = 24.sp, color = if (slot.empty) Tok.text2 else Tok.text))
        if (renaming) {
            val save = (pending as Pending.Rename).save
            Box(Modifier.weight(1f)) {
                NameField(if (save) playing.name else slot.name, "Name of project ${slot.index}", 16,
                    "Done", if (save) "Save in slot ${slot.index}" else "Done renaming", { setPending(null) }) {
                    if (save) actions.saveAs(slot.index, it, false) else actions.rename(slot.index, it)
                    setPending(null)
                }
            }
        }
        else Column(Modifier.weight(1f).semantics(mergeDescendants = true) { }) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                BasicText(if (slot.empty) "Empty" else slot.name, style = LupeType.key.copy(fontSize = 16.sp, color = if (slot.empty) Tok.text2 else Tok.text), maxLines = 1)
                if (slot.current) Box(Modifier.size(8.dp).background(Tok.text, CircleShape).semantics { contentDescription = "playing now" })
            }
            BasicText(if (slot.empty) "nothing saved here" else slot.saved, style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1)
        }
        if (!renaming) {
            when {
                slot.current -> Key({ setPending(Pending.Save(slot, System.currentTimeMillis())) }, "Save ${slot.name}", width = 68.dp, height = 36.dp, minTarget = 48.dp, enabled = idle) { fg -> KeyLabel("Save", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                slot.empty -> Key({ setPending(Pending.Rename(slot, save = true)) }, "Save here as a new project in slot ${slot.index}: asks for a name", width = 92.dp, height = 36.dp, minTarget = 48.dp, enabled = idle) { fg -> KeyLabel("Save here", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                else -> Key({
                    if (ui.changes != null) setPending(Pending.Load(slot, System.currentTimeMillis())) else { actions.load(slot.index, false); closeSheet() }
                }, "Load ${slot.name}", width = 68.dp, height = 36.dp, minTarget = 48.dp, enabled = idle) { fg -> KeyLabel("Load", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            }
            Box {
                MoreKey("More for project ${slot.index}", enabled = !slot.empty) { menu = true }
                LupeMenu(menu, { menu = false }, alignEnd = true, width = 240.dp) {
                    MenuRow("Rename", { menu = false; setPending(Pending.Rename(slot)) })
                    // the slot into a project on the phone; what happens to the playing music is said first
                    MenuRow("Copy to this phone", {
                        menu = false
                        if (copyNeedsAsking(slot.index - 1, playing)) setPending(Pending.Copy(slot, System.currentTimeMillis())) else copyNow()
                    }, enabled = idle, sub = "Keeps P${slot.index} on the FM-1 too")
                    // the playing project into this (used) slot: replaces what it holds, so it asks
                    if (!slot.current) MenuRow("Save the playing music here…", { menu = false; setPending(Pending.SaveAs(slot, System.currentTimeMillis())) }, enabled = idle, sub = "Replaces ${slot.name}")
                }
            }
        }
    }
}

/** A phone project, and its confirms and name field in place under it. */
@Composable
private fun FileBlock(f: PhoneProject, phone: ProjectsController, playing: PlayingNow, pending: Pending?, setPending: (Pending?) -> Unit, fm1: Boolean, idle: Boolean) {
    var menu by remember { mutableStateOf(false) }
    val home = playing.source == PlayingSource.Phone && playing.projectId == f.id
    val renaming = (pending as? Pending.RenameFile)?.file?.id == f.id
    val detail = fileDetail(f)
    Column {
        Row(
            Modifier.fillMaxWidth().defaultMinSize(minHeight = 64.dp)
                .clip(RoundedCornerShape(10.dp)).background(if (home) Tok.lifted else Tok.control)
                .drawBehind { if (home) drawRect(Tok.text, size = androidx.compose.ui.geometry.Size(3.dp.toPx(), size.height)) }
                .padding(start = 14.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (renaming) {
                Box(Modifier.weight(1f)) {
                    NameField(f.name, "New name for ${f.name}", 40, "Done", "Done renaming", { setPending(null) }) { phone.rename(f.id, it); setPending(null) }
                }
            } else {
                Column(Modifier.weight(1f).semantics(mergeDescendants = true) {
                    contentDescription = listOfNotNull(f.name, if (home) (if (playing.changed) "playing now, changed" else "playing now") else null, detail).joinToString(", ")
                }) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        BasicText(f.name, style = LupeType.key.copy(fontSize = 16.sp), maxLines = 1)
                        if (home) Box(Modifier.size(8.dp).background(Tok.text, CircleShape))
                    }
                    BasicText(if (home) "Playing now · $detail" else detail, style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1)
                }
                Key({
                    if (playing.needsSaving) setPending(Pending.Open(f, System.currentTimeMillis())) else phone.open(f)
                }, if (fm1) "Open ${f.name} on the FM-1" else "Open ${f.name}: plug in the FM-1 first", width = 68.dp, height = 36.dp, minTarget = 48.dp, enabled = fm1 && idle) { fg ->
                    KeyLabel("Open", fg, style = LupeType.key.copy(fontSize = 13.sp))
                }
                Box {
                    MoreKey("More for ${f.name}", enabled = idle) { menu = true }
                    LupeMenu(menu, { menu = false }, alignEnd = true, width = 220.dp) {
                        MenuRow("Rename", { menu = false; setPending(Pending.RenameFile(f)) }, sub = if (f.isSafetyCopy) "Keeps it as a project" else null)
                        if (!f.isSafetyCopy) MenuRow("Duplicate", { menu = false; phone.duplicate(f.id) })
                        MenuRow("Delete", { menu = false; setPending(Pending.Delete(f, System.currentTimeMillis())) }, sub = "Asks first")
                    }
                }
            }
        }
        LupeCrossfade((pending as? Pending.Open)?.takeIf { it.file.id == f.id }, Modifier.fillMaxWidth()) { p ->
            if (p != null) ConfirmInPlace(
                "Open ${f.name}? It replaces the music on the FM-1, which " +
                    (if (playing.source == PlayingSource.New) "isn't saved anywhere" else "changed since its save") +
                    ". Lupe keeps a safety copy of it first.",
                p.armedAt, { phone.open(f); setPending(null) }, { setPending(null) })
        }
        LupeCrossfade((pending as? Pending.Delete)?.takeIf { it.file.id == f.id }, Modifier.fillMaxWidth()) { p ->
            if (p != null) ConfirmInPlace("Delete ${f.name} from this phone? It's gone for good. What's on the FM-1 stays as it is.",
                p.armedAt, { phone.delete(f.id); setPending(null) }, { setPending(null) })
        }
    }
}

private val WHEN = DateTimeFormatter.ofPattern("d MMM, HH:mm", Locale.UK).withZone(ZoneId.systemDefault())

/** "Saved 17 Nov, 09:28 · 12 patterns"; a safety copy says "Taken". */
internal fun fileDetail(f: PhoneProject): String {
    val at = f.savedAt?.let { WHEN.format(it) }
    val what = if (f.patternCount == 1) "1 pattern" else "${f.patternCount} patterns"
    return listOfNotNull(at?.let { (if (f.isSafetyCopy) "Taken " else "Saved ") + it }, what).joinToString(" · ")
}

/** ⋯: a row's menu. */
@Composable
private fun MoreKey(description: String, enabled: Boolean, open: () -> Unit) =
    Key(open, description, width = 44.dp, height = 36.dp, minTarget = 48.dp, enabled = enabled) { fg ->
        Canvas(Modifier.size(14.dp, 4.dp)) { for (i in 0..2) drawCircle(fg, 1.5.dp.toPx(), Offset(2.dp.toPx() + i * 5.dp.toPx(), 2.dp.toPx())) }
    }

/** A name in place: a text field with [doneText] on the keyboard and beside it, and Cancel; nothing changes until done. */
@Composable
private fun NameField(initial: String, label: String, max: Int, doneText: String, doneDescription: String, cancel: () -> Unit, done: (String) -> Unit) {
    var text by remember { mutableStateOf(initial.take(max)) }
    val focus = remember { FocusRequester() }
    androidx.compose.runtime.LaunchedEffect(Unit) { focus.requestFocus() }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        BasicTextField(
            text, { text = it.take(max) }, Modifier.weight(1f).focusRequester(focus).background(Tok.well, RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 12.dp)
                .semantics { contentDescription = label },
            textStyle = LupeType.key.copy(fontSize = 16.sp), singleLine = true, cursorBrush = SolidColor(Tok.text),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done), keyboardActions = KeyboardActions(onDone = { if (text.isNotBlank()) done(text.trim()) }),
        )
        Key({ if (text.isNotBlank()) done(text.trim()) }, doneDescription, width = 56.dp, height = 36.dp, minTarget = 48.dp, on = true) { fg -> KeyLabel(doneText, fg, style = LupeType.key.copy(fontSize = 13.sp)) }
        Key({ cancel() }, "Cancel", width = 68.dp, height = 36.dp, minTarget = 48.dp) { fg -> KeyLabel("Cancel", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
    }
}


private fun ProjectsState.toUi(): ProjectsUi = ProjectsUi(
    slots = slots.map { ProjectSlotUi(it.slot + 1, it.name, if (it.used) "kept on the FM-1" else "", it.current, !it.used) },
    changes = if (changed) "${name.ifEmpty { "This project" }}'s changes since its last save" else null,
)

/** The Projects sheet's state from the core, and what it does about a touch (slots are 0-based in the core, 1-based on the sheet). */
@Composable
fun rememberProjects(core: LupeCore): ProjectsScreen {
    val state by core.projects.collectAsStateWithLifecycle()
    val patterns by core.patterns.collectAsStateWithLifecycle()
    val ui = remember(state) { state.toUi() }
    val actions = remember(core) {
        ProjectActions(
            load = { s, c -> core.send(ProjectLoad(s - 1, c)) },
            save = { c -> core.send(ProjectSave(c)) },
            saveAs = { s, n, c -> core.send(ProjectSaveAs(s - 1, n, c)) },
            rename = { s, n -> core.send(ProjectRename(s - 1, n)) },
        )
    }
    val ctx = LocalContext.current
    val messages = LocalMessages.current
    val scope = rememberCoroutineScope()
    // the app's own storage (filesDir/Projects): private to Lupe, kept until the app is removed
    val phone = remember(core) { ProjectsController(core, PhoneProjectStore(File(ctx.filesDir, "Projects")), scope, messages) }
    val playing = phone.playing(state)
    val pool = remember(patterns) { poolLine(patterns) }
    return ProjectsScreen(ui, actions, phone, playing, pool, state.busy)
}
