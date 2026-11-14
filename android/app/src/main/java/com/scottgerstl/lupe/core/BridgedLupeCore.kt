package com.scottgerstl.lupe.core

import android.os.SystemClock
import android.view.Choreographer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * The real core: P2's [LupeCore] over Swift's PhoneCore (android/BRIDGE.md §2). Each `onState(area, json)` from
 * Swift is decoded with [lupeJson] into P2's data classes and pushed into the matching flow; each [Intent] goes
 * to Swift as JSON. `shell` (tab, divider) is the screens' own state for now and stays here: Swift doesn't
 * publish it until the FM-1's page drives the bottom half (screen link, a later phase).
 */
class BridgedLupeCore(private val scope: CoroutineScope) : LupeCore {
    private val _link = MutableStateFlow(LinkState())
    private val _top = MutableStateFlow(TopState())
    private val _shell = MutableStateFlow(ShellState())
    private val _pads = MutableStateFlow(PadsState())
    private val _editor = MutableStateFlow(EditorState())
    /** P4's page: not published by PhoneCore yet (android/notes/p1-page-area-brief.md), so it stays at its default. */
    private val _page = MutableStateFlow(PageState())
    private val _mix = MutableStateFlow(MixState())
    private val _freeTake = MutableStateFlow(FreeTakeState())
    private val _sounds = MutableStateFlow(SoundsState())
    private val _projects = MutableStateFlow(ProjectsState())
    private val _meters = MutableStateFlow(MetersState())
    private val _timeline = MutableStateFlow(TimelineState())
    private val _automation = MutableStateFlow(AutomationState())
    private val _homeKnobs = MutableStateFlow(HomeKnobsState())
    private val _fm1Screen = MutableStateFlow(Fm1ScreenState())
    private val _clock = MutableStateFlow(ClockState())
    private var clockChecked = false
    override val link: StateFlow<LinkState> = _link
    override val top: StateFlow<TopState> = _top
    override val shell: StateFlow<ShellState> = _shell
    override val pads: StateFlow<PadsState> = _pads
    override val editor: StateFlow<EditorState> = _editor
    override val page: StateFlow<PageState> = _page
    override val mix: StateFlow<MixState> = _mix
    override val freeTake: StateFlow<FreeTakeState> = _freeTake
    override val sounds: StateFlow<SoundsState> = _sounds
    override val projects: StateFlow<ProjectsState> = _projects
    override val meters: StateFlow<MetersState> = _meters
    override val timeline: StateFlow<TimelineState> = _timeline
    override val automation: StateFlow<AutomationState> = _automation
    override val homeKnobs: StateFlow<HomeKnobsState> = _homeKnobs
    override val fm1Screen: StateFlow<Fm1ScreenState> = _fm1Screen
    override val clock: StateFlow<ClockState> = _clock
    private val _notice = MutableStateFlow(CoreNotice())
    override val notice: StateFlow<CoreNotice> = _notice
    /** A refusal for the screen: from the core's `notice` area when it has one, else from its log line. */
    /** The core has published a `notice` area: its log lines are no longer read for refusals. */
    @Volatile private var noticeArea = false
    private fun refuse(text: String) { _notice.value = CoreNotice(_notice.value.seq + 1, text) }

    init {
        // the core says what it refused only in its log: put those lines on the screen (posted to the UI thread; Swift may log from any)
        // …but only from a core that has no `notice` area. One that has it still writes the same lines, so a log refusal waits a quarter of a
        // second and is dropped if the area spoke meanwhile (or ever has): each refusal shows once.
        val ui = android.os.Handler(android.os.Looper.getMainLooper())
        LupeNative.debugListener = { line -> if (!noticeArea) refusalFromLog(line)?.let { words -> ui.postDelayed({ if (!noticeArea) refuse(words) }, 250) } }
        LupeNative.stateListener = { area, json -> receive(area, json) }
    }

    /** The page lag's Kotlin half (PhoneCore's LagTrace.swift is the Swift half; both read CLOCK_MONOTONIC): set when a
     *  family key or the back gesture sends, then for 1.5 s each shell or page arriving is logged with its decode time
     *  and the display frame after it. Lines start "lag kotlin" in LupeLog. */
    private var lagSince = 0L
    private var lagWhat = ""

