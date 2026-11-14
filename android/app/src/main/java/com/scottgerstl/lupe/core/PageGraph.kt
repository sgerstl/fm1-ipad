package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The picture a sound page can show under its dials (decision 30: Settings › Show graphics). Restored from before decision 25 took the
// pictures out; the tiles (MOD's routes, the pickers) stay in PageState.tiles. PROVISIONAL until P1 sends the restored shape.

@Serializable
enum class GraphKind {
    @SerialName("none") None,
    @SerialName("env") Env,
    @SerialName("lfo") Lfo,
    @SerialName("drive") Drive,
    @SerialName("fx") Fx,
    @SerialName("scale") Scale,
    @SerialName("arp") Arp,
    @SerialName("analog") Analog,
    /** MOD's eleven routes. */
    @SerialName("mod") Mod,
    /** LANES, LANE MIX, SAMPLES: knob 1's choices as tiles. */
    @SerialName("tiles") Tiles,
    /** The named card with the FM-1's cursor: SLICES (its markers can't be read), and the dense pages until their data has been read. */
    @SerialName("card") Card,
    /** OPERATOR: operator tiles and the operators' envelopes ([PageGraph.fm6]). */
    @SerialName("fm6op") Fm6Op,
    /** ALL OPS: the algorithm chart and the voice's other settings ([PageGraph.fm6]). */
    @SerialName("fm6all") Fm6All,
    /** DRUM-X's SOUND: lane tiles and the kit sound's windows ([PageGraph.sheet]). */
    @SerialName("sound") Sound,
}

/** An FM6 patch as OPERATOR and ALL OPS draw it. [ops] are operators 1…6. */
@Serializable
data class Fm6Operator(val output: Int = 0, val ratio: String = "", val r: List<Int> = emptyList(), val l: List<Int> = emptyList())

@Serializable
data class Fm6Patch(
    /** 0…31 (ALGO 1…32), FEEDBACK 0…7. */
    val algorithm: Int = 0,
    val feedback: Int = 0,
    /** The operator the FM-1's page is on, 1…6, and the window it is in (the second cursor), if reported. */
    val picked: Int = 1,
    val lit: Int? = null,
    val ops: List<Fm6Operator> = emptyList(),
    val lines: List<String> = emptyList(),
)

@Serializable
data class SheetCell(val label: String, val value: String)

@Serializable
data class SheetRow(val title: String, val cells: List<SheetCell> = emptyList())

/** DRUM-X's SOUND: the picked lane and the windows of its sound, read-only. */
@Serializable
data class SoundSheet(
    val lane: Int = 0,
    val lanes: List<String> = emptyList(),
    val rows: List<SheetRow> = emptyList(),
    val lit: Int? = null,
    val note: String? = null,
)

/**
 * What a graph is drawn from. Which fields a kind reads (the rest stay empty):
 *  - Env: [values] = ATTACK, DECAY, SUSTAIN, RELEASE (0…127)
 *  - Lfo: [values] = RATE, WAVE, PHASE, FADE; [caption] the rate as shown ("2.40 Hz")
 *  - Drive: [values] = DIST, TYPE, TONE; [caption] the type's name; [side] "drive 72 · tone 40"
 *  - Fx: [values] = DIST, CHORUS, DELAY, REVERB sends
 *  - Scale: [root] 0…11, [notes] the scale's semitone offsets from the root; [side] "C minor · ● root"
 *  - Arp: [values] = MODE, RATE, OCTAVE, GATE, SWING, CHANCE, HOLD, ORDER; [side] "UP · 2 oct · 1/16 · gate 60%"
 *  - Analog: [values] = WAVE, DETUNE, MIX, NOISE, CUTOFF, RESO; [caption] "OSC · SAW · 2 voices", [side] "FILTER · 710 Hz"
 *  - Mod: [routes] and [picked] (0…10)
 *  - Tiles: [tiles] and [picked]
 *  - Card: [title] (the page and where the FM-1's cursor is)
 *  - Fm6Op, Fm6All: [fm6] and [picked]
 *  - Sound: [sheet]
 */
@Serializable
data class PageGraph(
    val kind: GraphKind = GraphKind.None,
    val values: List<Int> = emptyList(),
    val root: Int = 0,
    val notes: List<Int> = emptyList(),
    val caption: String? = null,
    val side: String? = null,
    val picked: Int = 0,
    val title: String? = null,
    val fm6: Fm6Patch? = null,
    val sheet: SoundSheet? = null,
)

