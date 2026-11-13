package com.scottgerstl.lupe.core

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
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
    override val link: StateFlow<LinkState> = _link
    override val top: StateFlow<TopState> = _top
    override val shell: StateFlow<ShellState> = _shell
    override val pads: StateFlow<PadsState> = _pads
    override val editor: StateFlow<EditorState> = _editor

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
                "shell" -> _shell.value = lupeJson.decodeFromString(ShellState.serializer(), json)
                "pads" -> _pads.value = lupeJson.decodeFromString(PadsState.serializer(), json)
                "editor" -> _editor.value = lupeJson.decodeFromString(EditorState.serializer(), json)
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