    private fun lagMark(line: String) {
        if (lagSince == 0L) return
        val dt = SystemClock.uptimeMillis() - lagSince
        if (dt > 1500) { lagSince = 0L; return }
        LinkLog.add("lag kotlin $lagWhat +$dt ms: $line")
    }

    /** Swift calls this on the UI thread (the main actor). */
    fun receive(area: String, json: String) {
        val t = if (lagSince != 0L && (area == "page" || area == "shell")) SystemClock.uptimeMillis() else 0L
        LinkLog.area(area, json)
        if (t != 0L) {
            val doneAt = { lagMark("$area decoded in ${SystemClock.uptimeMillis() - t} ms (${json.length} bytes)") }
            receiveArea(area, json); doneAt()
            Choreographer.getInstance().postFrameCallback { lagMark("$area: next frame") }
            return
        }
        receiveArea(area, json)
    }

    private fun receiveArea(area: String, json: String) {
        try {
            when (area) {
                "link" -> _link.value = lupeJson.decodeFromString(LinkState.serializer(), json)
                "top" -> _top.value = lupeJson.decodeFromString(TopState.serializer(), json)
                // Swift sends only `bottom` (what the FM-1 shows); tab and divider stay the screens' own
                "shell" -> _shell.update { it.copy(bottom = lupeJson.decodeFromString(ShellBottom.serializer(), json).bottom) }
                "pads" -> _pads.value = lupeJson.decodeFromString(PadsState.serializer(), json)
                "editor" -> _editor.value = lupeJson.decodeFromString(EditorState.serializer(), json)
                "page" -> _page.value = lupeJson.decodeFromString(PageState.serializer(), json)
                "freetake" -> _freeTake.value = lupeJson.decodeFromString(FreeTakeState.serializer(), json)
                "mix" -> _mix.value = lupeJson.decodeFromString(MixState.serializer(), json)
                "sounds" -> _sounds.value = lupeJson.decodeFromString(SoundsState.serializer(), json)
                "projects" -> _projects.value = lupeJson.decodeFromString(ProjectsState.serializer(), json)
                "meters" -> _meters.value = lupeJson.decodeFromString(MetersState.serializer(), json)
                "timeline" -> _timeline.value = lupeJson.decodeFromString(TimelineState.serializer(), json)
                "automation" -> _automation.value = lupeJson.decodeFromString(AutomationState.serializer(), json)
                "homeKnobs" -> _homeKnobs.value = lupeJson.decodeFromString(HomeKnobsState.serializer(), json)
                "fm1Screen" -> _fm1Screen.value = lupeJson.decodeFromString(Fm1ScreenState.serializer(), json)
                "clock" -> {
                    // atMs must be on SystemClock.uptimeMillis()'s clock: the screen moves the outlines and pass bars on from it every frame. If it isn't
                    // (a boot-time clock that counts sleep would put it hours off), take the time the frame arrived instead, and say so once.
                    val c = lupeJson.decodeFromString(ClockState.serializer(), json)
                    val now = SystemClock.uptimeMillis()
                    val skew = c.atMs - now
                    if (c.running && !clockChecked) { clockChecked = true; LinkLog.add("clock: atMs ${c.atMs}, uptimeMillis $now, apart $skew ms" + if (kotlin.math.abs(skew) > 1000) " (too far: using the arrival time)" else "") }
                    _clock.value = if (c.running && kotlin.math.abs(skew) > 1000) c.copy(atMs = now) else c
                }
                "notice" -> { noticeArea = true; val n = lupeJson.decodeFromString(CoreNotice.serializer(), json); if (n.text.isNotEmpty()) _notice.value = n.copy(seq = _notice.value.seq + 1, text = refusalWords(n.text)) }
                else -> {}   // an area from a later phase: kept in LinkLog for the debug screen
            }
        } catch (e: Exception) {
            LinkLog.add("couldn't decode area $area: ${e.message}")
        }
    }

    override fun send(intent: Intent) {
        if (intent is PickPage || intent is GoHome) {
            lagSince = SystemClock.uptimeMillis(); lagWhat = intent.toString()
            LinkLog.add("lag kotlin $lagWhat +0 ms: sent (clock $lagSince)")
        }
        when (intent) {
            is Intent.SetTab -> _shell.value = _shell.value.copy(tab = intent.tab)
            else -> scope.launch { LupeNative.intent(lupeJson.encodeToString(Intent.serializer(), intent)) }
        }
    }
}
