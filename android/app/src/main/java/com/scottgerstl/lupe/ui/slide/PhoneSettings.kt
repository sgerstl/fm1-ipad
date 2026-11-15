package com.scottgerstl.lupe.ui.slide

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback

/**
 * The rest of Settings (P5, board 67): Haptics, and Labs, the settings to try on the phone, each off until
 * switched on (design/boards/phone-portrait-2.html board 67; Scott's decisions 3, 5 and 6). Kept in the same
 * SharedPreferences as [SlideSettings]. Labs entries follow CLAUDE.md rule 3 in spirit: a trial the person can
 * switch off, nothing hard-wired.
 */
class PhoneSettings(private val prefs: SharedPreferences? = null) {
    var haptics by mutableStateOf(prefs?.getBoolean(HAPTICS, true) ?: true)
        private set
    /** Labs: the sound page holds for 3 s after you touch it (decision 3's "pause after a phone touch"). */
    var pauseFollowing by mutableStateOf(prefs?.getBoolean(PAUSE, false) ?: false)
        private set
    /** Labs: the sound page and the sheets stop following the FM-1 (decision 3's pin). */
    var pinBottom by mutableStateOf(prefs?.getBoolean(PIN, false) ?: false)
        private set
    /** Labs: a one-octave piano under the grid (decision 5). Stored; the piano itself isn't built yet. */
    var piano by mutableStateOf(prefs?.getBoolean(PIANO, false) ?: false)
        private set
    /** Labs: the Timeline with time across, as the FM-1 and the iPad (decision 6). Stored; the Timeline is phase 6. */
    var timelineAcross by mutableStateOf(prefs?.getBoolean(ACROSS, false) ?: false)
        private set

    /**
     * Show graphics (decision 30, on by default): each sound page's picture appears under its four dials when a knob turns, and the Mix sheet's
     * shared pages get their pictures. Off: dials and tiles only.
     */
    var showGraphics by mutableStateOf(prefs?.getBoolean(GRAPHICS, true) ?: true)
        private set
    fun chooseShowGraphics(on: Boolean) { showGraphics = on; put(GRAPHICS, on) }


    /** Labs feel values (CLAUDE.md rule 3; added 2026-11-14, review 2026-11-28). The tab change's length in ms (the track thread mockup): default 380, 150 to 700. */
    var tabSlideMs by mutableStateOf(prefs?.getInt(TAB_MS, 380) ?: 380)
        private set
    fun chooseTabSlide(ms: Int) { tabSlideMs = ms.coerceIn(150, 700); prefs?.edit()?.putInt(TAB_MS, tabSlideMs)?.apply() }
    /** The hold menu's circle: how far it springs past its size, 0 (a plain ease-out) to 100; default 60 (the mockup's Spring). */
    var menuSpring by mutableStateOf(prefs?.getInt(MENU_SPRING, 60) ?: 60)
        private set
    fun chooseMenuSpring(v: Int) { menuSpring = v.coerceIn(0, 100); prefs?.edit()?.putInt(MENU_SPRING, menuSpring)?.apply() }
    /** The hold menu's speed in percent: 100 is the mockup's timing, 200 twice as fast; default 100, 50 to 200 (the mockup's Speed). */
    var menuSpeed by mutableStateOf(prefs?.getInt(MENU_SPEED, 100) ?: 100)
        private set
    fun chooseMenuSpeed(v: Int) { menuSpeed = v.coerceIn(50, 200); prefs?.edit()?.putInt(MENU_SPEED, menuSpeed)?.apply() }

    /**
     * Pad drag and the edge wells (CLAUDE.md rule 3; added 2026-11-15, review 2026-11-29; the iPhone's numbers, 373dadb): how far a pad is slid before it lifts (dp, 8),
     * how long a press must be before a slide counts as a drag, not a swipe (ms, 150), how long the wells take to slide in (ms, 220; out takes 72 % of it),
     * how near the pad's centre comes before a well glows (dp, 96) and before it is hot, so a drop there acts (dp, 48).
     */
    var padSlideStart by mutableStateOf(prefs?.getInt(PAD_SLIDE, 8) ?: 8)
        private set
    fun choosePadSlideStart(v: Int) { padSlideStart = v.coerceIn(4, 30); prefs?.edit()?.putInt(PAD_SLIDE, padSlideStart)?.apply() }
    var padSlideDwellMs by mutableStateOf(prefs?.getInt(PAD_DWELL, 150) ?: 150)
        private set
    fun choosePadSlideDwell(v: Int) { padSlideDwellMs = v.coerceIn(50, 400); prefs?.edit()?.putInt(PAD_DWELL, padSlideDwellMs)?.apply() }
    var wellSlideMs by mutableStateOf(prefs?.getInt(WELL_SLIDE, 220) ?: 220)
        private set
    fun chooseWellSlide(v: Int) { wellSlideMs = v.coerceIn(100, 500); prefs?.edit()?.putInt(WELL_SLIDE, wellSlideMs)?.apply() }
    var wellGlowDp by mutableStateOf(prefs?.getInt(WELL_GLOW, 96) ?: 96)
        private set
    fun chooseWellGlow(v: Int) { wellGlowDp = v.coerceIn(48, 160); prefs?.edit()?.putInt(WELL_GLOW, wellGlowDp)?.apply() }
    var wellHotDp by mutableStateOf(prefs?.getInt(WELL_HOT, 48) ?: 48)
        private set
    fun chooseWellHot(v: Int) { wellHotDp = v.coerceIn(24, 96); prefs?.edit()?.putInt(WELL_HOT, wellHotDp)?.apply() }

