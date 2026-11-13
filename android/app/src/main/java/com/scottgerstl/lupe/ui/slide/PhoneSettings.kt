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
    /** Labs: the bottom half holds your page for 3 s after you touch it (decision 3's "pause after a phone touch"). */
    var pauseFollowing by mutableStateOf(prefs?.getBoolean(PAUSE, false) ?: false)
        private set
    /** Labs: the bottom half stops following the FM-1's page (decision 3's "pin the bottom half's page"). */
    var pinBottom by mutableStateOf(prefs?.getBoolean(PIN, false) ?: false)
        private set
    /** Labs: a one-octave piano under the grid (decision 5). Stored; the piano itself isn't built yet. */
    var piano by mutableStateOf(prefs?.getBoolean(PIANO, false) ?: false)
        private set
    /** Labs: the Timeline with time across, as the FM-1 and the iPad (decision 6). Stored; the Timeline is phase 6. */
    var timelineAcross by mutableStateOf(prefs?.getBoolean(ACROSS, false) ?: false)
        private set

    /** Labs (decision 20): a sound key adds the sound page under the steps, and the whole bottom area is one vertical scroll. Off: today's layout. */
    var soundStack by mutableStateOf(prefs?.getBoolean(STACK, false) ?: false)
        private set

    fun chooseSoundStack(on: Boolean) { soundStack = on; put(STACK, on) }
    fun chooseHaptics(on: Boolean) { haptics = on; put(HAPTICS, on) }
    fun choosePauseFollowing(on: Boolean) { pauseFollowing = on; put(PAUSE, on) }
    fun choosePinBottom(on: Boolean) { pinBottom = on; put(PIN, on) }
    fun choosePiano(on: Boolean) { piano = on; put(PIANO, on) }
    fun chooseTimelineAcross(on: Boolean) { timelineAcross = on; put(ACROSS, on) }
    private fun put(key: String, v: Boolean) { prefs?.edit()?.putBoolean(key, v)?.apply() }

    companion object {
        fun from(context: android.content.Context) = PhoneSettings(context.getSharedPreferences("lupe_settings", android.content.Context.MODE_PRIVATE))
        const val HAPTICS = "haptics"
        const val PAUSE = "labs_pause_following"
        const val PIN = "labs_pin_bottom"
        const val PIANO = "labs_piano"
        const val ACROSS = "labs_timeline_across"
        const val STACK = "labs_sound_stack"
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
