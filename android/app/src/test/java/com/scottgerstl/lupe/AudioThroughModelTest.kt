package com.scottgerstl.lupe

import com.scottgerstl.lupe.audio.AudioDev
import com.scottgerstl.lupe.audio.OutputKind
import com.scottgerstl.lupe.audio.ThroughModel
import com.scottgerstl.lupe.audio.ThroughState
import com.scottgerstl.lupe.audio.ThroughStats
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Audio through's pure parts: the FM-1's input, the output kinds, the engine's stats array, the words shown. */
class AudioThroughModelTest {
    private val mic = AudioDev(1, 15, "Pixel mic", true)
    private val fm1 = AudioDev(7, ThroughModel.TYPE_USB_DEVICE, "USB-Audio - Felucca", true)
    private val otherUsb = AudioDev(9, ThroughModel.TYPE_USB_DEVICE, "USB-Audio - Something", true)
    private val usbOut = AudioDev(8, ThroughModel.TYPE_USB_DEVICE, "USB-Audio - Felucca", false)

    @Test fun picksFeluccaOverOtherUsbInputs() {
        assertEquals(fm1, ThroughModel.pickFm1(listOf(mic, otherUsb, fm1, usbOut)))
    }

    @Test fun fallsBackToAnyUsbInput() {
        assertEquals(otherUsb, ThroughModel.pickFm1(listOf(mic, otherUsb)))
    }

    @Test fun neverPicksThePhonesMicrophoneOrAnOutput() {
        // playing the phone's own microphone to its speaker would howl (the iPad's rule)
        assertNull(ThroughModel.pickFm1(listOf(mic, usbOut)))
        assertNull(ThroughModel.pickFm1(emptyList()))
    }

    @Test fun outputKindsAndNames() {
        assertEquals(OutputKind.Speaker, ThroughModel.kind(ThroughModel.TYPE_BUILTIN_SPEAKER))
        assertEquals(OutputKind.Wired, ThroughModel.kind(ThroughModel.TYPE_WIRED_HEADPHONES))
        assertEquals(OutputKind.Bluetooth, ThroughModel.kind(ThroughModel.TYPE_BLUETOOTH_A2DP))
        assertEquals(OutputKind.BluetoothLe, ThroughModel.kind(ThroughModel.TYPE_BLE_HEADSET))
        assertEquals("Phone speaker", ThroughModel.outputName(ThroughModel.TYPE_BUILTIN_SPEAKER, "Pixel 10 Pro"))
        assertEquals("Pixel Buds Pro 2", ThroughModel.outputName(ThroughModel.TYPE_BLE_HEADSET, "Pixel Buds Pro 2"))
        assertEquals("Bluetooth headphones", ThroughModel.outputName(ThroughModel.TYPE_BLUETOOTH_A2DP, ""))
    }

    @Test fun bluetoothSaysItAddsDelayAndWiredDoesNot() {
        assertNotNull(ThroughModel.bluetoothNote(OutputKind.Bluetooth))
        assertNotNull(ThroughModel.bluetoothNote(OutputKind.BluetoothLe))
        assertNull(ThroughModel.bluetoothNote(OutputKind.Wired))
        assertNull(ThroughModel.bluetoothNote(OutputKind.Speaker))
    }

    @Test fun statsArrayInTheEnginesOrder() {
        val a = DoubleArray(ThroughStats.COUNT)
        a[0] = 1.0; a[2] = 48000.0; a[3] = 48000.0; a[4] = 1.0; a[7] = 240.0; a[15] = 23.6; a[19] = 2.0; a[22] = 5.0; a[23] = 1.0; a[31] = 0.5; a[32] = 2.0; a[33] = -899.0; a[34] = 1.0
        val s = ThroughStats.from(a)
        assertTrue(s.running); assertTrue(s.inExclusive)
        assertEquals(48000, s.inRate); assertEquals(240, s.outBurst)
        assertEquals(23.6, s.totalMs, 1e-9)
        assertEquals(2L, s.underruns)
        assertEquals(6L, s.phoneDropouts)
        assertEquals(0.5, s.peak, 1e-9)
        assertEquals(2, s.tsFlags); assertEquals(-899, s.lastError); assertTrue(s.lastErrorInput)
        // a short array (an older engine) reads as zeros, not a crash
        assertEquals(0, ThroughStats.from(DoubleArray(3)).outBurst)
    }

    @Test fun summaryLines() {
        val s = ThroughStats(running = true, totalMs = 23.6)
        assertEquals("Off", ThroughModel.summary(ThroughState.Off, s))
        assertEquals("Playing on Wired headphones · 24\u00A0ms", ThroughModel.summary(ThroughState.Playing("Wired headphones", OutputKind.Wired), s))
        assertEquals("Playing on Buds · 24\u00A0ms + Bluetooth", ThroughModel.summary(ThroughState.Playing("Buds", OutputKind.Bluetooth), s))
        // no timestamp yet: no number rather than a wrong one
        assertEquals("Playing on Phone speaker", ThroughModel.summary(ThroughState.Playing("Phone speaker", OutputKind.Speaker), s.copy(totalMs = -1.0)))
    }

    @Test fun actionOnlyWhenThereIsSomethingToDo() {
        assertNull(ThroughModel.action(ThroughState.Playing("Phone speaker", OutputKind.Speaker)))
        assertNull(ThroughModel.action(ThroughState.Off))
        assertNotNull(ThroughModel.action(ThroughState.NoInput))
        assertNotNull(ThroughModel.action(ThroughState.NeedsPermission))
    }

    @Test fun detailsLine() {
        val s = ThroughStats(running = true, inRate = 44100, outRate = 48000, inExclusive = true, outExclusive = false, outLowLatency = true,
            inLatencyMs = 4.0, ringMs = 3.0, filterMs = 0.4, outLatencyMs = 10.0, outBurst = 96, ratioPpm = 412.0, underruns = 1, zeroRuns = 3)
        val d = ThroughModel.details(s)
        assertTrue(d, d.startsWith("44.1 → 48 kHz · in exclusive, out shared"))
        assertTrue(d, d.contains("Lupe gaps 1 · phone gaps 3"))
        assertTrue(d, d.contains("+412 ppm"))
        assertTrue(d, d.contains("timestamps –/–"))
        assertTrue(d, !d.contains("restarts"))
        assertTrue(ThroughModel.details(s.copy(tsFlags = 3, restarts = 2)).contains("timestamps in/out · restarts 2"))
        assertEquals("Stopped", ThroughModel.details(ThroughStats()))
    }
}
