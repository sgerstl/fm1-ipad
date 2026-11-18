package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.slide.PhoneSettings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Settings (board 67): haptics start on; Labs is gone and its two built trials are fixed as Scott had them (2026-11-18). */
class SettingsTest {
    @Test fun labsValuesAreBuiltInAndHapticsOn() {
        val s = PhoneSettings(null)
        assertTrue(s.haptics)
        assertTrue("pause following after a touch: on", s.pauseFollowing)
        assertFalse("pin the sound page: off", s.pinBottom)
    }
    @Test fun changesTakeEffectAtOnce() {
        val s = PhoneSettings(null)
        s.chooseHaptics(false); s.chooseSoundKeys(false)
        assertFalse(s.haptics); assertFalse(s.soundKeys)
    }
}
