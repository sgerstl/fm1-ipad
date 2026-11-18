package com.scottgerstl.lupe

import androidx.test.core.app.ApplicationProvider
import com.scottgerstl.lupe.ui.settings.segmentedFits
import com.scottgerstl.lupe.ui.slide.PhoneSettings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Settings (board 67): haptics on; Following's two switches (Scott, 2026-11-18) start as he had them and persist. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
class SettingsTest {
    private fun prefs() = ApplicationProvider.getApplicationContext<android.app.Application>().getSharedPreferences("settings_test", 0)

    @Test fun followingStartsAsScottHadIt() {
        val s = PhoneSettings(null)
        assertTrue(s.haptics)
        assertTrue("pause following after a touch: on", s.pauseFollowing)
        assertFalse("pin the sound page: off", s.pinBottom)
    }

    @Test fun followingPersists() {
        val p = prefs(); p.edit().clear().commit()
        PhoneSettings(p).apply { choosePauseFollowing(false); choosePinBottom(true) }
        val again = PhoneSettings(p)
        assertFalse(again.pauseFollowing); assertTrue(again.pinBottom)
    }

    @Test fun optionsSizeToTheirLabelsUntilTheyDontFit() {
        // "Left", "Right" at about 30 and 36 dp: 72 each (the least) side by side
        assertTrue(segmentedFits(listOf(30f, 36f), 560f))
        // three long labels at 200 % font: they don't fit, so the row shares the width and labels wrap
        assertFalse(segmentedFits(listOf(180f, 170f, 120f), 560f))
        assertTrue(segmentedFits(listOf(90f, 70f, 40f), 560f))
    }
}
