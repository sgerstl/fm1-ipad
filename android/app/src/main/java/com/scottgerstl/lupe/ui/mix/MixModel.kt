package com.scottgerstl.lupe.ui.mix

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.scottgerstl.lupe.core.PageControl

/** One track's strip on the mixer (board 64). Levels and pan are the FM-1's raw 0..127; the words are as the FM-1 shows them. */
data class MixTrackUi(
    val number: Int,
    val name: String,
    val level: Int,
    val levelText: String,
    /** 0..127, 64 is centre. */
    val pan: Int,
    val panText: String,
    val send: Int,
    val sendText: String,
    val muted: Boolean = false,
    /** 0..1, how loud the track is playing right now (the FM-1's meters), or 0. */
    val meter: Float = 0f,
    val selected: Boolean = false,
)

/** GLO's five pages, one at a time: Mixer, then the shared buses. */
data class MixUi(
    val pages: List<String> = listOf("Mixer", "Delay", "Reverb", "Chorus", "Global"),
    val page: Int = 0,
    val tracks: List<MixTrackUi> = emptyList(),
    /** The four controls of a bus page (knob order); null is an empty well. Shared by every track. */
    val bus: List<PageControl?> = emptyList(),
)

class MixActions(
    val page: (Int) -> Unit,
    val level: (track: Int, raw: Int) -> Unit,
    val pan: (track: Int, raw: Int) -> Unit,
    val send: (track: Int, raw: Int) -> Unit,
    val mute: (track: Int) -> Unit,
    val select: (track: Int) -> Unit,
    val setBus: (slot: Int, raw: Int) -> Unit,
    val openSounds: (track: Int) -> Unit,
)

private fun dbText(raw: Int): String = if (raw <= 0) "−∞ dB" else "%.1f dB".format((raw - 100) * 0.3).replace('-', '−')
private fun panText(raw: Int): String = when { raw == 64 -> "C"; raw < 64 -> "L${64 - raw}"; else -> "R${raw - 64}" }

/**
 * STAND-IN until P1's `mix` area lands (board 64's numbers), answering the mixer's actions locally. The screens only
 * know [MixUi] and [MixActions], so the core's state replaces this and nothing above changes.
 */
@Stable
class MockMix {
    private fun track(n: Int, name: String, level: Int, pan: Int, send: Int, muted: Boolean = false) =
        MixTrackUi(n, name, level, dbText(level), pan, panText(pan), send, "$send", muted, meter = (level / 160f))

    var ui by mutableStateOf(
        MixUi(
            tracks = listOf(
                track(1, "Acid", 99, 64, 20), track(2, "Pad", 80, 52, 45), track(3, "Pulse Ld", 87, 72, 10),
                track(4, "Drum Kit", 107, 64, 0), track(5, "Piano", 72, 84, 35).copy(selected = true), track(6, "Perc Kit", 83, 58, 15, muted = true),
            ),
            bus = listOf(
                PageControl("TIME", "3/16", 40, 0, 127, list = true), PageControl("FEEDBACK", "62", 62), PageControl("COLOR", "70", 70), PageControl("MIX", "30", 30),
            ),
        ),
    )
        private set

    private fun edit(t: Int, f: (MixTrackUi) -> MixTrackUi) { ui = ui.copy(tracks = ui.tracks.map { if (it.number == t) f(it) else it }) }

    val actions = MixActions(
        page = { ui = ui.copy(page = it) },
        level = { t, v -> edit(t) { it.copy(level = v, levelText = dbText(v), meter = v / 160f) } },
        pan = { t, v -> edit(t) { it.copy(pan = v, panText = panText(v)) } },
        send = { t, v -> edit(t) { it.copy(send = v, sendText = "$v") } },
        mute = { t -> edit(t) { it.copy(muted = !it.muted) } },
        select = { t -> ui = ui.copy(tracks = ui.tracks.map { it.copy(selected = it.number == t) }) },
        setBus = { s, v -> ui = ui.copy(bus = ui.bus.mapIndexed { i, c -> if (i == s && c != null) c.copy(raw = v, value = if (c.list) c.value else "$v") else c }) },
        openSounds = { },
    )
}

@Composable
fun rememberMock() = remember { MockMix() }
