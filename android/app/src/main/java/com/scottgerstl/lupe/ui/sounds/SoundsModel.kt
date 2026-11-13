package com.scottgerstl.lupe.ui.sounds

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/** An engine and its presets ("ANALOG": Acid, Pad …), as the FM-1 lists them. [readOnly]: Samples (USR1–3) can't be changed from the phone. */
data class EngineUi(val name: String, val presets: List<String>, val readOnly: Boolean = false)

/** What the Sounds browser shows for the track being browsed (board 66). */
data class SoundsUi(
    val track: Int,
    val trackName: String,
    /** The engines in the FM-1's order, then User (its 32 slots) and Samples. */
    val engines: List<EngineUi>,
    /** Where the track is now: engine and preset, ticked in the list. */
    val engine: Int = 0,
    val preset: Int = 0,
    /** Drum tracks: the kits, one per track; a pad's own sound overrides one pad of it (decision 15). Empty for other tracks. */
    val kits: List<String> = emptyList(),
    val kit: Int = 0,
    /** The pad being given its own sound (its entry's letter), if the browser was opened from a pad's menu. */
    val pad: String? = null,
    /** Pads of this drum track that carry their own sound: the names, for the mark. */
    val padSounds: Map<String, String> = emptyMap(),
)

class SoundsActions(
    val pickEngine: (Int) -> Unit,
    val pickPreset: (engine: Int, preset: Int) -> Unit,
    val pickKit: (Int) -> Unit,
    val setPadSound: (pad: String, engine: Int, preset: Int) -> Unit,
    val clearPadSound: (pad: String) -> Unit,
)

/** The browser is open for [track], and, from a drum pad's menu, for that pad's own sound. */
data class SoundsRequest(val track: Int, val pad: String? = null)

/**
 * STAND-IN until P1's `sounds` area lands (board 66's engines). The browser only knows [SoundsUi] and [SoundsActions].
 */
@Stable
class MockSounds {
    private val engines = listOf(
        EngineUi("ANALOG", listOf("ACID", "BASS", "LEAD", "PAD", "PLUCK", "STAB")),
        EngineUi("DIGITAL", listOf("BELL", "GLASS", "ORGAN", "EP", "CHOIR")),
        EngineUi("PHASE", listOf("SWEEP", "WARBLE", "SHIMMER", "DRONE")),
        EngineUi("LOFI", listOf("TAPE", "DUST", "CRUSH", "HAZE")),
        EngineUi("SAMPLE", listOf("PIANO", "PIANO 2", "FLUTE", "SAX", "E PIANO", "LOFI PIANO", "MUSIC BOX", "FLUTE PAD", "DARK SAX", "KOTO")),
        EngineUi("VOICE", listOf("AAH", "OOH", "CHOIR", "VOX")),
        EngineUi("TRIO", listOf("TRIAD", "SEVENTH", "OPEN")),
        EngineUi("WHEEL", listOf("SPIN", "CLICK", "MOTOR")),
        EngineUi("GRAIN", listOf("CLOUD", "MIST", "SAND")),
        EngineUi("USER", List(32) { i -> if (i < 5) "USER ${i + 1}" else "(empty)" }),
        EngineUi("SAMPLES", listOf("USR1", "USR2", "USR3"), readOnly = true),
    )
    var request by mutableStateOf<SoundsRequest?>(null)
    private var states by mutableStateOf(mapOf(5 to (4 to 0), 4 to (0 to 0)))
    private var kit by mutableStateOf(0)
    private var padSounds by mutableStateOf(mapOf<String, String>())
    private var browsing by mutableStateOf(-1)

    fun ui(track: Int, name: String, pad: String?): SoundsUi {
        val s = states[track] ?: (0 to 0)
        return SoundsUi(track, name, engines, browsing.takeIf { it in engines.indices } ?: s.first, s.second,
            kits = if (track == 4) listOf("808 KIT", "909 KIT", "ACOUSTIC", "LOFI KIT") else emptyList(), kit = kit, pad = pad, padSounds = padSounds)
    }

    fun actions(track: Int) = SoundsActions(
        pickEngine = { browsing = it },
        pickPreset = { e, p -> states = states + (track to (e to p)) },
        pickKit = { kit = it },
        setPadSound = { pad, e, p -> padSounds = padSounds + (pad to "${engines[e].name} ${engines[e].presets[p]}") },
        clearPadSound = { pad -> padSounds = padSounds - pad },
    )
}

@Composable
fun rememberMockSounds() = remember { MockSounds() }

/** Which track (and pad) the Sounds browser is open for; the Pads' hold menu, a track number held, and a Mix row set it. */
@Stable
class SoundsHost {
    var request by mutableStateOf<SoundsRequest?>(null)
    fun open(track: Int, pad: String? = null) { request = SoundsRequest(track, pad) }
    fun close() { request = null }
}

val LocalSoundsHost = androidx.compose.runtime.staticCompositionLocalOf { SoundsHost() }
