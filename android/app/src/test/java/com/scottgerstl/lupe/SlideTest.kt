package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.slide.SlideDirection
import com.scottgerstl.lupe.ui.slide.SlideSettings
import com.scottgerstl.lupe.ui.slide.takes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The iPad's ColumnSlidePan rule (ios/FM1/Knobs.swift): which first movement begins a slide, per setting. */
class SlideTest {
    @Test fun sidewaysTakesOnlyAcross() { assertTrue(SlideDirection.Sideways.takes(up = false)); assertFalse(SlideDirection.Sideways.takes(up = true)) }
    @Test fun upDownTakesOnlyUpDown() { assertTrue(SlideDirection.UpDown.takes(up = true)); assertFalse(SlideDirection.UpDown.takes(up = false)) }
    @Test fun bothTakesEither() { assertTrue(SlideDirection.Both.takes(true)); assertTrue(SlideDirection.Both.takes(false)) }
    @Test fun phoneDefaultsToUpDownWithTheMagnifierOn() {
        val s = SlideSettings(null)
        assertEquals(SlideDirection.UpDown, s.direction); assertTrue(s.magnifier)
    }
    @Test fun settingNamesParse() {
        assertEquals(SlideDirection.Sideways, SlideDirection.from("sideways"))
        assertEquals(SlideDirection.UpDown, SlideDirection.from("updown"))
        assertEquals(SlideDirection.Both, SlideDirection.from("Both"))
        assertEquals(null, SlideDirection.from("diagonal"))
    }
}
