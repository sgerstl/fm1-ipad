package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The ViewState areas P2 draws (android/BRIDGE.md §2). PROVISIONAL: hand-written to the contract until P1's
// PhoneCore writes recordings into android/fixtures/state/. When P1's State.swift lands, these are checked
// against it (a renamed field fails a build, not a screen) and replaced if they differ.

// ---- link (P1)

@Serializable
enum class LinkPhase {
    @SerialName("searching") Searching,
    @SerialName("connecting") Connecting,
    @SerialName("reading") Reading,
    @SerialName("ready") Ready,
    @SerialName("lost") Lost,
    @SerialName("wrongFirmware") WrongFirmware,
}

/** [reason] says why it was lost ("unplugged", "silent"); [firmware] is what a wrong-firmware FM-1 reported. */
@Serializable
data class LinkState(
    val phase: LinkPhase = LinkPhase.Searching,
    val reason: String? = null,
    val firmware: String? = null,
)

// ---- top (P2)

@Serializable
enum class PlaybackMode {
    @SerialName("loop") Loop,
    @SerialName("song") Song,
    @SerialName("once") Once,
}

@Serializable
enum class LaunchQuantize {
    @SerialName("loop") Loop,
    @SerialName("bar") Bar,
    @SerialName("beat") Beat,
    @SerialName("now") Now,
}

@Serializable
data class TopState(
    /** The FM-1 key's label: the project's name. */
    val project: String = "",
    val playing: Boolean = false,
    val rec: Boolean = false,
    val tempo: Double = 120.0,
    val mode: PlaybackMode = PlaybackMode.Loop,
    val launch: LaunchQuantize = LaunchQuantize.Bar,
    /** How many launches wait for the quantize point. */
    val waiting: Int = 0,
    /** The readout's position, 1-based: "10·3". */
    val bar: Int = 1,
    val beat: Int = 1,
)

// ---- shell (P2)

@Serializable
enum class Tab {
    @SerialName("pads") Pads,
    @SerialName("timeline") Timeline,
    @SerialName("mix") Mix,
}

@Serializable
enum class Divider {
    @SerialName("top") Top,
    @SerialName("split") Split,
    @SerialName("bottom") Bottom,
}

@Serializable
enum class BottomKind {
    /** SEQ: the step editor (P3). */
    @SerialName("editor") Editor,
    /** A sound page: ENV, LFO, FX, SEL, EDIT, ARP (P4). */
    @SerialName("page") Page,
    /** The FM-1's FREE TAKE picker is open: it takes the editor's place. */
    @SerialName("freetake") FreeTake,
}

/** Which page the FM-1's screen shows; the bottom half follows it. [family] and [page] are only set for [BottomKind.Page]. */
@Serializable
data class BottomPage(
    val kind: BottomKind = BottomKind.Editor,
    val family: String? = null,
    val page: String? = null,
)

/** What Swift's `shell` area carries: the bottom half only (tab and divider are Kotlin's). */
@Serializable
data class ShellBottom(val bottom: BottomPage)

@Serializable
data class ShellState(
    val tab: Tab = Tab.Pads,
    val divider: Divider = Divider.Split,
    val bottom: BottomPage = BottomPage(),
)

// ---- pads (P3). PROVISIONAL, as the areas above: hand-written to BRIDGE.md §2 until P1's PhoneCore records them.

@Serializable
enum class PadKind {
    @SerialName("empty") Empty,
    @SerialName("pattern") Pattern,
    @SerialName("rest") Rest,
}

@Serializable
enum class PadPlay {
    @SerialName("idle") Idle,
    @SerialName("playing") Playing,
    /** A launch is queued for [PadEntry.bar]. */
    @SerialName("waiting") Waiting,
    /** The song's next entry (SONG ON, ONCE): comes in by itself. */
    @SerialName("next") Next,
}

