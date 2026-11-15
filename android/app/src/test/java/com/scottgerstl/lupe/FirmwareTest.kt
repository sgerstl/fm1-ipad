package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.*
import com.scottgerstl.lupe.ui.firmware.*
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FirmwareTest {
    private fun fake(scope: TestScope): FakeLupeCore {
        val dir = File("../fixtures/state")
        val scenarios = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        return FakeLupeCore(scope, scenarios, "searching").also { scope.testScheduler.advanceTimeBy(10) }
    }

    @Test fun theCoresAreaDecodesWithItsOfferAndDefaults() {
        val s = lupeJson.decodeFromString<FirmwareState>("""{"running":"M-VAVE's own firmware, V16","identity":"FM-1_016","offer":{"kind":"install","from":"mvave","key":"mvave|FM-1_016","firmware":"Skiff-Lupe-2.5.1","title":"Lupe needs other firmware","text":"This FM-1 runs …"},"state":"idle","progress":0,"message":"","inUpdateMode":false}""")
        assertEquals("install", s.offer?.kind); assertEquals("mvave|FM-1_016", s.offer?.key); assertFalse(s.active); assertFalse(s.busy)
        assertNull(lupeJson.decodeFromString<FirmwareState>("""{"state":"idle"}""").offer)
        val w = lupeJson.decodeFromString<FirmwareState>("""{"state":"writing","progress":0.5,"installing":"Skiff-Lupe 2.5.1"}""")
        assertTrue(w.busy); assertTrue(w.active)
        assertFalse(lupeJson.decodeFromString<FirmwareState>("""{"state":"failed","inUpdateMode":true}""").busy)     // failed: the cover stays but it can be left
        assertFalse(lupeJson.decodeFromString<FirmwareState>("""{"state":"done"}""").busy)
    }

    @Test fun theIntentsTravelAsTheCoreTakesThem() {
        assertEquals("""{"intent":"firmwareInstall","which":"Skiff-Lupe-2.5.1","confirmed":true,"battery":63,"charging":false}""",
            lupeJson.encodeToString(Intent.serializer(), FirmwareInstall("Skiff-Lupe-2.5.1", confirmed = true, battery = 63, charging = false)))
        assertEquals("""{"intent":"firmwareInstall","confirmed":true,"skipBackup":true}""", lupeJson.encodeToString(Intent.serializer(), FirmwareInstall(confirmed = true, skipBackup = true)))
        assertEquals("""{"intent":"firmwareCancelOffer"}""", lupeJson.encodeToString(Intent.serializer(), FirmwareCancelOffer))
        assertEquals("""{"intent":"firmwareClose"}""", lupeJson.encodeToString(Intent.serializer(), FirmwareClose))
    }

    @Test fun theBatteryGateAndTheWordsOnTheKeys() {
        assertNotNull(batteryRefusal(23, charging = false)); assertTrue(batteryRefusal(23, false)!!.contains("23%"))
        assertNull(batteryRefusal(23, charging = true)); assertNull(batteryRefusal(30, false)); assertNull(batteryRefusal(null, false))
        assertEquals("Install Skiff-Lupe", offerKeyTitle("install")); assertEquals("Install the update", offerKeyTitle("update")); assertEquals("Finish installing", offerKeyTitle("finish"))
        assertEquals("Skiff-Lupe 2.5.1", firmwareWords("Skiff-Lupe-2.5.1")); assertEquals("Skiff-Lupe 2.5.1", firmwareWords(null))
        assertEquals("Writing the firmware", doing("writing", null)); assertEquals("Restarting the FM-1", doing("restarting", null))
    }

    @Test fun anUnconfirmedOrLowBatteryInstallIsRefusedAndNothingStarts() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(FirmwareInstall()); advanceTimeBy(10)
        assertEquals("idle", core.firmware.value.state)
        core.send(FirmwareInstall(confirmed = true, battery = 12, charging = false)); advanceTimeBy(10)
        assertEquals("idle", core.firmware.value.state); assertTrue(core.notice.value.text.contains("12%"))
    }

    @Test fun aConfirmedInstallRunsToDoneWithABackupAndCloseReturnsToIdle() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.showFirmwareOffer("install")
        core.send(FirmwareInstall("Skiff-Lupe-2.5.1", confirmed = true, battery = 80, charging = true))
        val seen = mutableSetOf<String>(); var last = 0.0; var back = true
        repeat(60) { advanceTimeBy(100); val s = core.firmware.value; seen += s.state; if (s.progress < last - 1e-9) back = false; last = s.progress }
        assertTrue(seen.containsAll(listOf("downloading", "backingUp", "staging", "writing", "restarting", "done"))); assertTrue(back)       // the progress never goes back
        assertEquals("done", core.firmware.value.state); assertNotNull(core.firmware.value.backup); assertNull(core.firmware.value.offer)
        core.send(FirmwareClose); advanceTimeBy(10)
        assertEquals("idle", core.firmware.value.state)
    }

    @Test fun aCutInstallFailsInUpdateModeAndNotNowHidesTheOffer() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.showFirmwareOffer("update"); assertNotNull(core.firmware.value.offer)
        core.send(FirmwareCancelOffer); advanceTimeBy(10); assertNull(core.firmware.value.offer)
        core.showFirmwareOffer("install"); core.failAt = "writing"
        core.send(FirmwareInstall(confirmed = true, battery = 90, charging = true))
        repeat(60) { advanceTimeBy(100) }
        assertEquals("failed", core.firmware.value.state); assertTrue(core.firmware.value.inUpdateMode)
    }
}

class FirmwareNameTest {
    private fun fw(running: String?, kind: String? = null, from: String = "") = FirmwareState(running = running, offer = kind?.let { FirmwareOffer(it, from) })
    @Test fun theMenuNamesTheFirmwareAndWhatCanBeDone() {
        assertEquals("Skiff-Lupe 2.5.1 · up to date", firmwareLine(fw("v2.5.1")))                                  // the core gave only a version, nothing on offer
        assertEquals("Skiff-Lupe 2.5.1 · up to date", firmwareLine(fw("Skiff-Lupe 2.5.1")))
        assertEquals("Skiff 2.6 · Skiff-Lupe available", firmwareLine(fw("v2.6.0".replace(".0", ""), "install", "stockSkiff")))
        assertEquals("SLOOP 2.8.4 · Skiff-Lupe available", firmwareLine(fw("2.8.4", "install", "sloop")))
        assertEquals("Skiff-Lupe 2.4 · Skiff-Lupe available", firmwareLine(fw("2.4", "update", "olderLupe")))
        assertEquals("M-VAVE's own firmware, V16 · Skiff-Lupe available", firmwareLine(fw("M-VAVE's own firmware, V16", "install", "mvave")))
        assertEquals("What the FM-1 runs, and Skiff-Lupe", firmwareLine(FirmwareState()))
    }
}
