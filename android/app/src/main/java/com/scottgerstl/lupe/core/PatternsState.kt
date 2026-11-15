package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The pattern pool (board 79, decision 38; P1's 3d09937): the FM-1's 64 pattern numbers, shared by every saved project. The `patterns` area is
// live (playing too); `patternPictures` is separate so the big part isn't resent when a use changes.

/** A pad of this project that names a pattern: [track] 1…6, [entry] from 0. */
@Serializable
data class PatternUse(val track: Int, val entry: Int)

/**
 * One kept pattern. [uses] is the FM-1's total count of things that use it (capped at 127); [here] the pads of this project, in track order;
 * [on] the tracks sitting on it now (1…6); [saved] a saved project holds it too (a dot). [unused] is the core's word: the FM-1's count is 0, so
 * Clear takes it (a pattern with no [here] but [saved] is not unused).
 */
@Serializable
data class PoolPattern(
    val number: Int, val len: Int = 0, val uses: Int = 0,
    val here: List<PatternUse> = emptyList(), val on: List<Int> = emptyList(), val saved: Boolean = false, val unused: Boolean = false,
)

/** Kept numbers only, ascending. [recycle] is the number Recycle will take (the lowest unused), absent when none. */
@Serializable
data class PatternsState(
    val free: Int = 0, val kept: Int = 0, val unused: Int = 0, val recycle: Int? = null,
    /** Playing, and some kept pattern has no current picture: "Stop to load pictures". */
    val picturesWaitForStop: Boolean = false,
    /** Stopped with the sheet open, and some are still being read: a quiet placeholder. */
    val picturesLoading: Boolean = false,
    val patterns: List<PoolPattern> = emptyList(),
)

/**
 * A pattern's picture: [notes] and [hits] each have [len] values (up to 64), one per step. [notes]: the highest MIDI note starting on the step,
 * −1 for none; [hits]: how many drum lanes hit there. [drums] true: draw [hits], else [notes]. [live]: drawn from the track that is on it, so it
 * is current and present while playing too.
 */
@Serializable
data class PatternPicture(
    val number: Int, val len: Int = 0, val drums: Boolean = false,
    val notes: List<Int> = emptyList(), val hits: List<Int> = emptyList(), val live: Boolean = false,
)

@Serializable
data class PatternPictures(val pictures: List<PatternPicture> = emptyList())

object PatternsDefaults {
    val patterns: kotlinx.coroutines.flow.StateFlow<PatternsState> = kotlinx.coroutines.flow.MutableStateFlow(PatternsState())
    val pictures: kotlinx.coroutines.flow.StateFlow<PatternPictures> = kotlinx.coroutines.flow.MutableStateFlow(PatternPictures())
}

/** The sheet opened or closed: the FM-1's stored notes are read only while it is open (stopped only; never stops playback). Not a write. */
@Serializable @SerialName("patternsOpen") data class PatternsOpen(val open: Boolean) : Intent

/** Clear these kept patterns; only unused ones go, stopped only, nothing is sent without [confirmed] (the screen asks once in place first). */
@Serializable @SerialName("clearPatterns") data class ClearPatterns(val numbers: List<Int>, val confirmed: Boolean = false) : Intent

/** The lowest unused number onto this pad, then emptied: a fresh pattern without a free number. No confirm (the menu names the number); stopped only. */
@Serializable @SerialName("recyclePattern") data class RecyclePattern(val track: Int, val entry: Int) : Intent

/** Copy pattern [number] to this empty pad: needs a free number; works while playing. */
@Serializable @SerialName("copyPattern") data class CopyPattern(val number: Int, val track: Int, val entry: Int) : Intent

/** "1 · E": a pad, as the sheet names it. */
fun padName(track: Int, entry: Int) = "$track · ${'A' + entry}"

/** "T2 A · T4 C": where this project uses a pattern, in track order. */
fun usesText(here: List<PatternUse>): String = here.joinToString(" · ") { "T${it.track} ${'A' + it.entry}" }
