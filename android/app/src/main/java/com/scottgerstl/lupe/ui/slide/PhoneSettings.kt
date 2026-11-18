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
    init {
        // 2026-11-17: the Labs sliders were cleared (Scott: start over; add back one by one when he asks). Any value a slider stored is dropped so
        // the phone runs the defaults below; the properties stay, read-only from the UI, so the code keeps one place for each value.
        prefs?.edit()?.apply { RETIRED_TUNING.forEach { remove(it) } }?.apply()
    }

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
     * Hybrid motion (design/hybrid-ui/spec.md §5; CLAUDE.md rule 3: added 2026-11-17, review 2026-12-01). The spatial spring's bounce in percent (25),
     * the at-the-finger length (200 ms), sheets and docked panels (300 ms), the 8-step page flip (280 ms), and how far a press squashes (92 %).
     */
    var motionBounce by mutableStateOf(prefs?.getInt(M_BOUNCE, 25) ?: 25)
        private set
    fun chooseMotionBounce(v: Int) { motionBounce = v.coerceIn(0, 50); prefs?.edit()?.putInt(M_BOUNCE, motionBounce)?.apply() }
    var motionFingerMs by mutableStateOf(prefs?.getInt(M_FINGER, 200) ?: 200)
        private set
    fun chooseMotionFinger(v: Int) { motionFingerMs = v.coerceIn(100, 400); prefs?.edit()?.putInt(M_FINGER, motionFingerMs)?.apply() }
    var motionPanelMs by mutableStateOf(prefs?.getInt(M_PANEL, 300) ?: 300)
        private set
    fun chooseMotionPanel(v: Int) { motionPanelMs = v.coerceIn(150, 480); prefs?.edit()?.putInt(M_PANEL, motionPanelMs)?.apply() }
    var motionPageFlipMs by mutableStateOf(prefs?.getInt(M_FLIP, 280) ?: 280)
        private set
    fun chooseMotionPageFlip(v: Int) { motionPageFlipMs = v.coerceIn(150, 480); prefs?.edit()?.putInt(M_FLIP, motionPageFlipMs)?.apply() }
    var motionPressScale by mutableStateOf(prefs?.getInt(M_PRESS, 92) ?: 92)
        private set
    /**
     * Expressive springs (Scott, 2026-11-17, round 3: "the animation should show the transformation from one shape to another"). Starting values
     * are Material 3 Expressive's own (androidx compose material3 `ExpressiveMotionTokens`: default spatial damping 0.8, stiffness 380; fast
     * spatial 0.6, 800), and the squash-and-stretch that makes a shape change read (6 %). Added 2026-11-17, review 2026-12-01.
     */
    var spatialStiffness by mutableStateOf(prefs?.getInt(M_SP_STIFF, 380) ?: 380)
        private set
    fun chooseSpatialStiffness(v: Int) { spatialStiffness = v.coerceIn(100, 1500); prefs?.edit()?.putInt(M_SP_STIFF, spatialStiffness)?.apply() }
    var spatialDamping by mutableStateOf(prefs?.getInt(M_SP_DAMP, 80) ?: 80)
        private set
    fun chooseSpatialDamping(v: Int) { spatialDamping = v.coerceIn(30, 100); prefs?.edit()?.putInt(M_SP_DAMP, spatialDamping)?.apply() }
    var fastStiffness by mutableStateOf(prefs?.getInt(M_FAST_STIFF, 800) ?: 800)
        private set
    fun chooseFastStiffness(v: Int) { fastStiffness = v.coerceIn(200, 3000); prefs?.edit()?.putInt(M_FAST_STIFF, fastStiffness)?.apply() }
    var squashPct by mutableStateOf(prefs?.getInt(M_SQUASH, 6) ?: 6)
        private set
    fun chooseSquash(v: Int) { squashPct = v.coerceIn(0, 15); prefs?.edit()?.putInt(M_SQUASH, squashPct)?.apply() }
    /** The hit bounce (Scott, 2026-11-17): how far a hit grows as its step sounds (112 %), its rise (50 ms) and its spring back (200 ms). Added 2026-11-17, review 2026-12-01. */
    var bounceScalePct by mutableStateOf(prefs?.getInt(B_SCALE, 112) ?: 112)
        private set
    fun chooseBounceScale(v: Int) { bounceScalePct = v.coerceIn(100, 130); prefs?.edit()?.putInt(B_SCALE, bounceScalePct)?.apply() }
    var bounceUpMs by mutableStateOf(prefs?.getInt(B_UP, 50) ?: 50)
        private set
    fun chooseBounceUp(v: Int) { bounceUpMs = v.coerceIn(10, 150); prefs?.edit()?.putInt(B_UP, bounceUpMs)?.apply() }
    var bounceBackMs by mutableStateOf(prefs?.getInt(B_BACK, 200) ?: 200)
        private set
    fun chooseBounceBack(v: Int) { bounceBackMs = v.coerceIn(60, 500); prefs?.edit()?.putInt(B_BACK, bounceBackMs)?.apply() }
    fun chooseMotionPress(v: Int) { motionPressScale = v.coerceIn(80, 100); prefs?.edit()?.putInt(M_PRESS, motionPressScale)?.apply() }

    /**
     * Pad drag and the edge wells (CLAUDE.md rule 3; added 2026-11-15, review 2026-11-29; the iPhone's numbers, 373dadb): how far a pad is slid before it lifts (dp, 8),
     * how long a press must be before a slide counts as a drag, not a swipe (ms, 150), how long the wells take to slide in (ms, 220; out takes 72 % of it),
     * how far out a well starts to glow (dp, 200; the glow rises steadily to full at the hot point) and how near before it is hot, so a drop there acts (dp, 64).
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
    /** The glow starts at this share of the screen's height (top and bottom wells) or width (the sides), in percent: 45 (20–70). */
    var wellGlowPct by mutableStateOf(prefs?.getInt(WELL_GLOW, 45) ?: 45)
        private set
    fun chooseWellGlow(v: Int) { wellGlowPct = v.coerceIn(20, 70); prefs?.edit()?.putInt(WELL_GLOW, wellGlowPct)?.apply() }
    // the side wells (Edit, Duplicate) light up sooner, since the drag crosses much more width: about 45 % of the width out, hot at 96 dp (the top and bottom: 45 % of the height, 64 dp)
    var wellSideGlowPct by mutableStateOf(prefs?.getInt(WELL_SIDE_GLOW, 45) ?: 45)
        private set
    fun chooseWellSideGlow(v: Int) { wellSideGlowPct = v.coerceIn(20, 70); prefs?.edit()?.putInt(WELL_SIDE_GLOW, wellSideGlowPct)?.apply() }
    var wellSideHotDp by mutableStateOf(prefs?.getInt(WELL_SIDE_HOT, 96) ?: 96)
        private set
    fun chooseWellSideHot(v: Int) { wellSideHotDp = v.coerceIn(32, 192); prefs?.edit()?.putInt(WELL_SIDE_HOT, wellSideHotDp)?.apply() }
    var wellHotDp by mutableStateOf(prefs?.getInt(WELL_HOT, 64) ?: 64)
        private set
    fun chooseWellHot(v: Int) { wellHotDp = v.coerceIn(24, 128); prefs?.edit()?.putInt(WELL_HOT, wellHotDp)?.apply() }

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

    /**
     * Offer played phrases (Scott, 2026-11-18: "the constant popping up of 'you just played 15 notes'… always blocks shit I want to see"): how
     * the FM-1's FREE TAKE offer shows. [TAKE_CHIP] a small chip by Record (the default), [TAKE_POPUP] the strip over Edit (as before), [TAKE_OFF] nothing.
     */
    var takeOffer by mutableStateOf(prefs?.getInt(TAKE_OFFER, TAKE_CHIP) ?: TAKE_CHIP)
        private set
    fun chooseTakeOffer(v: Int) { takeOffer = v.coerceIn(TAKE_CHIP, TAKE_OFF); prefs?.edit()?.putInt(TAKE_OFFER, takeOffer)?.apply() }
    /** The kit hint ("Hold a hit to edit it") has been shown: once per install. */
    var kitHintShown by mutableStateOf(prefs?.getBoolean(KIT_HINT, false) ?: false)
        private set
    fun markKitHintShown() { if (!kitHintShown) { kitHintShown = true; put(KIT_HINT, true) } }

    /**
     * Labs › Tab motion (temporary, Scott 2026-11-18; out again once he settles): the tab fade-through's style (Staggered, the default, is
     * Material's: out, then in from 0.92; Now is the old overlap from 0.98) and a speed for every duration of the tab change (1×, 1.3×, 1.6×).
     */
    var tabStaggered by mutableStateOf(prefs?.getBoolean(TAB_STAGGER, true) ?: true)
        private set
    var tabSpeedIndex by mutableStateOf((prefs?.getInt(TAB_SPEED, 0) ?: 0).coerceIn(0, TAB_SPEEDS.lastIndex))
        private set
    val tabSpeed: Float get() = TAB_SPEEDS[tabSpeedIndex]
    fun chooseTabStaggered(on: Boolean) { tabStaggered = on; put(TAB_STAGGER, on) }
    fun chooseTabSpeed(i: Int) { tabSpeedIndex = i.coerceIn(0, TAB_SPEEDS.lastIndex); prefs?.edit()?.putInt(TAB_SPEED, tabSpeedIndex)?.apply() }

    fun chooseHaptics(on: Boolean) { haptics = on; put(HAPTICS, on) }
    fun choosePauseFollowing(on: Boolean) { pauseFollowing = on; put(PAUSE, on) }
    fun choosePinBottom(on: Boolean) { pinBottom = on; put(PIN, on) }
    fun choosePiano(on: Boolean) { piano = on; put(PIANO, on) }
    fun chooseTimelineAcross(on: Boolean) { timelineAcross = on; put(ACROSS, on) }
    private fun put(key: String, v: Boolean) { prefs?.edit()?.putBoolean(key, v)?.apply() }

    companion object {
        fun from(context: android.content.Context) = PhoneSettings(context.getSharedPreferences("lupe_settings", android.content.Context.MODE_PRIVATE))
        /** The tuning keys retired from Labs on 2026-11-17; their stored values are removed so the defaults rule. */
        val RETIRED_TUNING = listOf("labs_tab_slide_ms", "labs_menu_spring", "labs_menu_speed", "labs_pad_slide_start", "labs_pad_slide_dwell", "labs_well_slide",
            "labs_well_side_glow_pct", "labs_well_side_hot", "labs_well_glow_pct", "labs_well_hot2", "labs_motion_bounce", "labs_motion_finger_ms", "labs_motion_panel_ms",
            "labs_motion_page_flip_ms", "labs_motion_press_scale", "labs_spatial_stiffness", "labs_spatial_damping", "labs_fast_spatial_stiffness", "labs_squash_pct",
            "labs_bounce_scale", "labs_bounce_up_ms", "labs_bounce_back_ms")
        const val HAPTICS = "haptics"
        const val TAB_STAGGER = "labs_tab_staggered"
        const val TAB_SPEED = "labs_tab_speed"
        val TAB_SPEEDS = listOf(1f, 1.3f, 1.6f)
        const val TAKE_OFFER = "take_offer"
        const val TAKE_CHIP = 0
        const val TAKE_POPUP = 1
        const val TAKE_OFF = 2
        const val KIT_HINT = "kit_hint_shown"
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
        const val WELL_SIDE_GLOW = "labs_well_side_glow_pct"
        const val WELL_SIDE_HOT = "labs_well_side_hot"
        const val WELL_GLOW = "labs_well_glow_pct"      // (new keys with the new defaults, 2026-11-15)
        const val WELL_HOT = "labs_well_hot2"
        const val GRAPHICS = "show_graphics"
        const val M_BOUNCE = "labs_motion_bounce"
        const val M_FINGER = "labs_motion_finger_ms"
        const val M_PANEL = "labs_motion_panel_ms"
        const val M_FLIP = "labs_motion_page_flip_ms"
        const val M_PRESS = "labs_motion_press_scale"
        const val M_SP_STIFF = "labs_spatial_stiffness"
        const val M_SP_DAMP = "labs_spatial_damping"
        const val M_FAST_STIFF = "labs_fast_spatial_stiffness"
        const val M_SQUASH = "labs_squash_pct"
        const val B_SCALE = "labs_bounce_scale"
        const val B_UP = "labs_bounce_up_ms"
        const val B_BACK = "labs_bounce_back_ms"
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
