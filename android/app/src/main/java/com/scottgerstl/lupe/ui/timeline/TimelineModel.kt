package com.scottgerstl.lupe.ui.timeline

import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.structuralEqualityPolicy
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.BlockDelete
import com.scottgerstl.lupe.core.BlockDuplicate
import com.scottgerstl.lupe.core.BlockMove
import com.scottgerstl.lupe.core.BlockSetPattern
import com.scottgerstl.lupe.core.BlockStretch
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.TimelineBlock
import com.scottgerstl.lupe.core.TimelineState
import com.scottgerstl.lupe.ui.sounds.LocalSoundsHost

/**
 * One block of a track's song as the screen draws it. The core's song is a track's list of entries played back to back,
 * so a block's place in time is where the ones before it end; it has no free position. [id] is its first entry (what
 * the core's intents name it by), [entries] how many entries it covers (a chain has several).
 */
data class BlockUi(
    val track: Int, val id: Int, val entries: Int,
    val start: Float, val length: Float, val passBars: Float, val reps: Int,
    val pattern: Int?, val rest: Boolean, val gap: Boolean,
    val playing: Boolean = false, val next: Boolean = false,
) {
    val end get() = start + length
    val key get() = track * 100 + id
}

/** The Timeline as the screen draws it: six tracks as columns, bars running down (decision 6, board 58). */
data class TimelineUi(
    val blocks: List<BlockUi> = emptyList(),
    val totalBars: Int = 16,
    /** The block selected on screen (not on the FM-1). */
    val selected: Int? = null,
    val selectedTrack: Int = 1,
    /** The patterns the FM-1 holds: what a block can be set to. */
    val kept: List<Int> = emptyList(),
    val trackNames: List<String> = emptyList(),
    /** How many blocks name each pattern, across every track: a pattern used nowhere else is erased when its block goes. */
    val uses: Map<Int, Int> = emptyMap(),
    /** Entries in use on each track, of 16: where the next block would go, and whether one more fits. */
    val entries: Map<Int, Int> = emptyMap(),
    /** Blocks deleted in the last ten seconds that can come back (batch item 13): the track and the block's id. */
    val deleted: List<com.scottgerstl.lupe.core.ClearedPad> = emptyList(),
)

class TimelineActions(
    val select: (key: Int?) -> Unit,
    val selectTrack: (track: Int) -> Unit,
    /** Reorder: [places] blocks earlier (negative) or later in its track's list. */
    val moveBy: (BlockUi, places: Int) -> Unit,
    /** REPS, the passes the block plays (what stretching changes). */
    val stretch: (BlockUi, reps: Int) -> Unit,
    val setPattern: (BlockUi, pattern: Int) -> Unit,
    val duplicate: (BlockUi) -> Unit,
    val delete: (BlockUi) -> Unit,
    val stop: () -> Unit,
    val openSounds: (track: Int) -> Unit,
    /** A new entry at [at] holding [pattern] (65 is a REST); the ones from there move on. */
    val insert: (track: Int, at: Int, pattern: Int) -> Unit,
    /** A new empty pattern after the track's last entry. */
    val newBlock: (track: Int) -> Unit,
    val chain: (BlockUi) -> Unit,
    val split: (BlockUi) -> Unit,
    /** Put a deleted block back (the core answers with a notice if the track changed since). */
    val undoDelete: (com.scottgerstl.lupe.core.ClearedPad) -> Unit = {},
    /** Open the Edit tab on this block's pattern (its first entry). */
    val edit: (BlockUi) -> Unit = {},
)

private fun TimelineBlock.toUi(track: Int) = BlockUi(
    track, id, last - first + 1, startBar.toFloat(), lengthBars.toFloat(), passBars.toFloat().coerceAtLeast(0.25f), reps, pattern, kind == "rest", kind == "gap", playing, next,
)

fun TimelineState.toUi(selected: Int?, selectedTrack: Int) = TimelineUi(
    blocks = tracks.flatMap { t -> t.blocks.map { it.toUi(t.track) } },
    totalBars = kotlin.math.ceil(bars).toInt().coerceAtLeast(1),
    selected = selected, selectedTrack = selectedTrack, kept = kept, trackNames = tracks.map { it.name.substringAfter(" · ") },
    uses = tracks.flatMap { t -> t.blocks.mapNotNull { it.pattern } }.groupingBy { it }.eachCount(),
    entries = tracks.associate { it.track to it.entriesUsed },
)

