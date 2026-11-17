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
    /** The FM-1 key whose screen is up (decision 24): ScreenState.kt. */
    val fm1Screen: StateFlow<Fm1ScreenState> get() = ScreenDefaults.fm1Screen

    /** The clock reference for per-frame movement (ClockState.kt). */
    val clock: StateFlow<ClockState> get() = ClockDefaults.clock
    /** The editor track's playing step (PlayheadState.kt): one small send per step, not part of the editor area. */
    val playhead: StateFlow<PlayheadState> get() = PlayheadDefaults.state
    /** The FM-1's notes sounding now, by track (KeysState.kt). */
    val keys: StateFlow<KeysState> get() = KeysDefaults.state

    /** The pattern pool (PatternsState.kt, board 79) and its pictures. */
    val patterns: StateFlow<PatternsState> get() = PatternsDefaults.patterns
    val patternPictures: StateFlow<PatternPictures> get() = PatternsDefaults.pictures

    /** The firmware the FM-1 runs, what the phone offers, and the install's progress (FirmwareState.kt; P1's fe3faaf). */
    val firmware: StateFlow<FirmwareState> get() = FirmwareDefaults.state

    /** Answers to [ProjectTransfer] requests, as they happen (ProjectTransfer.kt). */
    val transfers: kotlinx.coroutines.flow.SharedFlow<TransferEvent> get() = TransferDefaults.none

    /** The last thing refused, to show on screen (Notice.kt). */
    val notice: StateFlow<CoreNotice> get() = NoticeDefaults.notice

    fun send(intent: Intent)
}
