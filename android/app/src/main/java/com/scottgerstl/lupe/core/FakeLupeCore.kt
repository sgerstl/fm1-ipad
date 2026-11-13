package com.scottgerstl.lupe.core

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

val lupeJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    classDiscriminator = "intent"
}

/**
 * A scenario file in android/fixtures/state/: `{"provisional": true, "frames": [{"atMs": 0, "area": "top", "state": {…}}, …]}`.
 * Each frame is one `onState(area, json)` call, as PhoneCore will make it. PROVISIONAL until P1's recordings land.
 */
class Scenario(val name: String, val provisional: Boolean, val frames: List<Frame>) {
    class Frame(val atMs: Long, val area: String, val state: JsonElement)

    companion object {
        fun parse(name: String, text: String): Scenario {
            val root = lupeJson.parseToJsonElement(text).jsonObject
            val frames = (root["frames"] as JsonArray).map {
                val o = it as JsonObject
                Frame(o["atMs"]?.jsonPrimitive?.int?.toLong() ?: 0L, o["area"]!!.jsonPrimitive.content, o["state"]!!)
            }
            return Scenario(name, (root["provisional"]?.jsonPrimitive?.content == "true"), frames)
        }
    }
}

/**
 * Replays the fixture scenarios as the real core would emit them, and answers intents just enough for the
 * shell to be driven by hand on the phone (the real core answers from the FM-1; this answers from itself).
 * [scenarios] maps a name ("ready", "searching", "lost", "wrongFirmware") to its parsed file.
 */
class FakeLupeCore(
    private val scope: CoroutineScope,
    private val scenarios: Map<String, Scenario>,
    initial: String = "ready",
) : LupeCore {
    private val _link = MutableStateFlow(LinkState())
    private val _top = MutableStateFlow(TopState())
    private val _shell = MutableStateFlow(ShellState())
    override val link: StateFlow<LinkState> = _link
    override val top: StateFlow<TopState> = _top
    override val shell: StateFlow<ShellState> = _shell

    private var replay: Job? = null
    private var ticker: Job? = null

    val scenarioNames: List<String> get() = scenarios.keys.toList()

    init { play(initial) }

    /** Replays a scenario from its first frame. The fake's debug menu and the launch extra use this. */
    fun play(name: String) {
        val s = scenarios[name] ?: return
        replay?.cancel()
        replay = scope.launch {
            var last = 0L
            for (f in s.frames.sortedBy { it.atMs }) {
                delay(f.atMs - last); last = f.atMs
                apply(f.area, f.state)
            }
        }
    }

    /** Set the shell's bottom page as if the FM-1's button had been pressed (what the bottom half follows). */
    fun showBottom(page: BottomPage) = _shell.update { it.copy(bottom = page) }

    private fun apply(area: String, state: JsonElement) {
        when (area) {
            "link" -> _link.value = lupeJson.decodeFromJsonElement(LinkState.serializer(), state)
            "top" -> _top.value = lupeJson.decodeFromJsonElement(TopState.serializer(), state).also { syncTicker(it.playing) }
            "shell" -> _shell.value = lupeJson.decodeFromJsonElement(ShellState.serializer(), state)
        }
    }

    override fun send(intent: Intent) {
        when (intent) {
            Intent.Retry -> play("ready")
            Intent.Play -> setPlaying(true)
            Intent.Stop -> setPlaying(false)
            Intent.Rec -> _top.update { it.copy(rec = !it.rec) }
            is Intent.SetTempo -> _top.update { it.copy(tempo = intent.bpm.coerceIn(20.0, 300.0)) }
            is Intent.SetLaunch -> _top.update { it.copy(launch = intent.quantize) }
            Intent.CancelWaiting -> _top.update { it.copy(waiting = 0) }
            is Intent.SetTab -> _shell.update { it.copy(tab = intent.tab) }
            is Intent.SetDivider -> _shell.update { it.copy(divider = intent.position) }
            is Intent.SetPlaybackMode -> _top.update { it.copy(mode = intent.mode) }
        }
    }

    private fun setPlaying(on: Boolean) {
        _top.update { it.copy(playing = on, bar = if (on) it.bar else 1, beat = if (on) it.beat else 1) }
        syncTicker(on)
    }

    // The readout moves while playing, one beat at the current tempo (the real core gets this from the FM-1's clock).
    private fun syncTicker(playing: Boolean) {
        ticker?.cancel()
        if (!playing) return
        ticker = scope.launch {
            while (true) {
                delay((60_000.0 / _top.value.tempo).toLong())
                _top.update {
                    val beat = it.beat % 4 + 1
                    it.copy(beat = beat, bar = if (beat == 1) it.bar + 1 else it.bar,
                        waiting = if (beat == 1 && it.waiting > 0) it.waiting - 1 else it.waiting)
                }
            }
        }
    }
}
