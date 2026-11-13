package com.scottgerstl.lupe.core

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
    private val _sounds = MutableStateFlow(SoundsState())
    private val _projects = MutableStateFlow(ProjectsState())
    private val _meters = MutableStateFlow(MetersState())
    override val link: StateFlow<LinkState> = _link
    override val top: StateFlow<TopState> = _top
    override val shell: StateFlow<ShellState> = _shell
    override val pads: StateFlow<PadsState> = _pads
    override val editor: StateFlow<EditorState> = _editor
    override val page: StateFlow<PageState> = _page
    override val mix: StateFlow<MixState> = _mix
    override val sounds: StateFlow<SoundsState> = _sounds
    override val projects: StateFlow<ProjectsState> = _projects
    override val meters: StateFlow<MetersState> = _meters

    init {
        LupeNative.stateListener = { area, json -> receive(area, json) }
    }

    /** Swift calls this on the UI thread (the main actor). */
    fun receive(area: String, json: String) {
        LinkLog.area(area, json)
        try {
            when (area) {
                "link" -> _link.value = lupeJson.decodeFromString(LinkState.serializer(), json)
                "top" -> _top.value = lupeJson.decodeFromString(TopState.serializer(), json)
                // Swift sends only `bottom` (what the FM-1 shows); tab and divider stay the screens' own
                "shell" -> _shell.update { it.copy(bottom = lupeJson.decodeFromString(ShellBottom.serializer(), json).bottom) }
                "pads" -> _pads.value = lupeJson.decodeFromString(PadsState.serializer(), json)
                "editor" -> _editor.value = lupeJson.decodeFromString(EditorState.serializer(), json)
                "page" -> _page.value = lupeJson.decodeFromString(PageState.serializer(), json)
                "mix" -> _mix.value = lupeJson.decodeFromString(MixState.serializer(), json)
                "sounds" -> _sounds.value = lupeJson.decodeFromString(SoundsState.serializer(), json)
                "projects" -> _projects.value = lupeJson.decodeFromString(ProjectsState.serializer(), json)
                "meters" -> _meters.value = lupeJson.decodeFromString(MetersState.serializer(), json)
                else -> {}   // an area from a later phase: kept in LinkLog for the debug screen
            }
        } catch (e: Exception) {
            LinkLog.add("couldn't decode area $area: ${e.message}")
        }
    }

    override fun send(intent: Intent) {
        when (intent) {
            is Intent.SetTab -> _shell.value = _shell.value.copy(tab = intent.tab)
            is Intent.SetDivider -> _shell.value = _shell.value.copy(divider = intent.position)
            else -> scope.launch { LupeNative.intent(lupeJson.encodeToString(Intent.serializer(), intent)) }
        }
    }
}
