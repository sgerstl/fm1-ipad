package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The `page` ViewState area (P4): what the bottom half shows while the FM-1 is on a sound page (ENV, LFO, FX, SEL,
// EDIT, ARP). PROVISIONAL, like everything in android/fixtures/state/page-*.json: hand-written to design/phone-sound-pages.md
// and BRIDGE.md §2 until P1's PhoneCore records real ones. Kept out of State.kt so P3's edits there don't collide;
// the intents at the bottom extend the sealed [Intent] from here (Kotlin allows that within a package).
//
// Who decides what: the core (Swift: SkiffPages, DeviceDisplay) names the pages the FM-1 has for this track, finds each
// knob's label and formats each value as the FM-1 shows it. Compose draws, and decides only look and feel (the ring,
// the lit state, the haptics, the graph pictures from the values it is given).

/** The six family keys of the bottom half's top row, in the FM-1's order. GLO and SEQ are not here (map: "What stays the same"). */
val PageFamilies = listOf("ENV", "LFO", "FX", "SEL", "EDIT", "ARP")

/** One key of the page row: [index] is the FM-1's page number (the screen link's), [title] its name on the FM-1. */
@Serializable
data class PageRef(val index: Int, val title: String)

/**
 * One of the four controls, in the FM-1's knob order. A knob with no parameter on this page (the FM-1's 0xFF) is
 * `null` in [PageState.controls], an empty well, so knob 3 here is always knob 3 on the FM-1.
 */
@Serializable
data class PageControl(
    val label: String,
    /** The value as the FM-1 shows it: "72", "-3", "710 Hz", "SAW", "1/16T". */
    val value: String,
    val raw: Int = 0,
    val min: Int = 0,
    val max: Int = 127,
    /** The value is a name from a list (a wave, a division): each step gets a haptic tick, and the value may shrink to fit. */
    val list: Boolean = false,
    /** A picker's knob 1 (MOD's ROUTE, LANES' LANE): no ring, it isn't a value. The tiles above send it. */
    val ringless: Boolean = false,
    /** Shown but not editable here (MOD's fixed route: SRC and DEST). Drawn in text2. */
    val fixed: Boolean = false,
    /** This step carries a lock for it while a step is held: ◆ beside the label. */
    val locked: Boolean = false,
    /**
     * The names a list control steps through, indexed by [raw] (the FM-1's DESC names; empty for a number), so
     * [FakeLupeCore] can rename on SetParam. The real core sends them too, taken from the parameter's DESC.
     */
    val names: List<String> = emptyList(),
)

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

@Serializable
data class PageTile(val label: String)

/** One of MOD's eleven routes: [group] "LFO", "ENV" or "SLOTS"; [amount] 0…127 as the small bar; [empty] a matrix slot with nothing set. */
@Serializable
data class PageRoute(val group: String, val label: String, val amount: Int = 0, val empty: Boolean = false)

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
    val routes: List<PageRoute> = emptyList(),
    val tiles: List<PageTile> = emptyList(),
    val picked: Int = 0,
    val title: String? = null,
    val fm6: Fm6Patch? = null,
    val sheet: SoundSheet? = null,
)

/**
 * The banner that stands in for the page row while a step is held ("Locking to step 6", board 61), or says why it
 * can't ("Not lockable": SAMPLES and GLO's pages are SC_GLOBAL), or "Keys: SCALE" while SCL is held on the FM-1.
 */
@Serializable
data class PageLock(
    val text: String,
    val note: String? = null,
    /** A real lock (the ◆ in front, in the track's colour) rather than a notice. */
    val locking: Boolean = true,
)

@Serializable
data class PageState(
    val family: String = "ENV",
    /** The family's pages the selected track has, in the FM-1's order. */
    val pages: List<PageRef> = emptyList(),
    /** [PageRef.index] of the page showing. */
    val page: Int = 0,
    /** The selected track, 1…6, and its name ("Piano"): the track line. */
    val track: Int = 1,
    val trackName: String = "",
    /** Always four. */
    val controls: List<PageControl?> = List(4) { null },
    val graph: PageGraph = PageGraph(),
    /** The control (0…3) the FM-1's knob last turned, and a counter that grows with every turn: Compose lights it and fades it 600 ms after the last. */
    val turned: Int = -1,
    val turnSeq: Int = 0,
    val lock: PageLock? = null,
)

// ---- intents (P4). Same JSON discriminator ("intent") as Intent.kt.

/** Turn one of the four controls to [value] (its raw number; a list's index). [slot] 0…3 is the FM-1's knob order. A graph handle sends this too. */
@Serializable @SerialName("setParam")
data class SetParam(val slot: Int, val value: Int) : Intent

/** Send the FM-1 to a page (SCREEN_GOTO). [page] null: the family's first. */
@Serializable @SerialName("pickPage")
data class PickPage(val family: String, val page: Int? = null) : Intent

/** MOD: pick one of the eleven routes (turns knob 1). */
@Serializable @SerialName("pickRoute")
data class PickRoute(val route: Int) : Intent

/** LANES, LANE MIX, SOUND, SAMPLES: pick a tile (turns knob 1). */
@Serializable @SerialName("pickTile")
data class PickTile(val tile: Int) : Intent

/** Back to the pattern (decision 19: Android's back gesture, no visible key): SCREEN_GOTO 127, a HOME tap on the FM-1.
 *  JSON `{"intent":"goHome"}`. A write: refused while read-only. The shell's bottom returns to the editor. */
/**
 * The block's GLO, SAVE and SEQ: send the FM-1 to that screen (SCREEN_GOTO; the phone opens its own place for it as well: the Mix tab, the
 * Projects sheet, the editor). [screen] is "GLO", "SAVE" or "SEQ"; [page] (optional) is one of that key's pages in Lupe's numbers for a second press of a lit key (GLO 30-34, SAVE 35-38, SEQ 41-45). P1 fixed the shape. A write.
 */
@Serializable @SerialName("screenGoto")
data class ScreenGoto(val screen: String, val page: Int? = null) : Intent

@Serializable @SerialName("goHome")
data object GoHome : Intent
