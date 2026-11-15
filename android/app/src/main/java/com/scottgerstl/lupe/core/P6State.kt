package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// P6's areas: timeline and automation (android/BRIDGE.md §2's phase table). Mirrors P1's
// android/core/Sources/PhoneCore/P6State.swift; fixtures recorded from FakeSkiff. Direction-free: the phone draws time
// down (decision 6), the area only says where things are in bars and steps.

// ---- timeline

@Serializable
data class TimelineBlock(
    /** The block's first entry (0-based): what the intents name it by. */
    val id: Int,
    val first: Int,
    val last: Int,
    /** "pattern", "rest", or "gap" (an empty entry inside the list). */
    val kind: String = "pattern",
    /** Pattern number 1…64 (a chain's first part); [patterns] all the chain's parts. */
    val pattern: Int? = null,
    val patterns: List<Int> = emptyList(),
    /** REPS: passes it plays (stretch changes this). */
    val reps: Int = 1,
    /** Bars (4/4) from the song's start, its length, and one pass. */
    val startBar: Double = 0.0,
    val lengthBars: Double = 0.0,
    val passBars: Double = 0.0,
    val hasSound: Boolean = false,
    /** The block the track is on, its pass (1-based) when known, the one the song or a launch brings next. */
    val playing: Boolean = false,
    val pass: Int? = null,
    val next: Boolean = false,
    val queued: Boolean = false,
)

@Serializable
data class TimelineTrack(
    val track: Int,
    val name: String = "",
    val muted: Boolean = false,
    val blocks: List<TimelineBlock> = emptyList(),
    val endBar: Double = 0.0,
    /** Entries in use, of 16: whether one more fits. */
    val entriesUsed: Int = 0,
)

@Serializable
data class TimelineState(
    /** SONG "off" (each track loops its block), "on", "once". */
    val mode: String = "off",
    val tracks: List<TimelineTrack> = emptyList(),
    /** The song's length in bars (the longest track). */
    val bars: Double = 0.0,
    /** The clock in bars since Start; null when stopped. */
    val playheadBar: Double? = null,
    /** Clock pulses in a bar (96): the smooth playhead is the clock's pulse count over this (P1's 6f2f933 makes [playheadBar] step by the beat). */
    val ticksPerBar: Int = 96,
    val playing: Boolean = false,
    /** Pattern numbers the FM-1 holds (what Set pattern may name). */
    val kept: List<Int> = emptyList(),
)

// ---- automation (decision 7: one lane at a time under the grid)

@Serializable
data class AutomationLane(
    val param: String,
    val id: Int,
    /** Recorded changes (drawn ones are recorded too: MOTION keeps no difference) and locks on the lane. */
    val recorded: Int = 0,
    val locks: Int = 0,
)

@Serializable
data class AutomationPoint(
    val step: Int,
    val value: Int,
    /** "lock" (this step only), "recorded" (a change at or before this step, held), "sound" (the sound's own). */
    val source: String = "sound",
    val text: String = "",
)

@Serializable
data class AutomationState(
    val track: Int = 1,
    val pattern: Int = 0,
    /** The pattern's length: what a lane spans. */
    val steps: Int = 16,
    val lanes: List<AutomationLane> = emptyList(),
    /** The lane shown, "" when none. */
    val lane: String = "",
    val min: Int = 0,
    val max: Int = 127,
    /** The sound's own value (what the lane returns to). */
    val base: Int = 0,
    val points: List<AutomationPoint> = emptyList(),
    /** MOTION's shared records across all tracks, used of [capacity] (64). */
    val used: Int = 0,
    val capacity: Int = 64,
)

object P6Defaults {
    val timeline: StateFlow<TimelineState> = MutableStateFlow(TimelineState())
    val automation: StateFlow<AutomationState> = MutableStateFlow(AutomationState())
}

// ---- intents (same "intent" discriminator)

/** A new entry at [at] holding [pattern] (a kept 1…64, or 65 a REST); the entries from there move on. */
@Serializable @SerialName("blockInsert") data class BlockInsert(val track: Int, val at: Int, val pattern: Int) : Intent
/** A new empty pattern after the track's last entry. */
@Serializable @SerialName("blockNew") data class BlockNew(val track: Int) : Intent
/** The block one place earlier (−1) or later (+1) among the track's blocks. */
@Serializable @SerialName("blockMove") data class BlockMove(val track: Int, val block: Int, val by: Int) : Intent
/** Stretch: its REPS (1…16). */
@Serializable @SerialName("blockStretch") data class BlockStretch(val track: Int, val block: Int, val reps: Int) : Intent
/** Out of the list. When a pattern used nowhere else would be erased, only [confirmed] (confirm in place). */
@Serializable @SerialName("blockDelete") data class BlockDelete(val track: Int, val block: Int, val confirmed: Boolean = false) : Intent
@Serializable @SerialName("blockSetPattern") data class BlockSetPattern(val track: Int, val block: Int, val pattern: Int, val confirmed: Boolean = false) : Intent
@Serializable @SerialName("blockDuplicate") data class BlockDuplicate(val track: Int, val block: Int) : Intent
@Serializable @SerialName("blockChain") data class BlockChain(val track: Int, val block: Int) : Intent
@Serializable @SerialName("blockSplit") data class BlockSplit(val track: Int, val block: Int) : Intent

@Serializable @SerialName("automationLane") data class AutomationLanePick(val lane: String) : Intent
/** Draw [values] (raw, one a step) from step [from] on lane [param]; [lock] draws locks. Over recorded changes only
 *  [confirmed] (decision 16: the screen asks first, in place). */
@Serializable @SerialName("drawLane") data class DrawLane(val param: String, val from: Int, val values: List<Int>, val lock: Boolean = false, val confirmed: Boolean = false) : Intent
/** The lane's records gone (recorded and locks): only [confirmed]. */
@Serializable @SerialName("clearLane") data class ClearLane(val param: String, val confirmed: Boolean = false) : Intent
