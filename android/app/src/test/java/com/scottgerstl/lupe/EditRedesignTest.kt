package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.ScreenGoto
import com.scottgerstl.lupe.core.SetStepNotes
import com.scottgerstl.lupe.core.Step
import com.scottgerstl.lupe.core.StepField
import com.scottgerstl.lupe.ui.edit.NoteDrag
import com.scottgerstl.lupe.ui.edit.moveNote
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest

/** The Edit redesign (Scott, 2026-11-17): the condition picker's words, the FM-1 cursor link, and a dragged note's drop. */
@OptIn(ExperimentalCoroutinesApi::class)
class EditRedesignTest {
    private fun fake(scope: TestScope) = FakeLupeCore(scope, emptyMap(), "searching")
    @Test fun conditionsReadAsWords() {
        assertEquals("Always", com.scottgerstl.lupe.ui.shell.condWords("ALWAYS"))
        assertEquals("Every 2nd of 4", com.scottgerstl.lupe.ui.shell.condWords("2:4"))
        assertEquals("Not fill", com.scottgerstl.lupe.ui.shell.condWords("!FILL"))
        assertEquals(12, com.scottgerstl.lupe.ui.shell.CONDITIONS.size)   // the core's table (PadsEditor.swift)
    }

    @Test fun screenGotoCarriesTheCursorOnNotesAndFeelOnly() = runTest {
        val core = fake(this)
        core.send(ScreenGoto("SEQ", 41, cursor = 5))
        assertEquals("SEQ", core.fm1Screen.value.key); assertEquals(5, core.fm1Screen.value.cursor)
        core.send(ScreenGoto("SEQ", 42, cursor = 9))
        assertEquals(9, core.fm1Screen.value.cursor)
        core.send(ScreenGoto("SEQ", 43, cursor = 3))                           // PATTERN: no step cursor
        assertEquals(null, core.fm1Screen.value.cursor)
    }

    private class Recording(base: LupeCore) : LupeCore by base { val sent = mutableListOf<Intent>(); override fun send(intent: Intent) { sent += intent } }

    @Test fun aDroppedNoteChangesPitchFirstThenMoves() = runTest {
        val ed = EditorState(steps = List(16) { if (it == 2) Step(on = true, notes = listOf(60, 64)) else Step() })
        val core = Recording(fake(this))
        var landed = -1
        moveNote(ed, NoteDrag(fromStep = 2, fromPitch = 64, toStep = 5, toPitch = 65), core) { landed = it }
        assertEquals(SetStepNotes(2, listOf(60, 65)), core.sent[0])                 // the dragged note only, in place first
        assertEquals(Intent.StepSelect(2), core.sent[1])
        assertEquals(Intent.StepAdjust(StepField.Move, 3), core.sent[2])           // then the step moves (a refusal leaves only the pitch changed)
        assertEquals(5, landed)
        val same = Recording(fake(this))
        moveNote(ed, NoteDrag(2, 64, 2, 67), same) {}
        assertEquals(listOf<Intent>(SetStepNotes(2, listOf(60, 67))), same.sent)    // a pitch change alone: no move
    }
}
