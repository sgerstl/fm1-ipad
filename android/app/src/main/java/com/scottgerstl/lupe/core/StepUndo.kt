package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Edit's undo and redo (Scott, 2026-11-18: "undo, with long press to redo"). The core keeps the history (StepUndo.swift): a gesture starts
// with [UndoMark], and the step edits after it are one undo step. [StepUndo] puts the newest back, [StepRedo] does it again. EditorState's
// undoLabel / redoLabel say what they would do; null: nothing to undo / redo.

/** A new undo step starts: the step edits that follow are one edit, called [label] ("note added · step 5"). */
@Serializable @SerialName("undoMark") data class UndoMark(val label: String) : Intent
@Serializable @SerialName("stepUndo") data object StepUndo : Intent
@Serializable @SerialName("stepRedo") data object StepRedo : Intent
