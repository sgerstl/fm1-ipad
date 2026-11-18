package com.scottgerstl.lupe

import com.scottgerstl.lupe.audio.OutputKind
import com.scottgerstl.lupe.audio.ThroughState
import com.scottgerstl.lupe.ui.shell.throughNeedsHand
import com.scottgerstl.lupe.ui.shell.throughStartNote
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/** Play-through's messages now Settings' Audio section is gone (Scott, 2026-11-18). */
class ThroughMessagesTest {
    @Test fun needsAHandOnlyWhileOnAndStuck() {
        assertNotNull(throughNeedsHand(true, ThroughState.NoInput))
        assertNotNull(throughNeedsHand(true, ThroughState.NeedsPermission))
        assertNull(throughNeedsHand(false, ThroughState.NoInput))                                  // turned off: the refusal leaves
        assertNull(throughNeedsHand(true, ThroughState.Playing("Phone speaker", OutputKind.Speaker)))
    }
    @Test fun theBluetoothNoteShowsOnceWhenItStartsOnBluetooth() {
        assertNotNull(throughStartNote(null, OutputKind.Bluetooth))
        assertNotNull(throughStartNote(OutputKind.Speaker, OutputKind.BluetoothLe))               // moved to Bluetooth while playing
        assertNull(throughStartNote(OutputKind.Bluetooth, OutputKind.Bluetooth))                  // still on it: not again
        assertNull(throughStartNote(null, OutputKind.Wired))
        assertNull(throughStartNote(OutputKind.Bluetooth, null))
    }
}
