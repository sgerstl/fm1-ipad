package com.scottgerstl.lupe.ui.projects

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import com.scottgerstl.lupe.core.ProjectsState
import com.scottgerstl.lupe.core.ProjectSaveAs
import com.scottgerstl.lupe.core.ProjectSave
import com.scottgerstl.lupe.core.ProjectRename
import com.scottgerstl.lupe.core.ProjectLoad
import com.scottgerstl.lupe.core.LupeCore
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.settings.Segmented
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.ui.shell.MenuRow
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.LupeSheet
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

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

private sealed interface Pending {
    /** Load [slot] over the playing project's unsaved changes: confirmed in place. */
    data class Load(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** Save over the playing project's own slot: replaces what it held. */
    data class Save(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** Save the playing project into a used slot: replaces that project. */
    data class SaveAs(val slot: ProjectSlotUi, val armedAt: Long) : Pending
    /** The name field in place: a Rename, or (with [save]) the name for Save here, defaulting to the playing project's. */
    data class Rename(val slot: ProjectSlotUi, val save: Boolean = false) : Pending
}

/**
 * Projects, from the FM-1 key's menu (board 67). The FM-1 keeps four. The playing one has ● and Save, the others
 * Load, an empty one Save here; ⋯ holds Rename. Load over unsaved changes asks in place (DESIGN.md: it names what
 * goes, offers Save first beside Cancel, and ignores taps for 0.4 s).
 */
@Composable
fun ProjectsSheet(ui: ProjectsUi, actions: ProjectActions) {
    val host = LocalSheetHost.current
    var pending by remember { mutableStateOf<Pending?>(null) }
    val open = host.open == SheetKind.Projects
    if (!open && pending != null) pending = null
    LupeSheet(open, "Projects", { host.close() }) {
        val playing = ui.slots.firstOrNull { it.current }
        BasicText(
            "The FM-1 keeps four projects." + (playing?.let { " Playing now: ${it.index} ${it.name}" + if (ui.changes != null) ", changed since its save." else "." } ?: ""),
            Modifier.padding(bottom = 12.dp), style = LupeType.small.copy(fontSize = 13.sp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            ui.slots.forEach { slot -> SlotRow(slot, playing, pending, { pending = it }, ui, actions) { host.close() } }
        }
        // a Save over the playing project's own slot replaces what the slot held: asked in place too
        LupeCrossfade(pending as? Pending.Save, Modifier.fillMaxWidth().padding(top = 16.dp)) { p ->
            if (p != null) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val words = "Save over ${p.slot.index} ${p.slot.name}? It replaces what the slot held."
                Box(
                    Modifier.fillMaxWidth()
                        .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                        .semantics(mergeDescendants = true) {
                            role = Role.Button; contentDescription = "Confirm: $words"
                            onClick { if (System.currentTimeMillis() - p.armedAt > 400) { actions.save(true); pending = null; true } else false }
                        }
                        .pointerInput(p) { detectTapGestures { if (System.currentTimeMillis() - p.armedAt > 400) { actions.save(true); pending = null } } }
                        .padding(14.dp),
                ) { BasicText(words, style = LupeType.key) }
                Key({ pending = null }, "Cancel", Modifier.fillMaxWidth(), height = 44.dp, fill = true) { fg -> KeyLabel("Cancel", fg) }
            }
        }
        // Save as over a used slot names the project it replaces
        LupeCrossfade(pending as? Pending.SaveAs, Modifier.fillMaxWidth().padding(top = 16.dp)) { p ->
            if (p != null) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val words = "Replace ${p.slot.index} ${p.slot.name} with ${playing?.name?.ifEmpty { "the playing project" } ?: "the playing project"}? ${p.slot.name} is gone."
                val go = { actions.saveAs(p.slot.index, playing?.name?.ifEmpty { null } ?: "Project ${p.slot.index}", true); pending = null }
                Box(
                    Modifier.fillMaxWidth()
                        .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                        .semantics(mergeDescendants = true) {
                            role = Role.Button; contentDescription = "Confirm: $words"
                            onClick { if (System.currentTimeMillis() - p.armedAt > 400) { go(); true } else false }
                        }
                        .pointerInput(p) { detectTapGestures { if (System.currentTimeMillis() - p.armedAt > 400) go() } }
                        .padding(14.dp),
                ) { BasicText(words, style = LupeType.key) }
                Key({ pending = null }, "Cancel", Modifier.fillMaxWidth(), height = 44.dp, fill = true) { fg -> KeyLabel("Cancel", fg) }
            }
        }
        // a Load that would lose changes: a red-outlined row naming what goes, Save first and Cancel
        LupeCrossfade(pending as? Pending.Load, Modifier.fillMaxWidth().padding(top = 16.dp)) { p ->
            if (p != null) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val words = "Load ${p.slot.index} ${p.slot.name}? ${ui.changes ?: "Your changes"} go."
                Box(
                    Modifier.fillMaxWidth()
                        .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                        .semantics(mergeDescendants = true) {
                            role = Role.Button; contentDescription = "Confirm: $words"
                            onClick { if (System.currentTimeMillis() - p.armedAt > 400) { actions.load(p.slot.index, true); pending = null; host.close(); true } else false }
                        }
                        .pointerInput(p) { detectTapGestures { if (System.currentTimeMillis() - p.armedAt > 400) { actions.load(p.slot.index, true); pending = null; host.close() } } }
                        .padding(14.dp),
                ) { BasicText(words, style = LupeType.key) }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // Save first writes the playing project, then loads the other
                    Key({ actions.save(true); actions.load(p.slot.index, true); pending = null; host.close() }, "Save the playing project first, then load ${p.slot.name}",
                        Modifier.weight(1f), height = 44.dp, fill = true) { fg -> KeyLabel("Save first", fg) }
                    Key({ pending = null }, "Cancel", Modifier.weight(1f), height = 44.dp, fill = true) { fg -> KeyLabel("Cancel", fg) }
                }
            }
        }
    }
}

