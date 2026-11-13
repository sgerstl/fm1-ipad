package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.StateFlow

/**
 * The whole surface Compose sees (android/BRIDGE.md §2): a flow per ViewState area, and [send] for what the
 * person did. P1's real core and [FakeLupeCore] both implement it; screens never know which.
 * Later phases add areas here (pads, editor, page, mix …), one at a time.
 */
interface LupeCore {
    val link: StateFlow<LinkState>
    val top: StateFlow<TopState>
    val shell: StateFlow<ShellState>

    fun send(intent: Intent)
}
