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
 * shell, the pads and the editor to be driven by hand on the phone (the real core answers from the FM-1; this
 * answers from itself, and from FakeData's patterns). [scenarios] maps a name ("ready", "searching", "lost",
 * "wrongFirmware", "drums") to its parsed file.
 */
class FakeLupeCore(
    private val scope: CoroutineScope,
    private val scenarios: Map<String, Scenario>,
    initial: String = "ready",
) : LupeCore {
    private val _link = MutableStateFlow(LinkState())
    private val _top = MutableStateFlow(TopState())
    private val _shell = MutableStateFlow(ShellState())
    private val _pads = MutableStateFlow(PadsState())
    private val _editor = MutableStateFlow(EditorState())
    override val link: StateFlow<LinkState> = _link
    override val top: StateFlow<TopState> = _top
    override val shell: StateFlow<ShellState> = _shell
    override val pads: StateFlow<PadsState> = _pads
    override val editor: StateFlow<EditorState> = _editor

    private var replay: Job? = null
    private var ticker: Job? = null

    // the editor's working pattern, kept per (track, pattern) so edits stay when you come back
    private val patterns = mutableMapOf<Pair<Int, Int>, MutableList<FStep>>()
    private var model: MutableList<FStep> = MutableList(16) { FStep() }
    private var clipboard: FStep? = null
    private val sceneSnaps = mutableMapOf<Int, List<Int?>>()
    private var stepCount = 0
    private var startBar = 1

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

    /** The FM-1's key pressed: the note goes into the selected step (a chord adds, up to four), then the cursor moves on. */
    fun fm1Key(midi: Int) {
        val ed = _editor.value
        val st = model[ed.selected]
        if (ed.kind == EditorKind.Drum) {
            val lane = (midi % 6)
            st.on = true; st.lanes.add(lane)
        } else if (ed.chord && st.on) {
            if (st.extra < 3) st.extra++
        } else { st.on = true; st.midi = midi; st.extra = 0 }
        emitEditor { it.copy(selected = if (ed.chord) it.selected else (it.selected + 1) % 16) }
    }

    /** One of the FM-1's four knobs turned: with a step held (or Lock latched), the value locks to that step. */
    fun fm1Knob(knob: Int, delta: Int) {
        val ed = _editor.value
        if (ed.lock == LockMode.Off) return
        val params = if (ed.kind == EditorKind.Drum) FakeData.drumAutoLanes else FakeData.rollLanes
        val p = params.getOrNull(knob - 1) ?: return
        val st = model[ed.selected]
        val old = st.values.firstOrNull { it.param == p && it.locked }?.value ?: FakeData.baseValue(p)
        st.values.removeAll { it.param == p }
        st.values.add(StepValue(p, (old + delta * 4).coerceIn(0, 127), true))
        emitEditor()
    }

    private fun apply(area: String, state: JsonElement) {
        when (area) {
            "link" -> _link.value = lupeJson.decodeFromJsonElement(LinkState.serializer(), state)
            "top" -> _top.value = lupeJson.decodeFromJsonElement(TopState.serializer(), state).also { syncTicker(it.playing) }
            "shell" -> _shell.value = lupeJson.decodeFromJsonElement(ShellState.serializer(), state)
            "pads" -> _pads.value = lupeJson.decodeFromJsonElement(PadsState.serializer(), state)
            "editor" -> {
                val e = lupeJson.decodeFromJsonElement(EditorState.serializer(), state)
                model = e.steps.map { FStep.from(it, e.kind == EditorKind.Drum) }.toMutableList()
                patterns[e.track to e.pattern] = model
                _editor.value = e
            }
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
            Intent.CancelWaiting -> { _pads.update { p -> p.copy(rows = p.rows.map { r -> r.copy(entries = r.entries.map { if (it.play == PadPlay.Waiting) it.copy(play = PadPlay.Idle, bar = null) else it }) }) }; recount() }
            is Intent.SetTab -> _shell.update { it.copy(tab = intent.tab) }
            is Intent.SetDivider -> _shell.update { it.copy(divider = intent.position) }
            is Intent.SetPlaybackMode -> _top.update { it.copy(mode = intent.mode) }
            is Intent.PadTap -> launch(intent.track, intent.entry)
            is Intent.PadSelect -> selectPad(intent.track, intent.entry)
            is Intent.PadSelectSound -> { selectPad(intent.track, intent.entry); showBottom(BottomPage(BottomKind.Page, "SEL", "SOUNDS")) }
            is Intent.PadNew -> padNew(intent.track, intent.entry)
            is Intent.PadSet -> editEntry(intent.track, intent.entry) { it.copy(kind = PadKind.Pattern, pattern = intent.pattern) }
            is Intent.PadClear -> editEntry(intent.track, intent.entry) { PadEntry() }
            is Intent.TrackSelect -> {
                val row = _pads.value.rows.firstOrNull { it.track == intent.track } ?: return
                val at = row.entries.indexOfFirst { it.play == PadPlay.Playing }.takeIf { it >= 0 } ?: row.entries.indexOfFirst { it.kind == PadKind.Pattern }
                if (at >= 0) selectPad(intent.track, at)
            }
            is Intent.TrackMute -> _pads.update { p -> p.copy(rows = p.rows.map { if (it.track == intent.track) it.copy(muted = !it.muted) else it }) }
            is Intent.SceneRecall -> recall(intent.scene)
            is Intent.SceneStore -> store(intent.scene)
            is Intent.StepSelect -> emitEditor { it.copy(selected = intent.step.coerceIn(0, 15)) }
            is Intent.StepHold -> emitEditor {
                when {
                    intent.down -> it.copy(selected = intent.step, lock = LockMode.Held)
                    it.lock == LockMode.Held -> it.copy(lock = LockMode.Off)
                    else -> it
                }
            }
            is Intent.StepAdjust -> adjust(intent.field, intent.delta)
            Intent.ChordToggle -> emitEditor { it.copy(chord = !it.chord) }
            Intent.LockToggle -> emitEditor { it.copy(lock = if (it.lock == LockMode.Latched) LockMode.Off else LockMode.Latched) }
            is Intent.LockClear -> { model[intent.step].values.removeAll { it.param == intent.param && it.locked }; emitEditor() }
            is Intent.LocksClearAll -> { model[intent.step].values.removeAll { it.locked }; emitEditor() }
            is Intent.StepAction -> {
                val st = model[intent.step]
                when (intent.action) {
                    StepActionKind.Copy -> clipboard = st.copyOf()
                    StepActionKind.Paste -> clipboard?.let { model[intent.step] = it.copyOf() }
                    StepActionKind.Clear -> model[intent.step] = FStep()
                }
                emitEditor()
            }
            is Intent.LanePick -> emitEditor { it.copy(lane = intent.lane) }
        }
    }

    // ---- editor

    private fun emitEditor(change: (EditorState) -> EditorState = { it }) {
        val e = change(_editor.value)
        val drum = e.kind == EditorKind.Drum
        val lane = e.lane
        val lv = model.map { st -> ((st.values.firstOrNull { it.param == lane }?.value ?: (FakeData.baseValue(lane) + if (lane.isEmpty()) 0 else (model.indexOf(st) * 7) % 22 - 8)) * 100 / 127).coerceIn(0, 100) }
        _editor.value = e.copy(steps = model.map { it.toStep(drum) }, laneValues = lv)
    }

    private fun adjust(field: StepField, delta: Int) {
        val ed = _editor.value
        val st = model[ed.selected]
        val drum = ed.kind == EditorKind.Drum
        when (field) {
            StepField.Pitch -> if (drum) {
                st.on = true
                st.lanes = (if (st.lanes.isEmpty()) setOf(0) else st.lanes).map { Math.floorMod(it + delta, FakeData.drumLanes.size) }.toMutableSet()
            } else { st.on = true; st.midi = (st.midi + delta).coerceIn(24, 96) }
            StepField.Move -> {
                val to = Math.floorMod(ed.selected + delta, 16)
                val tmp = model[to]; model[to] = model[ed.selected]; model[ed.selected] = tmp
                emitEditor { it.copy(selected = to) }; return
            }
            StepField.Length -> st.length = (st.length + delta).coerceIn(1, 16)
            StepField.Velocity -> st.velocity = (st.velocity + delta * 4).coerceIn(1, 127)
            StepField.Chance -> st.chance = (st.chance + delta * 5).coerceIn(0, 100)
            StepField.Ratchet -> st.ratchet = (st.ratchet + delta).coerceIn(1, 4)
            StepField.Cond -> st.cond = FakeData.conds[Math.floorMod(FakeData.conds.indexOf(st.cond) + delta, FakeData.conds.size)]
            StepField.Nudge -> st.nudge = (st.nudge + delta).coerceIn(-12, 12)
        }
        emitEditor()
    }

    private fun selectPad(track: Int, entry: Int) {
        val row = _pads.value.rows.firstOrNull { it.track == track } ?: return
        val e = row.entries.getOrNull(entry) ?: return
        if (e.kind != PadKind.Pattern || e.pattern == null) return
        val drum = FakeData.isDrum(track)
        model = patterns.getOrPut(track to e.pattern) { FStep.generate(track, e.pattern) }
        val lanes = if (drum) FakeData.drumAutoLanes else FakeData.rollLanes
        _pads.update { it.copy(selected = PadRef(track, entry)) }
        _editor.value = EditorState(
            track = track, trackName = row.name, entry = ('A' + entry).toString(), pattern = e.pattern,
            scale = if (drum) "" else "C min", kind = if (drum) EditorKind.Drum else EditorKind.Roll,
            selected = 0, playhead = _editor.value.playhead, lanes = lanes, lane = lanes.first(),
        )
        emitEditor()
    }

    // ---- pads

    private fun editEntry(track: Int, entry: Int, f: (PadEntry) -> PadEntry) {
        _pads.update { p ->
            val rows = p.rows.map { r -> if (r.track != track) r else r.copy(entries = r.entries.mapIndexed { i, e -> if (i == entry) f(e) else e }) }
            // always somewhere to add: keep one empty column after the last used one
            val used = rows.maxOf { r -> r.entries.indexOfLast { it.kind != PadKind.Empty } }
            val want = maxOf(used + 2, 5)
            p.copy(rows = rows.map { r -> r.copy(entries = (r.entries + List(maxOf(0, want - r.entries.size)) { PadEntry() }).take(maxOf(want, r.entries.size))) })
        }
        recount()
    }

    private fun padNew(track: Int, entry: Int) {
        val next = (_pads.value.rows.flatMap { it.entries }.mapNotNull { it.pattern }.maxOrNull() ?: 0) + 1
        editEntry(track, entry) { PadEntry(PadKind.Pattern, next) }
    }

    private fun launch(track: Int, entry: Int) {
        val st = _top.value
        val row = _pads.value.rows.firstOrNull { it.track == track } ?: return
        val e = row.entries.getOrNull(entry) ?: return
        if (e.kind == PadKind.Empty) return
        when {
            e.play == PadPlay.Playing -> return // already playing: nothing to queue (the real core decides what a re-tap means)
            e.play == PadPlay.Waiting -> setEntryPlay(track, entry, PadPlay.Idle)
            !st.playing || st.launch == LaunchQuantize.Now || st.launch == LaunchQuantize.Beat -> makeCurrent(track, entry)
            else -> {
                _pads.update { p -> p.copy(rows = p.rows.map { r ->
                    if (r.track != track) r else r.copy(entries = r.entries.mapIndexed { i, x ->
                        if (i == entry) x.copy(play = PadPlay.Waiting, bar = st.bar + 1)
                        else if (x.play == PadPlay.Waiting) x.copy(play = PadPlay.Idle, bar = null) else x })
                }) }
            }
        }
        recount()
    }

    private fun setEntryPlay(track: Int, entry: Int, play: PadPlay) = _pads.update { p -> p.copy(rows = p.rows.map { r ->
        if (r.track != track) r else r.copy(entries = r.entries.mapIndexed { i, x -> if (i == entry) x.copy(play = play, bar = null) else x }) }) }

    private fun makeCurrent(track: Int, entry: Int) = _pads.update { p -> p.copy(rows = p.rows.map { r ->
        if (r.track != track) r else r.copy(entries = r.entries.mapIndexed { i, x ->
            if (i == entry) x.copy(play = PadPlay.Playing, bar = null, progress = null)
            else if (x.play != PadPlay.Idle) x.copy(play = PadPlay.Idle, bar = null, progress = null) else x }) }) }

    private fun recount() = _top.update { t -> t.copy(waiting = _pads.value.rows.sumOf { r -> r.entries.count { it.play == PadPlay.Waiting } }) }

    private fun store(n: Int) {
        sceneSnaps[n] = _pads.value.rows.map { r -> r.entries.indexOfFirst { it.play == PadPlay.Playing }.takeIf { it >= 0 } }
        _pads.update { p -> p.copy(scenes = p.scenes.mapIndexed { i, s -> if (i == n) s.copy(stored = true) else s }) }
    }

    private fun recall(n: Int) {
        val snap = sceneSnaps[n] ?: if (_pads.value.scenes.getOrNull(n)?.stored == true) _pads.value.rows.map { r -> r.entries.indexOfFirst { it.kind == PadKind.Pattern }.takeIf { it >= 0 } } else return
        snap.forEachIndexed { i, at -> if (at != null) launch(i + 1, at) }
        _pads.update { p -> p.copy(scenes = p.scenes.mapIndexed { i, s -> s.copy(current = i == n) }) }
    }

    // ---- the clock

    private fun setPlaying(on: Boolean) {
        _top.update { it.copy(playing = on, bar = if (on) it.bar else 1, beat = if (on) it.beat else 1) }
        if (!on) {
            _editor.update { it.copy(playhead = -1) }
            _pads.update { p -> p.copy(rows = p.rows.map { r -> r.copy(entries = r.entries.map { it.copy(progress = null) }) }) }
        }
        syncTicker(on)
    }

    // The readout, the playhead and the pads' pass bars move while playing, a sixteenth at a time at the current
    // tempo (the real core counts the FM-1's clock).
    private fun syncTicker(playing: Boolean) {
        ticker?.cancel()
        if (!playing) return
        stepCount = 0; startBar = _top.value.bar
        ticker = scope.launch {
            while (true) {
                delay((60_000.0 / _top.value.tempo / 4).toLong())
                stepCount++
                val bar = startBar + stepCount / 16
                val beat = (stepCount / 4) % 4 + 1
                val newBar = stepCount % 16 == 0
                _top.update { it.copy(bar = bar, beat = beat) }
                if (newBar) _pads.update { p -> p.copy(rows = p.rows.map { r ->
                    val landing = r.entries.indexOfFirst { it.play == PadPlay.Waiting && (it.bar ?: 0) <= bar }
                    if (landing < 0) r else r.copy(entries = r.entries.mapIndexed { i, x ->
                        if (i == landing) x.copy(play = PadPlay.Playing, bar = null) else if (x.play == PadPlay.Playing) x.copy(play = PadPlay.Idle) else x })
                }) }
                _pads.update { p -> p.copy(rows = p.rows.map { r -> r.copy(entries = r.entries.map {
                    if (it.play == PadPlay.Playing) it.copy(progress = (stepCount % 16) / 16f) else it }) }) }
                recount()
                _editor.update { it.copy(playhead = stepCount % 16) }
            }
        }
    }
}
