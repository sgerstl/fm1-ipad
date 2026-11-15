package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.matchIds
import org.junit.Assert.*
import org.junit.Test

class EntryIdsTest {
    private var n = 100L
    private fun m(old: List<String>, oldIds: List<Long>, new: List<String>) = matchIds(old, oldIds, new) { n++ }

    @Test fun aDuplicateGetsANewIdAndTheOnesAfterItKeepTheirs() {
        // A B → A A' B: the copy of A is new (same key as A: the earlier A keeps its id), B keeps its id and moves along
        val ids = m(listOf("a", "b", "e"), listOf(1, 2, 3), listOf("a", "a", "b", "e"))
        assertEquals(1L, ids[0]); assertEquals(2L, ids[2]); assertEquals(3L, ids[3]); assertTrue(ids[1] !in listOf(1L, 2L, 3L))
    }

    @Test fun aDeleteClosesUpAndTheRestKeepTheirIds() {
        assertEquals(listOf(2L, 3L, 4L), m(listOf("a", "b", "c", "e"), listOf(1, 2, 3, 4), listOf("b", "c", "e")))
    }

    @Test fun aSwapKeepsBothIds() {
        val ids = m(listOf("a", "b", "e"), listOf(1, 2, 3), listOf("b", "a", "e"))
        assertEquals(setOf(1L, 2L, 3L), ids.toSet())
        assertEquals(listOf(2L, 1L, 3L).toSet(), ids.toSet())
    }

    @Test fun aMoveOntoAnEmptyKeepsTheMoversId() {
        // A e e → e A e
        val ids = m(listOf("a", "e", "e"), listOf(1, 2, 3), listOf("e", "a", "e"))
        assertEquals(1L, ids[1])
    }

    @Test fun nothingChangedChangesNothing() {
        assertEquals(listOf(1L, 2L), m(listOf("a", "b"), listOf(1, 2), listOf("a", "b")))
    }
}