@Composable
private fun SlotRow(slot: ProjectSlotUi, playing: ProjectSlotUi?, pending: Pending?, setPending: (Pending?) -> Unit, ui: ProjectsUi, actions: ProjectActions, closeSheet: () -> Unit) {
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
            RenameField(if (save) (playing?.name.orEmpty()) else slot.name, slot.index, { setPending(null) }) {
                if (save) actions.saveAs(slot.index, it, false) else actions.rename(slot.index, it)
                setPending(null)
            }
        }
        else Column(Modifier.weight(1f).semantics(mergeDescendants = true) { }) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                BasicText(if (slot.empty) "Empty" else slot.name, style = LupeType.key.copy(fontSize = 16.sp, color = if (slot.empty) Tok.text2 else Tok.text), maxLines = 1)
                if (slot.current) Box(Modifier.size(8.dp).background(Tok.text, androidx.compose.foundation.shape.CircleShape).semantics { contentDescription = "playing now" })
            }
            BasicText(if (slot.empty) "nothing saved here" else slot.saved, style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1)
        }
        if (!renaming) {
            when {
                slot.current -> Key({ setPending(Pending.Save(slot, System.currentTimeMillis())) }, "Save ${slot.name}", width = 68.dp, height = 36.dp, minTarget = 48.dp) { fg -> KeyLabel("Save", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                slot.empty -> Key({ setPending(Pending.Rename(slot, save = true)) }, "Save here as a new project in slot ${slot.index}: asks for a name", width = 92.dp, height = 36.dp, minTarget = 48.dp) { fg -> KeyLabel("Save here", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                else -> Key({
                    if (ui.changes != null) setPending(Pending.Load(slot, System.currentTimeMillis())) else { actions.load(slot.index, false); closeSheet() }
                }, "Load ${slot.name}", width = 68.dp, height = 36.dp, minTarget = 48.dp) { fg -> KeyLabel("Load", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            }
            Box {
                Key({ menu = true }, "More for project ${slot.index}", width = 44.dp, height = 36.dp, minTarget = 48.dp, enabled = !slot.empty) { fg ->
                    Canvas(Modifier.size(14.dp, 4.dp)) { for (i in 0..2) drawCircle(fg, 1.5.dp.toPx(), Offset(2.dp.toPx() + i * 5.dp.toPx(), 2.dp.toPx())) }
                }
                LupeMenu(menu, { menu = false }, alignEnd = true, width = 200.dp) {
                    MenuRow("Rename", { menu = false; setPending(Pending.Rename(slot)) })
                    // the playing project into this (used) slot: replaces what it holds, so it asks
                    if (!slot.current && playing != null) MenuRow("Save the playing project here", { menu = false; setPending(Pending.SaveAs(slot, System.currentTimeMillis())) }, sub = "Replaces ${slot.name}")
                }
            }
        }
    }
}

/** The name in place: a text field with Done on the keyboard and a Cancel; the project keeps its name until Done. */
@Composable
private fun RenameField(initial: String, index: Int, cancel: () -> Unit, done: (String) -> Unit) {
    var text by remember { mutableStateOf(initial) }
    val focus = remember { FocusRequester() }
    androidx.compose.runtime.LaunchedEffect(Unit) { focus.requestFocus() }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        BasicTextField(
            text, { text = it.take(16) }, Modifier.weight(1f).focusRequester(focus).background(Tok.well, RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 12.dp)
                .semantics { contentDescription = "Name of project $index" },
            textStyle = LupeType.key.copy(fontSize = 16.sp), singleLine = true, cursorBrush = SolidColor(Tok.text),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done), keyboardActions = KeyboardActions(onDone = { if (text.isNotBlank()) done(text.trim()) }),
        )
        Key({ if (text.isNotBlank()) done(text.trim()) }, "Done renaming", width = 56.dp, height = 36.dp, minTarget = 48.dp, on = true) { fg -> KeyLabel("Done", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
        Key({ cancel() }, "Cancel renaming", width = 68.dp, height = 36.dp, minTarget = 48.dp) { fg -> KeyLabel("Cancel", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
    }
}


private fun ProjectsState.toUi(): ProjectsUi = ProjectsUi(
    slots = slots.map { ProjectSlotUi(it.slot + 1, it.name, if (it.used) "kept on the FM-1" else "", it.current, !it.used) },
    changes = if (changed) "${name.ifEmpty { "This project" }}'s changes since its last save" else null,
)

/** The Projects sheet's state from the core, and what it does about a touch (slots are 0-based in the core, 1-based on the sheet). */
@Composable
fun rememberProjects(core: LupeCore): Pair<ProjectsUi, ProjectActions> {
    val state by core.projects.collectAsStateWithLifecycle()
    val ui = remember(state) { state.toUi() }
    val actions = remember(core) {
        ProjectActions(
            load = { s, c -> core.send(ProjectLoad(s - 1, c)) },
            save = { c -> core.send(ProjectSave(c)) },
            saveAs = { s, n, c -> core.send(ProjectSaveAs(s - 1, n, c)) },
            rename = { s, n -> core.send(ProjectRename(s - 1, n)) },
        )
    }
    return ui to actions
}
