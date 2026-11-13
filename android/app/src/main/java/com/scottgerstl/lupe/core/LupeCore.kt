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
    val pads: StateFlow<PadsState>
    val editor: StateFlow<EditorState>
    /** The bottom half's sound page (ENV, LFO, FX, SEL, EDIT, ARP): P4. */
    val page: StateFlow<PageState>
    /** P5 (P1's core publishes them; P5State.kt). Defaults for a core that doesn't yet. */
    val mix: StateFlow<MixState> get() = P5Defaults.mix
    val sounds: StateFlow<SoundsState> get() = P5Defaults.sounds
    val projects: StateFlow<ProjectsState> get() = P5Defaults.projects
    val meters: StateFlow<MetersState> get() = P5Defaults.meters
    /** FREE TAKE: the offer, the FM-1's picker, the landing (FreeTakeState.kt). */
    val freeTake: StateFlow<FreeTakeState> get() = FreeTakeDefaults.state
    /** P6 (P6State.kt). */
    val timeline: StateFlow<TimelineState> get() = P6Defaults.timeline
    val automation: StateFlow<AutomationState> get() = P6Defaults.automation
    /** HOME's four sound knobs under the step grid (HomeKnobsState.kt). */
    val homeKnobs: StateFlow<HomeKnobsState> get() = HomeKnobsDefaults.state

    fun send(intent: Intent)
}
