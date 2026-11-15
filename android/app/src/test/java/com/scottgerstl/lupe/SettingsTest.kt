package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.slide.PhoneSettings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Settings (board 67): haptics start on, every Labs trial starts off. */
class SettingsTest {
    @Test fun labsStartOffAndHapticsOn() {
        val s = PhoneSettings(null)
        assertTrue(s.haptics)
        assertFalse(s.pauseFollowing); assertFalse(s.pinBottom); assertFalse(s.piano); assertFalse(s.timelineAcross)
    }
    @Test fun changesTakeEffectAtOnce() {
        val s = PhoneSettings(null)
        s.chooseHaptics(false); s.choosePinBottom(true)
        assertFalse(s.haptics); assertTrue(s.pinBottom)
    }
}