    /**
     * Handedness (the iPhone's setting, decision 33): right-handed, a hold menu opens to the left of the finger so the hand doesn't cover it,
     * and the sound keys sit down the right edge; left-handed, the other way round.
     */
    // two settings now (Scott, 2026-11-15): the sound keys' side and the side hold menus open to, each its own; the old handedness carries into both
    // (left-handed meant the rail on the left and menus opening to the right)
    var railLeft by mutableStateOf(prefs?.takeIf { it.contains(RAIL_LEFT) }?.getBoolean(RAIL_LEFT, false) ?: (prefs?.getBoolean(LEFT_HANDED, false) ?: false))
        private set
    var menusRight by mutableStateOf(prefs?.takeIf { it.contains(MENUS_RIGHT) }?.getBoolean(MENUS_RIGHT, false) ?: (prefs?.getBoolean(LEFT_HANDED, false) ?: false))
        private set
    fun chooseRailLeft(on: Boolean) { railLeft = on; put(RAIL_LEFT, on) }
    fun chooseMenusRight(on: Boolean) { menusRight = on; put(MENUS_RIGHT, on) }

    /**
     * Sound keys (decision 32, off by default): a rail of FX SEL ENV LFO EDIT ARP down the edge, so the phone can open the sound panel too.
     * Off, the FM-1's own keys drive. This is the switch; the rail itself is the docked panel's work.
     */
    var soundKeys by mutableStateOf(prefs?.getBoolean(SOUND_KEYS, false) ?: false)
        private set
    fun chooseSoundKeys(on: Boolean) { soundKeys = on; put(SOUND_KEYS, on) }

    fun chooseHaptics(on: Boolean) { haptics = on; put(HAPTICS, on) }
    fun choosePauseFollowing(on: Boolean) { pauseFollowing = on; put(PAUSE, on) }
    fun choosePinBottom(on: Boolean) { pinBottom = on; put(PIN, on) }
    fun choosePiano(on: Boolean) { piano = on; put(PIANO, on) }
    fun chooseTimelineAcross(on: Boolean) { timelineAcross = on; put(ACROSS, on) }
    private fun put(key: String, v: Boolean) { prefs?.edit()?.putBoolean(key, v)?.apply() }

    companion object {
        fun from(context: android.content.Context) = PhoneSettings(context.getSharedPreferences("lupe_settings", android.content.Context.MODE_PRIVATE))
        const val HAPTICS = "haptics"
        const val LEFT_HANDED = "left_handed"       // (the old one, read once to fill the two below)
        const val RAIL_LEFT = "rail_left"
        const val MENUS_RIGHT = "menus_right"
        const val SOUND_KEYS = "soundKeys"   // the same key as P4's branch, so either copy reads the other's
        const val TAB_MS = "labs_tab_slide_ms"
        const val MENU_SPRING = "labs_menu_spring"
        const val MENU_SPEED = "labs_menu_speed"
        const val PAD_SLIDE = "labs_pad_slide_start"
        const val PAD_DWELL = "labs_pad_slide_dwell"
        const val WELL_SLIDE = "labs_well_slide"
        const val WELL_GLOW = "labs_well_glow"
        const val WELL_HOT = "labs_well_hot"
        const val GRAPHICS = "show_graphics"
        const val PAUSE = "labs_pause_following"
        const val PIN = "labs_pin_bottom"
        const val PIANO = "labs_piano"
        const val ACROSS = "labs_timeline_across"
    }
}

val LocalPhoneSettings = staticCompositionLocalOf { PhoneSettings() }

/** Every haptic in the app goes through the platform's; Settings › Haptics turns them all off here. */
@Composable
fun GatedHaptics(settings: PhoneSettings, content: @Composable () -> Unit) {
    val real = LocalHapticFeedback.current
    val gated = androidx.compose.runtime.remember(real, settings) {
        object : HapticFeedback { override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) { if (settings.haptics) real.performHapticFeedback(hapticFeedbackType) } }
    }
    CompositionLocalProvider(LocalHapticFeedback provides gated, content = content)
}
