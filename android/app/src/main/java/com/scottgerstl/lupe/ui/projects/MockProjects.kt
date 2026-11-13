package com.scottgerstl.lupe.ui.projects

import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.Stable

/**
 * STAND-IN until P1's `projects` area lands: four slots as board 67 draws them, answering the sheet's actions
 * locally. Replaced by the core's state (the sheet only knows [ProjectsUi] and [ProjectActions]).
 */
@Stable
class MockProjects {
    var ui by mutableStateOf(
        ProjectsUi(
            listOf(
                ProjectSlotUi(1, "Night Drive", "saved today 22:40", current = true),
                ProjectSlotUi(2, "Koto sketch", "saved 11 Nov"),
                ProjectSlotUi(3, "", "", empty = true),
                ProjectSlotUi(4, "Acid test", "saved 2 Nov"),
            ),
            changes = "Night Drive's changes since 22:40",
        ),
    )
        private set

    val actions = ProjectActions(
        load = { s -> ui = ui.copy(slots = ui.slots.map { it.copy(current = it.index == s) }, changes = null) },
        save = { s -> ui = ui.copy(slots = ui.slots.map { if (it.index == s) it.copy(saved = "saved just now") else it }, changes = null) },
        saveAs = { s, n -> ui = ui.copy(slots = ui.slots.map { if (it.index == s) it.copy(name = n, saved = "saved just now", empty = false, current = true) else it.copy(current = false) }, changes = null) },
        rename = { s, n -> ui = ui.copy(slots = ui.slots.map { if (it.index == s) it.copy(name = n) else it }) },
    )
}

@Composable
fun rememberMockProjects() = remember { MockProjects() }