@Serializable
data class PadEntry(
    val kind: PadKind = PadKind.Empty,
    /** The pattern's number, for [PadKind.Pattern]. */
    val pattern: Int? = null,
    val play: PadPlay = PadPlay.Idle,
    /** Where a waiting launch lands, 1-based ("bar 11"). */
    val bar: Int? = null,
    /** Passes of the entry (×4) and the one playing (2 of 4); null when REPS is 1. */
    val passes: Int? = null,
    val pass: Int? = null,
    /** 0..1 through the pass, from Lupe's own clock count; null when not known (no bar is drawn). */
    val progress: Float? = null,
    /** The entry carries a sound (the iPad cuts the pad's top right corner). */
    val hasSound: Boolean = false,
)

@Serializable
data class PadRow(
    /** 1-based track number. */
    val track: Int,
    /** The track's sound name ("Acid", "Drum Kit"). */
    val name: String,
    val muted: Boolean = false,
    /** One per column: entries A… up to the last any track uses, plus one empty. */
    val entries: List<PadEntry> = emptyList(),
)

@Serializable
data class Scene(val stored: Boolean = false, val current: Boolean = false)

/** [entry] is 0-based (A = 0). */
@Serializable
data class PadRef(val track: Int = 1, val entry: Int = 0)

@Serializable
data class PadsState(
    val rows: List<PadRow> = emptyList(),
    /** Sixteen. */
    val scenes: List<Scene> = emptyList(),
    /** The pad the editor shows. */
    val selected: PadRef = PadRef(),
    /** The pattern numbers (1…64) the FM-1 holds: the only ones Set pattern can name (LIST SET refuses an empty one).
     *  P1, 2026-11-14 (Scott's run: Set to 60 refused). */
    val kept: List<Int> = emptyList(),
)

// ---- editor (P3)

@Serializable
enum class EditorKind {
    /** Melodic: a note (and up to four chord notes) per step. */
    @SerialName("roll") Roll,
    /** Drum kit: lanes; a step is the lanes that hit. */
    @SerialName("drum") Drum,
}

/** A value on a step. [locked] true: a lock on this step (◆); false: recorded automation the step passes through (—). */
@Serializable
data class StepValue(val param: String, val value: Int, val locked: Boolean = true)

@Serializable
data class Step(
    val on: Boolean = false,
    /** What the cell shows: "C4", "D#4", or lane names for a drum step ("BD SD"). Empty when off. */
    val note: String = "",
    /** Chord notes beyond the first: the "+2". */
    val extra: Int = 0,
    /** In steps. */
    val length: Int = 1,
    val velocity: Int = 100,
    val chance: Int = 100,
    val ratchet: Int = 1,
    val cond: String = "ALWAYS",
    val nudge: Int = 0,
    /** Shown in the step panel's NOTES tab as the value under PITCH (a chord reads "C5 D#5"). */
    val pitchText: String = "",
    val values: List<StepValue> = emptyList(),
    /** How long LENGTH can make it: up to the next step with a note, at most 16 (P1, 2026-11-14). */
    val maxLength: Int = 16,
    /** A TIE step: the step (0-based) whose note it holds, else -1. Pasting into it or clearing it shortens that note,
     *  which the paste and clear confirms should say (Scott's run, 2026-11-14). */
    val heldFrom: Int = -1,
) {
    val locked: Boolean get() = values.any { it.locked }
}

@Serializable
enum class LockMode {
    @SerialName("off") Off,
    /** A step is held down: knob turns lock to it until let go. */
    @SerialName("held") Held,
    /** The step panel's Lock key latched it. */
    @SerialName("latched") Latched,
}

@Serializable
data class EditorState(
    val track: Int = 1,
    val trackName: String = "",
    /** "B": the entry the pattern sits in. */
    val entry: String = "A",
    val pattern: Int = 0,
    /** "C min", or "" for a drum kit. */
    val scale: String = "",
    val kind: EditorKind = EditorKind.Roll,
    /** Sixteen. */
    val steps: List<Step> = emptyList(),
    val selected: Int = 0,
    /** -1 when stopped. */
    val playhead: Int = -1,
    val chord: Boolean = false,
    val lock: LockMode = LockMode.Off,
    /** Automation: the lanes this track has, the one shown, and its values (0..100) per step. */
    val lanes: List<String> = emptyList(),
    val lane: String = "",
    val laneValues: List<Int> = emptyList(),
)