/**
 * The Timeline's state from the core, and what a touch does about it (blocks are reordered and stretched, not placed: see
 * [BlockUi]). Returns States: the clock moves four times a beat, and reading it only where it is drawn keeps that from
 * recomposing anything; [ui] changes only when a block does.
 */
@Composable
fun rememberTimeline(core: LupeCore): Triple<State<TimelineUi>, TimelineActions, State<Double?>> {
    val st = core.timeline.collectAsStateWithLifecycle()
    var selected by remember { mutableStateOf<Int?>(null) }
    // the FM-1's selected track (the timeline area carries none): the pads' selection
    val pads = core.pads.collectAsStateWithLifecycle()
    val sounds = LocalSoundsHost.current
    val ui = remember(st) { derivedStateOf(structuralEqualityPolicy()) { st.value.toUi(selected, pads.value.selected.track).copy(deleted = pads.value.clearUndo.filter { it.block }) } }
    // the playhead from the clock, every frame, as the pass bars are (P1's playheadBar steps by the beat now): bars = pulses / ticksPerBar, only
    // while the clock runs and the song plays; without a clock the core's beat-stepped bar still shows
    val clock = core.clock.collectAsStateWithLifecycle()
    val playingNow = core.top.collectAsStateWithLifecycle()
    var frame by remember { mutableLongStateOf(0L) }
    val running = playingNow.value.playing && clock.value.running
    androidx.compose.runtime.LaunchedEffect(running) { if (running) while (true) androidx.compose.runtime.withFrameNanos { frame = it } }
    val head = remember(st, clock, playingNow) {
        object : State<Double?> {
            override val value: Double? get() {
                if (playingNow.value.playing && clock.value.running && st.value.ticksPerBar > 0) {
                    frame      // (read, so a drawn playhead redraws each frame)
                    return clock.value.ticksNow(android.os.SystemClock.uptimeMillis()) / st.value.ticksPerBar
                }
                return st.value.playheadBar
            }
        }
    }
    val actions = remember(core, sounds, st) {
        TimelineActions(
            select = { selected = it },
            selectTrack = { core.send(Intent.TrackSelect(it)) },
            moveBy = { b, k ->
                // one place a time: each move changes the block's own id by the neighbour it passed
                val blocks = st.value.tracks.firstOrNull { it.track == b.track }?.blocks.orEmpty()
                var at = blocks.indexOfFirst { it.id == b.id }; var id = b.id
                repeat(kotlin.math.abs(k)) {
                    val nb = blocks.getOrNull(at + if (k > 0) 1 else -1) ?: return@repeat
                    core.send(BlockMove(b.track, id, if (k > 0) 1 else -1))
                    id += if (k > 0) (nb.last - nb.first + 1) else -(nb.last - nb.first + 1)
                    at += if (k > 0) 1 else -1
                }
                selected = null
            },
            stretch = { b, reps -> core.send(BlockStretch(b.track, b.id, reps)) },
            setPattern = { b, p -> core.send(BlockSetPattern(b.track, b.id, p, confirmed = true)) },
            duplicate = { core.send(BlockDuplicate(it.track, it.id)) },
            // no confirm (batch item 13): it goes at once and an Undo strip, and the lane's menu, put it back for ten seconds
            delete = { core.send(BlockDelete(it.track, it.id)); selected = null },
            stop = { core.send(Intent.Stop) },
            openSounds = { sounds.open(it) },
            insert = { t, at, p -> core.send(com.scottgerstl.lupe.core.BlockInsert(t, at, p)) },
            newBlock = { core.send(com.scottgerstl.lupe.core.BlockNew(it)) },
            chain = { core.send(com.scottgerstl.lupe.core.BlockChain(it.track, it.id)) },
            split = { core.send(com.scottgerstl.lupe.core.BlockSplit(it.track, it.id)) },
            undoDelete = { core.send(com.scottgerstl.lupe.core.UndoClear(it.track, it.entry)) },
            edit = { core.send(com.scottgerstl.lupe.core.Intent.PadSelect(it.track, it.id)); core.send(com.scottgerstl.lupe.core.Intent.SetTab(com.scottgerstl.lupe.core.Tab.Edit)) },
        )
    }
    return Triple(ui, actions, head)
}

/**
 * The Timeline tab's one entry point for the landscape shell (agreed with P2): it collects its own state from [core]
 * and fills what it is given (the body under the header line; the shell has already inset it, so no window insets here).
 */
@Composable
fun TimelineTab(core: LupeCore, modifier: Modifier = Modifier) {
    val t = rememberTimeline(core)
    TimelinePage(t.first, t.second, t.third, core.top.collectAsStateWithLifecycle(), modifier)
}
