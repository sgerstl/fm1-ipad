package com.scottgerstl.lupe.ui.timeline

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** One block of the song: a pattern (or a REST) playing on a track for [bars] whole bars from bar [start] (0-based). */
data class BlockUi(val id: Int, val track: Int, val start: Int, val bars: Int, val pattern: Int?, val rest: Boolean = false) {
    val end get() = start + bars
}

/** The Timeline as the screen draws it: six tracks as columns, bars running down (decision 6, board 58). */
data class TimelineUi(
    val blocks: List<BlockUi> = emptyList(),
    /** How long the song is, in bars (at least the longest track). */
    val totalBars: Int = 16,
    val selected: Int? = null,
    val selectedTrack: Int = 1,
    /** The patterns the FM-1 holds: what a block can be set to. */
    val kept: List<Int> = emptyList(),
    val trackNames: List<String> = emptyList(),
    /** The FM-1 refuses changes to the order while the song plays: the strip says so, with Stop. */
    val playing: Boolean = false,
)

class TimelineActions(
    val select: (id: Int?) -> Unit,
    val selectTrack: (track: Int) -> Unit,
    val move: (id: Int, start: Int) -> Unit,
    val resize: (id: Int, bars: Int) -> Unit,
    val setPattern: (id: Int, pattern: Int) -> Unit,
    val duplicate: (id: Int) -> Unit,
    val delete: (id: Int) -> Unit,
    val stop: () -> Unit,
    val openSounds: (track: Int) -> Unit,
)

/**
 * STAND-IN until P1's `timeline` area lands (board 58's song). The screen only knows [TimelineUi] and
 * [TimelineActions]; the core's state replaces this and nothing above changes. The rules a core enforces are mirrored so
 * a stand-in can't promise what the FM-1 won't do: a block can't overlap its track's neighbours.
 */
@Stable
class MockTimeline {
    private var nextId = 100
    var ui by mutableStateOf(
        TimelineUi(
            blocks = listOf(
                BlockUi(1, 1, 0, 4, 5), BlockUi(2, 1, 4, 4, 5), BlockUi(3, 1, 8, 8, 7),
                BlockUi(4, 2, 0, 8, 2), BlockUi(5, 2, 8, 8, 3),
                BlockUi(6, 3, 0, 4, null, rest = true), BlockUi(7, 3, 4, 4, 11), BlockUi(8, 3, 8, 4, 11), BlockUi(9, 3, 12, 4, 14),
                BlockUi(10, 4, 0, 4, 1), BlockUi(11, 4, 4, 4, 4), BlockUi(12, 4, 8, 4, 4), BlockUi(13, 4, 12, 4, 6),
                BlockUi(14, 5, 0, 8, null, rest = true), BlockUi(15, 5, 8, 8, 12),
                BlockUi(16, 6, 0, 8, 9), BlockUi(17, 6, 8, 8, 10),
            ),
            totalBars = 16, selected = null, selectedTrack = 5, kept = listOf(1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15),
            trackNames = listOf("Acid", "Pad", "Pulse Ld", "Drum Kit", "Piano", "Perc Kit"),
        ),
    )
        private set

    private fun block(id: Int) = ui.blocks.first { it.id == id }
    private fun others(b: BlockUi) = ui.blocks.filter { it.track == b.track && it.id != b.id }
    private fun edit(id: Int, f: (BlockUi) -> BlockUi) { ui = ui.copy(blocks = ui.blocks.map { if (it.id == id) f(it) else it }) }

    val actions = TimelineActions(
        select = { ui = ui.copy(selected = it) },
        selectTrack = { ui = ui.copy(selectedTrack = it) },
        move = { id, start ->
            val b = block(id); val o = others(b)
            val lo = o.filter { it.end <= b.start }.maxOfOrNull { it.end } ?: 0
            val hi = o.filter { it.start >= b.end }.minOfOrNull { it.start } ?: Int.MAX_VALUE
            edit(id) { it.copy(start = start.coerceIn(lo, (hi - b.bars).coerceAtLeast(lo))) }
        },
        resize = { id, bars ->
            val b = block(id); val hi = others(b).filter { it.start >= b.end }.minOfOrNull { it.start } ?: Int.MAX_VALUE
            edit(id) { it.copy(bars = bars.coerceIn(1, (hi - b.start).coerceAtMost(64))) }
        },
        setPattern = { id, p -> edit(id) { it.copy(pattern = p, rest = false) } },
        duplicate = { id ->
            val b = block(id)
            val free = others(b).none { it.start < b.end + b.bars && it.end > b.end }
            if (free) ui = ui.copy(blocks = ui.blocks + b.copy(id = nextId++, start = b.end), selected = null)
        },
        delete = { id -> ui = ui.copy(blocks = ui.blocks.filter { it.id != id }, selected = null) },
        stop = { ui = ui.copy(playing = false) },
        openSounds = { },
    )

    fun playing(on: Boolean) { ui = ui.copy(playing = on) }
}
