package com.scottgerstl.lupe.ui.mix

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.MixSectionPick
import com.scottgerstl.lupe.core.MixState
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.core.SetLevel
import com.scottgerstl.lupe.core.SetMixParam
import com.scottgerstl.lupe.core.SetPan
import com.scottgerstl.lupe.core.SetReverb

/** One track's strip on the mixer (board 64). Levels and the send are the FM-1's raw values; the words are as the FM-1 shows them. */
data class MixTrackUi(
    val number: Int,
    val name: String,
    val level: Int,
    val levelText: String,
    /** 0..127 with 64 the centre (the core's −64…63, shifted so a slide has no negative range). */
    val pan: Int,
    val panText: String,
    val send: Int,
    val sendText: String,
    val muted: Boolean = false,
    /** Lupe's solo (the iPad's, through PERFORM's mutes). */
    val solo: Boolean = false,
    /** 0..1 level meter, or null when the core has none to show (no meter is drawn). */
    val meter: Float? = null,
    val selected: Boolean = false,
)

/** GLO's five pages, one at a time: Mixer, then the shared buses. */
data class MixUi(
    val pages: List<String> = listOf("Mixer", "Delay", "Reverb", "Chorus", "Global"),
    val page: Int = 0,
    val tracks: List<MixTrackUi> = emptyList(),
    /** The four controls of a bus page (knob order); null is an empty well. Shared by every track. */
    val bus: List<PageControl?> = emptyList(),
    /** The bus card's settings (DELAY MODE on 2.5.1): a choice from a list, shown under the four controls. */
    val settings: List<PageControl> = emptyList(),
)

class MixActions(
    val page: (Int) -> Unit,
    val level: (track: Int, raw: Int) -> Unit,
    val pan: (track: Int, raw: Int) -> Unit,
    val send: (track: Int, raw: Int) -> Unit,
    val mute: (track: Int) -> Unit,
    val select: (track: Int) -> Unit,
    val setBus: (slot: Int, raw: Int) -> Unit,
    val setSetting: (index: Int, raw: Int) -> Unit,
    val solo: (track: Int) -> Unit,
)

fun MixState.toUi(): MixUi {
    val titles = sections.map { it.title }.ifEmpty { listOf("Mixer", "Delay", "Reverb", "Chorus", "Global") }
    val keys = sections.map { it.key }.ifEmpty { listOf("mixer", "delay", "reverb", "chorus", "global") }
    return MixUi(
        pages = titles, page = keys.indexOf(section).coerceAtLeast(0),
        // the core names a track "Engine · Sound" ("Analog · Acid"); the row has room for the sound's name
        tracks = rows.map { MixTrackUi(it.track, it.name.substringAfter(" · "), it.level, it.levelText, it.pan + 64, it.panText, it.reverb ?: 0, it.reverbText ?: "…", it.mute, it.solo, null, it.selected) },
        bus = card?.controls.orEmpty(), settings = card?.settings.orEmpty(),
    )
}

/** The Mix tab's state from the core, and what it does about a touch. The pan is shifted back to the core's −64…63. */
@Composable
fun rememberMix(core: LupeCore): Pair<MixUi, MixActions> {
    val state by core.mix.collectAsStateWithLifecycle()
    val ui = remember(state) { state.toUi() }
    val keys = remember(state.sections) { state.sections.map { it.key }.ifEmpty { listOf("mixer", "delay", "reverb", "chorus", "global") } }
    val actions = remember(core, keys) {
        MixActions(
            page = { core.send(MixSectionPick(keys.getOrElse(it) { "mixer" })) },
            level = { t, v -> core.send(SetLevel(t, v)) },
            pan = { t, v -> core.send(SetPan(t, v - 64)) },
            send = { t, v -> core.send(SetReverb(t, v)) },
            mute = { core.send(Intent.TrackMute(it)) },
            select = { core.send(Intent.TrackSelect(it)) },
            setBus = { s, v -> core.send(SetMixParam(s, v)) },
            setSetting = { i, v -> core.send(com.scottgerstl.lupe.core.SetMixSetting(i, v)) },
            solo = { core.send(com.scottgerstl.lupe.core.TrackSolo(it)) },
        )
    }
    return ui to actions
}
