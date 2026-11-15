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
    private val _page = MutableStateFlow(PageState())
    private val pageFake = FakePages()
    override val link: StateFlow<LinkState> = _link
    override val top: StateFlow<TopState> = _top
    override val shell: StateFlow<ShellState> = _shell
    override val pads: StateFlow<PadsState> = _pads
    override val editor: StateFlow<EditorState> = _editor
    override val page: StateFlow<PageState> = _page
    private val _clock = MutableStateFlow(ClockState())
    override val clock: StateFlow<ClockState> = _clock
    private val _notice = MutableStateFlow(CoreNotice())
    override val notice: StateFlow<CoreNotice> = _notice
    // the pattern pool (board 79): 52 of 64 kept, twelve unused; "FM-1: all 64 patterns taken" in the fake menu fills it
    private var pool: List<PoolPattern> = FakePool.initial()
    private var poolFull = false
    /** The track as it was before a block was deleted, for ten seconds (batch item 13). */
    private val blockUndo = mutableMapOf<ClearedPad, TimelineTrack>()
    private val _patterns = MutableStateFlow(FakePool.state(pool, false))
    override val patterns: StateFlow<PatternsState> = _patterns
    private val _patternPictures = MutableStateFlow(FakePool.pictures(pool, false))
    override val patternPictures: StateFlow<PatternPictures> = _patternPictures
    /** Say the pool again: the lists, the counts, the pictures (waiting for a stop while playing), and the pads' own free count and unused list. */
    private fun publishPool() {
        val shown = if (poolFull) pool + (1..64).filter { n -> pool.none { it.number == n } }.map { PoolPattern(it, 16, 1, listOf(PatternUse(1, 6)), listOf(1), false, false) } else pool
        val playing = _top.value.playing
        val st = FakePool.state(shown, playing)
        _patterns.value = st; _patternPictures.value = FakePool.pictures(shown, playing)
        _pads.value = _pads.value.copy(patternsFree = if (st.free == 0) 0 else st.free, unused = shown.filter { it.unused }.map { it.number })
    }
    /** The FM-1 refusing something, as the real one does (its reason, for the screen). */
    fun refuse(reason: String) { _notice.value = CoreNotice(_notice.value.seq + 1, refusalWords(reason)) }
    /** For looking at the full-pool case: the fake says no pattern number is free, and refuses New pattern as Skiff does. */
    fun fillPool(full: Boolean) { poolFull = full; publishPool() }
    private val _fm1Screen = MutableStateFlow(Fm1ScreenState(key = "HOME"))
    override val fm1Screen: StateFlow<Fm1ScreenState> = _fm1Screen
    private val _home = MutableStateFlow(FakeHome.seed())
    override val homeKnobs: StateFlow<HomeKnobsState> = _home
    private val _mix = MutableStateFlow(MixState())
    private val _freeTake = MutableStateFlow(FreeTakeState())
    private val _firmware = MutableStateFlow(FirmwareState(running = "Skiff-Lupe 2.5.1", identity = "FELUCCA v2.5.1"))
    private val _playhead = MutableStateFlow(PlayheadState())
    private val _sounds = MutableStateFlow(SoundsState())
    private val _projects = MutableStateFlow(ProjectsState())
    private val _meters = MutableStateFlow(MetersState())
    override val meters: StateFlow<MetersState> = _meters
    private val _timeline = MutableStateFlow(TimelineState())
    private val _automation = MutableStateFlow(AutomationState())
    override val timeline: StateFlow<TimelineState> = _timeline
    override val automation: StateFlow<AutomationState> = _automation
    private var autoLane = ""
    override val mix: StateFlow<MixState> = _mix
    override val freeTake: StateFlow<FreeTakeState> = _freeTake
    override val firmware: StateFlow<FirmwareState> = _firmware
    override val playhead: StateFlow<PlayheadState> = _playhead
    override val sounds: StateFlow<SoundsState> = _sounds
    override val projects: StateFlow<ProjectsState> = _projects

    private var replay: Job? = null
    private var ticker: Job? = null

    // the editor's working pattern, kept per (track, pattern) so edits stay when you come back
    private val stepPatterns = mutableMapOf<Pair<Int, Int>, MutableList<FStep>>()
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
    fun showBottom(page: BottomPage) { _shell.update { it.copy(bottom = page) }; _fm1Screen.value = if (page.kind == BottomKind.Page) Fm1ScreenState(key = page.family.orEmpty(), title = page.family.orEmpty()) else Fm1ScreenState(key = "HOME") }

    /** The FM-1's knob [slot] (0…3) turned on a sound page: the phone lights that control (the screen link's job on the real core). */
    fun fm1PageKnob(slot: Int) = _page.update { pageFake.fm1Turn(it, slot) }

    /** The FM-1's HOME knob [slot] (0…3) turned by [delta]: the phone's knob follows and lights. */
    fun fm1HomeKnob(slot: Int, delta: Int) = _home.update { FakeHome.set(it, slot, (it.controls.getOrNull(slot)?.raw ?: 0) + delta).copy(hot = slot, hotSeq = it.hotSeq + 1) }

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

    /** Scenarios without recorded mix, sounds or projects get a seed from the pads' track names. */
    private fun seedP5() {
        val rows = _pads.value.rows
        if (_mix.value.rows.isEmpty() && rows.isNotEmpty()) _mix.value = FakeP5.seedMix(rows.map { it.name }, _pads.value.selected.track)
        if (_sounds.value.engines.isEmpty() && rows.isNotEmpty()) _sounds.value = FakeP5.seedSounds(_pads.value.selected.track, rows.getOrNull(_pads.value.selected.track - 1)?.name.orEmpty())
        if (_projects.value.slots.isEmpty()) _projects.value = FakeP5.seedProjects()
        if (_timeline.value.tracks.isEmpty() && rows.isNotEmpty()) _timeline.value = FakeP6.seedTimeline(_pads.value)
    }

    private fun apply(area: String, state: JsonElement) {
        when (area) {
            "link" -> _link.value = lupeJson.decodeFromJsonElement(LinkState.serializer(), state)
            "top" -> _top.value = lupeJson.decodeFromJsonElement(TopState.serializer(), state).also { syncTicker(it.playing) }
            "shell" -> _shell.value = lupeJson.decodeFromJsonElement(ShellState.serializer(), state)
            "homeKnobs" -> _home.value = lupeJson.decodeFromJsonElement(HomeKnobsState.serializer(), state)
            "clock" -> _clock.value = lupeJson.decodeFromJsonElement(ClockState.serializer(), state)
            "page" -> {
                val p0 = lupeJson.decodeFromJsonElement(PageState.serializer(), state)
                // a recording without the picture's data (P1 is restoring it): the fake draws one from the page's own values, so Show graphics can be tried
                val p = if (p0.graph.kind != GraphKind.None) p0 else p0.copy(graph = FakePageMap.graph(p0.pages.firstOrNull { it.index == p0.page }?.title.orEmpty(), p0.controls))
                pageFake.learn(p); _page.value = p
            }
            "freetake" -> _freeTake.value = lupeJson.decodeFromJsonElement(FreeTakeState.serializer(), state)
            "mix" -> _mix.value = lupeJson.decodeFromJsonElement(MixState.serializer(), state)
            "sounds" -> _sounds.value = lupeJson.decodeFromJsonElement(SoundsState.serializer(), state)
            "projects" -> _projects.value = lupeJson.decodeFromJsonElement(ProjectsState.serializer(), state)
            "timeline" -> _timeline.value = lupeJson.decodeFromJsonElement(TimelineState.serializer(), state)
            "automation" -> _automation.value = lupeJson.decodeFromJsonElement(AutomationState.serializer(), state)
            "pads" -> {
                _pads.value = lupeJson.decodeFromJsonElement(PadsState.serializer(), state)
                seedP5()
            }
            "editor" -> {
                val e = lupeJson.decodeFromJsonElement(EditorState.serializer(), state)
                model = e.steps.map { FStep.from(it, e.kind == EditorKind.Drum) }.toMutableList()
                stepPatterns[e.track to e.pattern] = model
                _editor.value = e
                emitEditor()   // the fake fills what the recording doesn't (maxLength, heldFrom)
            }
        }
    }

    override fun send(intent: Intent) {
        when (intent) {
            Intent.Retry -> play("ready")
            Intent.Play -> { setPlaying(true); publishPool() }
            Intent.Stop -> { setPlaying(false); publishPool() }
            is PatternsOpen -> Unit
            is ClearPatterns -> if (!intent.confirmed) Unit else if (_top.value.playing) refuse("Stop playback to clear patterns. The FM-1 only clears them while stopped.") else {
                val gone = pool.filter { it.number in intent.numbers && it.unused }.map { it.number }
                if (gone.isEmpty()) refuse("Left alone because they are in use or empty: " + intent.numbers.joinToString(", ") { "%02d".format(it) }) else {
                    pool = pool.filter { it.number !in gone }; poolFull = false; publishPool()
                    refuse("Cleared patterns ${gone.joinToString(" and ") { "%02d".format(it) }}. ${_patterns.value.free} pattern numbers are free.")
                }
            }
            is RecyclePattern -> { val n = _patterns.value.recycle
                if (_top.value.playing) refuse("Stop playback to recycle a pattern. The FM-1 only does it while stopped.")
                else if (n == null) refuse("No pattern is unused, so there is nothing to recycle.")
                else { pool = pool.map { if (it.number == n) it.copy(unused = false, uses = 1, here = listOf(PatternUse(intent.track, intent.entry)), on = listOf(intent.track)) else it }
                    editEntry(intent.track, intent.entry) { PadEntry(PadKind.Pattern, n) }; publishPool()
                    refuse("Pattern %02d was emptied and put on T${intent.track} pad ${intent.entry + 1}.".format(n)) } }
            is CopyPattern -> refuse("Pattern %02d was copied to a free number and put on T${intent.track} pad ${intent.entry + 1}.".format(intent.number))
            Intent.Rec -> _top.update { it.copy(rec = !it.rec) }
            is Intent.SetTempo -> _top.update { it.copy(tempo = intent.bpm.coerceIn(20.0, 300.0)) }
            is Intent.SetLaunch -> _top.update { it.copy(launch = intent.quantize) }
            Intent.CancelWaiting -> { _pads.update { p -> p.copy(rows = p.rows.map { r -> r.copy(entries = r.entries.map { if (it.play == PadPlay.Waiting) it.copy(play = PadPlay.Idle, bar = null) else it }) }) }; recount() }
            is Intent.SetTab -> _shell.update { it.copy(tab = intent.tab) }
            is SetHomeKnob -> _home.update { FakeHome.set(it, intent.slot, intent.value) }
            // installing Skiff-Lupe (decision 42): a scripted fake loader, never a real FM-1. Not behind the read-only gate: the confirm on the screen is the gate.
            is FirmwareInstall -> when {
                !intent.confirmed -> refuse("The install needs your confirmation first.")
                intent.battery != null && intent.battery < 30 && intent.charging != true -> refuse("Charge the phone first: it's at ${intent.battery}%. The phone powers the FM-1 while it writes, so Lupe installs below 30% only while charging.")
                _top.value.playing -> refuse("Stop playing before installing firmware.")
                _firmware.value.active && _firmware.value.state != "failed" -> Unit
                else -> runFakeInstall(intent)
            }
            FirmwareCancelOffer -> _firmware.update { it.copy(offer = null) }
            FirmwareClose -> _firmware.update { it.copy(state = "idle", progress = 0.0, message = "", installing = null, inUpdateMode = false) }
            is ScreenGoto -> {
                val pages = ScreenPages.of(intent.screen)
                val (n, title) = pages.firstOrNull { it.first == intent.page } ?: pages.firstOrNull() ?: return
                _fm1Screen.value = Fm1ScreenState(key = intent.screen, page = n, title = title)
                // as the real core: the mix area's section follows the FM-1's GLO page by itself
                if (intent.screen == "GLO") listOf("mixer", "delay", "reverb", "chorus", "global").getOrNull(n - 30)?.let { sec -> _mix.update { FakeP5.mix(it, MixSectionPick(sec)) } }
                if (intent.screen == "SEQ") _shell.update { it.copy(bottom = BottomPage()) }
            }
            is com.scottgerstl.lupe.core.GoHome -> { _shell.update { it.copy(bottom = BottomPage()) }; _fm1Screen.value = Fm1ScreenState(key = "HOME") }
            is Intent.SetPlaybackMode -> _top.update { it.copy(mode = intent.mode) }
            is Intent.PadTap -> launch(intent.track, intent.entry)
            is Intent.PadSelect -> selectPad(intent.track, intent.entry)
            is Intent.PadSelectSound -> selectPad(intent.track, intent.entry)   // the Sounds browser is the screen for it (Done returns to whatever the bottom half was on)
            is Intent.PadNew -> if (_pads.value.patternsFree == 0) refuse("All 64 patterns are taken. Clear unused ones to free a number") else padNew(intent.track, intent.entry)
            is Intent.PadSet -> editEntry(intent.track, intent.entry) { it.copy(kind = PadKind.Pattern, pattern = intent.pattern) }
            is ClearUnusedPatterns -> { val p = _pads.value; if (intent.confirmed && p.unused.isNotEmpty()) { val n = p.unused.size
                _pads.value = p.copy(unused = emptyList(), kept = p.kept - p.unused.toSet(), patternsFree = (p.patternsFree ?: 0) + n); refuse("Cleared $n unused pattern${if (n == 1) "" else "s"}: their numbers are free") } }
            is ClearSteps -> {
                // the notes go and the pad stays; the fake keeps no notes to wipe, so it only records the ten-second Undo (the real core wipes and restores them)
                val e = _pads.value.rows.firstOrNull { it.track == intent.track }?.entries?.getOrNull(intent.entry)
                if (e == null || e.kind != PadKind.Pattern) refuse("T${intent.track} pad ${'A' + intent.entry} has no pattern to clear.")
                else {
                    val c = ClearedPad(intent.track, intent.entry, e.pattern, kind = "steps")
                    _pads.update { it.copy(clearUndo = it.clearUndo + c) }
                    scope.launch { kotlinx.coroutines.delay(10_000); _pads.update { it.copy(clearUndo = it.clearUndo - c) } }
                }
            }
            is PadMove -> {
                // the FM-1 rewrites a list only while stopped; a pad moves within its own track, the rest shifting along (P1's real one answers the same way)
                if (_top.value.playing) refuse("Stop to rearrange: the FM-1 moves pads only while stopped")
                else if (intent.toTrack != intent.track) refuse("A pad moves within its own track. Copy it to put it on another one.")
                else {
                    _pads.update { p -> p.copy(rows = p.rows.map { r ->
                        if (r.track != intent.track || intent.from !in r.entries.indices || r.entries[intent.from].kind == PadKind.Empty) r
                        else {
                            // P1's rules (pattern-pad.md B15–B17): onto a filled pad the two swap; onto an empty one it moves there and leaves its old place empty
                            val l = r.entries.toMutableList()
                            val to = intent.to.coerceIn(0, l.size - 1).let { t -> if (l[t].kind == PadKind.Empty) minOf(t, l.indexOfFirst { it.kind == PadKind.Empty }.let { if (it < 0) t else it }) else t }
                            val x = l[intent.from]; l[intent.from] = l[to]; l[to] = x
                            r.copy(entries = l)
                        } }) }
                    recount()
                }
            }
            is Intent.PadClear -> {
                // no confirm (batch item 13): the pad is cleared at once and can come back for ten seconds
                val e = _pads.value.rows.firstOrNull { it.track == intent.track }?.entries?.getOrNull(intent.entry)
                editEntry(intent.track, intent.entry) { PadEntry() }
                if (e != null && e.kind != PadKind.Empty) {
                    val c = ClearedPad(intent.track, intent.entry, if (e.kind == PadKind.Pattern) e.pattern else null)
                    _pads.update { it.copy(clearUndo = it.clearUndo + c) }
                    scope.launch { kotlinx.coroutines.delay(10_000); _pads.update { it.copy(clearUndo = it.clearUndo - c) } }
                }
            }
            is UndoClear -> {
                val c = _pads.value.clearUndo.lastOrNull { intent.track == null || (it.track == intent.track && it.entry == intent.entry) }
                if (c == null) refuse("There is no clear to undo any more.")
                else if (c.block) {
                    val was = blockUndo.remove(c)
                    if (was != null) _timeline.update { st -> st.copy(tracks = st.tracks.map { if (it.track == c.track) was else it }) }
                    _pads.update { it.copy(clearUndo = it.clearUndo - c) }
                }
                else { editEntry(c.track, c.entry) { if (c.pattern != null) PadEntry(PadKind.Pattern, c.pattern) else PadEntry(PadKind.Rest) }; _pads.update { it.copy(clearUndo = it.clearUndo - c) } }
            }
            is Intent.TrackSelect -> {
                _mix.update { FakeP5.mix(it, intent) }
                val row = _pads.value.rows.firstOrNull { it.track == intent.track } ?: return
                val at = row.entries.indexOfFirst { it.play == PadPlay.Playing }.takeIf { it >= 0 } ?: row.entries.indexOfFirst { it.kind == PadKind.Pattern }
                if (at >= 0) selectPad(intent.track, at)
            }
            // while it plays a mute waits for the launch point, as on the FM-1 (a second press takes the wait back); stopped, it lands at once
            is Intent.TrackMute -> if (_top.value.playing) _pads.update { p -> p.copy(rows = p.rows.map { if (it.track == intent.track) it.copy(mutePending = if (it.mutePending != "none") "none" else if (it.muted) "unmute" else "mute", launchTick = nextBarTick()) else it }) }
                else { _mix.update { FakeP5.mix(it, intent) }; _pads.update { p -> p.copy(rows = p.rows.map { if (it.track == intent.track) it.copy(muted = !it.muted) else it }) } }
            is Intent.SceneRecall -> { recall(intent.scene); if (_top.value.playing) _pads.update { p -> p.copy(scenes = p.scenes.mapIndexed { i, sc -> sc.copy(waiting = i == intent.scene, launchTick = nextBarTick()) }) } }
            is Intent.SceneStore -> if (_pads.value.scenes.getOrNull(intent.scene)?.stored == true && !intent.confirmed) Unit /* the core refuses: must confirm */ else store(intent.scene)
            is Intent.StepSelect -> emitEditor { it.copy(selected = intent.step.coerceIn(0, model.size - 1)) }
            is Intent.StepHold -> emitEditor {
                when {
                    intent.down -> it.copy(selected = intent.step, lock = LockMode.Held)
                    it.lock == LockMode.Held -> it.copy(lock = LockMode.Off)
                    else -> it
                }
            }
            is Intent.StepAdjust -> adjust(intent.field, intent.delta)
            is PlayNote -> {}   // it would sound; the fake has no voice
            is SetStepNotes -> if (_editor.value.kind != EditorKind.Drum && intent.notes.distinct().size <= 4) {   // more than four is refused whole
                val st = model[intent.step.coerceIn(0, model.size - 1)]
                val notes = intent.notes.distinct()
                if (notes.isEmpty()) { st.on = false; st.more.clear(); st.extra = 0 }
                else { if (!st.on) st.velocity = 100; st.on = true; st.midi = notes[0]; st.more = notes.drop(1).toMutableList(); st.extra = st.more.size }
                emitEditor { it.copy(selected = intent.step.coerceIn(0, model.size - 1)) }
            }
            is ToggleStepNote -> if (_editor.value.kind != EditorKind.Drum) {
                val st = model[intent.step.coerceIn(0, model.size - 1)]
                val notes = st.notes().toMutableList()
                if (intent.note in notes) notes.remove(intent.note) else if (notes.size < 4) notes.add(intent.note)   // a full step is left alone
                if (notes.isEmpty()) { st.on = false; st.more.clear(); st.extra = 0 }
                else { if (!st.on) st.velocity = 100; st.on = true; st.midi = notes[0]; st.more = notes.drop(1).toMutableList(); st.extra = st.more.size }
                emitEditor()
            }
            is ToggleHit -> if (_editor.value.kind == EditorKind.Drum && intent.lane in FakeData.drumLanes.indices) {
                val st = model[intent.step.coerceIn(0, model.size - 1)]
                if (!st.on) st.velocity = 100
                if (!st.lanes.remove(intent.lane)) st.lanes.add(intent.lane)
                st.on = st.lanes.isNotEmpty(); emitEditor()
            }
            // LENGTH: the pattern's step count. Shorter drops the tail; longer repeats the pattern's steps (a demo, so there is something past 16)
            is SetPatternSteps -> {
                val n = intent.steps.coerceIn(1, 64); val old = model.size
                if (n != old) {
                    model = if (n < old) model.subList(0, n).toMutableList() else MutableList(n) { i -> if (i < old) model[i] else model[i % old].copyOf().also { it.values.clear() } }
                    stepPatterns[_editor.value.track to _editor.value.pattern] = model
                    emitEditor { it.copy(selected = it.selected.coerceIn(0, n - 1)) }
                }
            }
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
            is SetParam -> _page.update { pageFake.setParam(it, intent.slot, intent.value) }
            is PickPage -> { _fm1Screen.value = Fm1ScreenState(key = intent.family, page = intent.page ?: 0, title = intent.family); _page.update { pageFake.pick(it, intent.family, intent.page, _editor.value.track, _editor.value.trackName) }; _shell.update { it.copy(bottom = BottomPage(BottomKind.Page, _page.value.family, _page.value.pages.firstOrNull { r -> r.index == _page.value.page }?.title)) } }
            is PickRoute -> _page.update { pageFake.pickRoute(it, intent.route) }
            is PickTile -> _page.update { pageFake.pickTile(it, intent.tile) }
            is Intent.LanePick -> emitEditor { it.copy(lane = intent.lane) }
            // FREE TAKE (FreeTakeState.kt): the picker's choices; the shell follows the picker
            TakeStart, is TakeGuessPick, is TakeBarsPick, is TakeFirstBeat, is TakeSetTempo, TakeListen, TakeKeep, TakePutBack, TakeUndo, TakeDismissOffer, TakeDismissLanded -> {
                val ed = _editor.value
                _freeTake.update { FakeTake.apply(it, intent, ed.track, ed.trackName) }
                _shell.update { it.copy(bottom = if (_freeTake.value.picker != null) BottomPage(BottomKind.FreeTake) else if (it.bottom.kind == BottomKind.FreeTake) BottomPage() else it.bottom) }
            }
            is BlockDelete -> {
                // no confirm (batch item 13): it goes at once and can come back for ten seconds, the track as the delete left it
                val tr = _timeline.value.tracks.firstOrNull { it.track == intent.track }
                val b = tr?.blocks?.firstOrNull { it.id == intent.block }
                _timeline.update { FakeP6.timeline(it, intent.copy(confirmed = true)) }
                if (tr != null && b != null) {
                    val c = ClearedPad(intent.track, intent.block, if (b.kind == "pattern") b.pattern else null, block = true)
                    blockUndo[c] = tr
                    _pads.update { it.copy(clearUndo = it.clearUndo.filter { u -> !(u.block && u.track == c.track) } + c) }
                    scope.launch { kotlinx.coroutines.delay(10_000); blockUndo.remove(c); _pads.update { it.copy(clearUndo = it.clearUndo - c) } }
                }
            }
            is BlockMove, is BlockStretch, is BlockSetPattern, is BlockDuplicate, is BlockInsert -> _timeline.update { FakeP6.timeline(it, intent) }
            is BlockNew -> _timeline.update { FakeP6.timeline(it, BlockInsert(intent.track, Int.MAX_VALUE, _timeline.value.kept.maxOrNull()?.plus(1) ?: 1)) }
            is AutomationLanePick -> { autoLane = intent.lane; emitEditor() }
            is DrawLane -> {
                val st = _editor.value.selected
                val p = intent.param
                // refused unless confirmed when any painted step shows recorded data (one held from an earlier step counts), as the core
                val pts = FakeP6.automation(_editor.value, p).points
                val hasRecorded = (intent.from until intent.from + intent.values.size).any { pts.getOrNull(it)?.source == "recorded" }
                if (!(hasRecorded && !intent.confirmed)) {          // drawing over recorded changes is refused unless confirmed
                    intent.values.forEachIndexed { n, v ->
                        val k = intent.from + n
                        if (k in model.indices) { model[k].values.removeAll { it.param == p }; model[k].values.add(StepValue(p, v.coerceIn(0, 127), locked = intent.lock)) }
                    }
                    emitEditor()
                }
            }
            is ClearLane -> if (intent.confirmed) { model.forEach { m -> m.values.removeAll { it.param == intent.param } }; emitEditor() }
            // P5's intents (P5State.kt): mix, sounds, projects
            is MixSectionPick, is SetLevel, is SetPan, is SetReverb, is TrackSolo, is SetMixParam, is SetMixSetting -> _mix.update { FakeP5.mix(it, intent) }
            is SoundsTargetPick, is SoundsView, is PickPreset, is PickUser, ClearEntrySound, is SaveSound, is EraseUser -> _sounds.update { FakeP5.sounds(it, intent) }
            is ProjectLoad, is ProjectSave, is ProjectSaveAs, is ProjectRename -> _projects.update { FakeP5.projects(it, intent) }
            else -> {}
        }
    }

    // ---- editor

    private fun emitEditor(change: (EditorState) -> EditorState = { it }) {
        val e = change(_editor.value)
        val drum = e.kind == EditorKind.Drum
        val lane = e.lane
        val lv = model.map { st -> ((st.values.firstOrNull { it.param == lane }?.value ?: (FakeData.baseValue(lane) + if (lane.isEmpty()) 0 else (model.indexOf(st) * 7) % 22 - 8)) * 100 / 127).coerceIn(0, 100) }
        // how far each step can grow: up to the next note (or the pattern's end)
        val steps = model.mapIndexed { i, st ->
            val next = (i + 1 until model.size).firstOrNull { model[it].on } ?: model.size
            // a step inside the previous note's length holds it (a TIE): heldFrom is that note's step
            val owner = (i - 1 downTo 0).firstOrNull { model[it].on && it + model[it].length > i && (it + 1..i).none { k -> k != i && model[k].on } }
            st.toStep(drum).copy(maxLength = next - i, heldFrom = if (!st.on && owner != null) owner else -1)
        }
        _editor.value = e.copy(steps = steps, laneValues = lv, maxNotes = if (drum) 0 else 4, kitLanes = if (drum) FakeData.drumLanes else emptyList(), patternSteps = model.size, patternStepsMax = 64)
        // the automation area follows the pattern (unless a recording supplied its own, which the next frame replaces)
        if (e.lanes.isNotEmpty()) _automation.value = FakeP6.automation(_editor.value, autoLane.ifEmpty { e.lane })
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
                val to = Math.floorMod(ed.selected + delta, model.size)
                val tmp = model[to]; model[to] = model[ed.selected]; model[ed.selected] = tmp
                emitEditor { it.copy(selected = to) }; return
            }
            StepField.Length -> { val next = (ed.selected + 1 until model.size).firstOrNull { model[it].on } ?: model.size; st.length = (st.length + delta).coerceIn(1, next - ed.selected) }
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
        model = stepPatterns.getOrPut(track to e.pattern) { FStep.generate(track, e.pattern) }
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

    /** The demo's firmware states, for looking at the screens: what the FM-1 runs and what is offered (kind install / update / finish / foreign), or nothing. */
    fun showFirmwareOffer(kind: String?) {
        _firmware.update {
            when (kind) {
                "install" -> it.copy(running = "Skiff 2.6", identity = "FELUCCA v2.6.0", offer = FirmwareOffer("install", "stockSkiff", "stockSkiff|2.6", "Skiff-Lupe-2.5.1", "Lupe needs other firmware",
                    "This FM-1 runs Skiff 2.6. Lupe works with Skiff-Lupe 2.5.1: Skiff with Lupe's screen link. Installing it takes the FM-1 back to 2.5.1, so it loses CAST. Your projects stay."))
                "sloop" -> it.copy(running = "SLOOP 2.8.4", identity = "FELUCCA v2.8.4", offer = FirmwareOffer("install", "sloop", "sloop|2.8.4", "Skiff-Lupe-2.5.1", "Lupe needs other firmware",
                    "This FM-1 runs SLOOP 2.8.4. Lupe works with Skiff-Lupe 2.5.1. Skiff converts SLOOP's projects when it opens them."))
                "update" -> it.copy(running = "Skiff-Lupe 2.4", identity = "FELUCCA v2.4.0", offer = FirmwareOffer("update", "olderLupe", "olderLupe|2.4", "Skiff-Lupe-2.5.1", "An update for Skiff-Lupe 2.4",
                    "Lupe can install Skiff-Lupe 2.5.1, the newer build of the screen link."))
                "finish" -> it.copy(running = null, identity = "FELUCCA UPDATE", offer = FirmwareOffer("finish", "loader", "loader|update", "Skiff-Lupe-2.5.1", "Finish the firmware install",
                    "The FM-1 is waiting in update mode: an install was cut off. Nothing is lost. Lupe can finish it now with Skiff-Lupe 2.5.1."))
                "foreign" -> it.copy(running = null, identity = "ota-FM-1_301", offer = FirmwareOffer("foreign", "unknown", "unknown|ota", null, "The FM-1 is in another update mode",
                    "It reports ota-FM-1_301, another firmware's update mode. Finish it with the updater that started it, then plug the FM-1 in again."))
                else -> it.copy(running = "Skiff-Lupe 2.5.1", identity = "FELUCCA v2.5.1", offer = null)
            }
        }
    }

    /** A scripted install: download, backup, staging, writing, restarting, done (or a cut when the offer is "finish"'s opposite: tests drive failures by [failAt]). */
    var failAt: String? = null
    private fun runFakeInstall(i: FirmwareInstall) {
        val name = firmwareWords(i.which ?: _firmware.value.offer?.firmware)
        scope.launch {
            fun set(state: String, p: Double, msg: String, backup: String? = _firmware.value.backup) = _firmware.update { it.copy(state = state, progress = maxOf(it.progress, p), message = msg, installing = name, backup = backup, inUpdateMode = false) }
            _firmware.update { it.copy(progress = 0.0, backup = null) }
            set("downloading", 0.02, "Downloading $name from GitHub"); kotlinx.coroutines.delay(700); set("downloading", 0.06, "Downloading $name from GitHub")
            if (failAt == "backingUp") { _firmware.update { it.copy(state = "failed", message = "The backup couldn't be taken.", installing = name) }; return@launch }
            if (!i.skipBackup) { set("backingUp", 0.1, "Backing up the projects"); kotlinx.coroutines.delay(700); set("backingUp", 0.25, "Backing up the projects", "/data/user/0/com.scottgerstl.lupe/files/Backups/2026-11-15-skiff-2.4.bak") }
            set("staging", 0.3, "Checking the firmware file"); kotlinx.coroutines.delay(600)
            for (p in listOf(0.4, 0.55, 0.7, 0.85, 0.95)) { set("writing", p, "Writing the firmware"); kotlinx.coroutines.delay(500)
                if (failAt == "writing" && p >= 0.7) { _firmware.update { it.copy(state = "failed", message = "The FM-1 dropped off USB.", inUpdateMode = true) }; return@launch } }
            set("restarting", 0.98, "Restarting the FM-1"); kotlinx.coroutines.delay(700)
            _firmware.update { it.copy(state = "done", progress = 1.0, message = "The FM-1 restarted and reports Skiff-Lupe 2.5.1.", offer = null, running = "Skiff-Lupe 2.5.1") }
        }
    }

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

    /** The clock pulse (24 a quarter, 6 a sixteenth) the next bar starts on. */
    private fun nextBarTick(): Double = (stepCount / 16 + 1) * 96.0
    /** `SystemClock.uptimeMillis()`, the clock area's time base (0 where there is no Android, as in unit tests). */
    private fun uptime(): Long = runCatching { android.os.SystemClock.uptimeMillis() }.getOrDefault(0L)

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
            _playhead.update { it.copy(step = -1) }
            _meters.value = MetersState()
            _timeline.update { it.copy(playing = false, playheadBar = null) }
            _clock.value = ClockState()
            _pads.update { p -> p.copy(scenes = p.scenes.map { it.copy(waiting = false, launchTick = null) }, rows = p.rows.map { r -> r.copy(mutePending = "none", soloPending = false, launchTick = null, passTicks = null, passStartTick = null, entries = r.entries.map { it.copy(progress = null, launchTick = null) }) }) }
        }
        syncTicker(on)
    }

    // The readout, the playhead and the pads' pass bars move while playing, a sixteenth at a time at the current
    // tempo (the real core counts the FM-1's clock).
    private fun syncTicker(playing: Boolean) {
        ticker?.cancel()
        if (!playing) return
        stepCount = 0; startBar = _top.value.bar
        _clock.value = ClockState(true, 0.0, uptime(), _top.value.tempo / 60.0 * 24.0)
        ticker = scope.launch {
            while (true) {
                delay((60_000.0 / _top.value.tempo / 4).toLong())
                stepCount++
                val bar = startBar + stepCount / 16
                val beat = (stepCount / 4) % 4 + 1
                val newBar = stepCount % 16 == 0
                _top.update { it.copy(bar = bar, beat = beat) }
                _timeline.update { it.copy(playing = true, playheadBar = (bar - 1) + (beat - 1) / 4.0) }
                if (newBar) _pads.update { p -> p.copy(rows = p.rows.map { r ->
                    val landing = r.entries.indexOfFirst { it.play == PadPlay.Waiting && (it.bar ?: 0) <= bar }
                    if (landing < 0) r else r.copy(entries = r.entries.mapIndexed { i, x ->
                        if (i == landing) x.copy(play = PadPlay.Playing, bar = null) else if (x.play == PadPlay.Playing) x.copy(play = PadPlay.Idle) else x })
                }) }
                // what waited for the bar lands on it: mutes, and the recalled scene
                if (newBar) {
                    _pads.value.rows.filter { it.mutePending != "none" }.forEach { r -> _mix.update { FakeP5.mix(it, Intent.TrackMute(r.track)) } }
                    _pads.update { p -> p.copy(rows = p.rows.map { if (it.mutePending != "none") it.copy(muted = it.mutePending == "mute", mutePending = "none") else it }, scenes = p.scenes.map { it.copy(waiting = false, launchTick = null) }) }
                }
                // a new clock reference every beat (and the count the rows' launch points and passes are measured in)
                if (stepCount % 4 == 0) _clock.value = ClockState(true, stepCount * 6.0, uptime(), _top.value.tempo / 60.0 * 24.0)
                val barStart = (stepCount / 16) * 96.0
                _pads.update { p -> p.copy(rows = p.rows.map { r ->
                    val playing = r.entries.any { it.play == PadPlay.Playing }
                    val waits = r.entries.any { it.play == PadPlay.Waiting } || r.mutePending != "none" || r.soloPending
                    r.copy(passTicks = if (playing) 96.0 else null, passStartTick = if (playing) barStart else null, launchTick = if (waits) nextBarTick() else null,
                        entries = r.entries.map {
                            when (it.play) {
                                PadPlay.Playing -> it.copy(progress = (stepCount % 16) / 16f, launchTick = null)
                                PadPlay.Waiting -> it.copy(launchTick = nextBarTick() + 96.0 * (((it.bar ?: 0) - (startBar + stepCount / 16) - 1).coerceAtLeast(0)))
                                else -> if (it.launchTick != null) it.copy(launchTick = null) else it
                            }
                        }) }) }
                recount()
                // as the real core sends it now: its own small area per step, the editor area's playhead stays -1
                _playhead.value = PlayheadState(track = _editor.value.track, step = stepCount % model.size, steps = model.size)
                // the meters move while it plays: each track near its level, never louder
                _meters.value = MetersState(_mix.value.rows.mapIndexed { n, r -> if (r.mute) 0.0 else (r.level / 127.0) * (0.55 + 0.45 * kotlin.math.abs(kotlin.math.sin((stepCount + n * 3) * 0.7))) })
            }
        }
    }
}

/** The fake's HOME knobs: ANALOG's CUTOFF 84, RES 40, ATTACK 12, RELEASE 64 (board 70). */
internal object FakeHome {
    fun seed() = HomeKnobsState(1, "Analog · Acid", "ANALOG", "ACID", listOf("CUTOFF" to 84, "RES" to 40, "ATTACK" to 12, "RELEASE" to 64).map { (l, v) -> PageControl(l, "$v", v, 0, 127) }, fm1Home = true)
    fun set(s: HomeKnobsState, slot: Int, value: Int): HomeKnobsState {
        val c = s.controls.getOrNull(slot) ?: return s
        val v = value.coerceIn(c.min, c.max)
        return s.copy(controls = s.controls.mapIndexed { i, x -> if (i == slot) c.copy(raw = v, value = "$v") else x })
    }
}
