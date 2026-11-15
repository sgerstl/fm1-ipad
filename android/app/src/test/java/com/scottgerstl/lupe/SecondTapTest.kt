package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.secondTapOpensMenu
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Batch item 10: a second tap on the already selected pad opens its menu, only while stopped. */
class SecondTapTest {
    @Test fun itOpensOnlyOnTheSelectedPadWhileStopped() {
        assertTrue(secondTapOpensMenu(alreadySelected = true, transportPlaying = false, selectMode = false))
        assertFalse(secondTapOpensMenu(alreadySelected = false, transportPlaying = false, selectMode = false))   // the first tap selects
        assertFalse(secondTapOpensMenu(alreadySelected = true, transportPlaying = true, selectMode = false))     // playing: taps keep queuing
        assertFalse(secondTapOpensMenu(alreadySelected = true, transportPlaying = false, selectMode = true))
    }
}
