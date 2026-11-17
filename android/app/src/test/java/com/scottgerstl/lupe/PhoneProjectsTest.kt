package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.PatternUse
import com.scottgerstl.lupe.core.PatternsState
import com.scottgerstl.lupe.core.PhoneHome
import com.scottgerstl.lupe.core.PhoneProject
import com.scottgerstl.lupe.core.PhoneProjectStore
import com.scottgerstl.lupe.core.PlayingSource
import com.scottgerstl.lupe.core.PoolPattern
import com.scottgerstl.lupe.core.ProjectSlot
import com.scottgerstl.lupe.core.ProjectsState
import com.scottgerstl.lupe.core.TransferEvent
import com.scottgerstl.lupe.core.lupeJson
import com.scottgerstl.lupe.core.playingNow
import com.scottgerstl.lupe.core.poolLine
import com.scottgerstl.lupe.core.skiffName
import com.scottgerstl.lupe.core.transferWords
import com.scottgerstl.lupe.ui.projects.ProjectSlotUi
import com.scottgerstl.lupe.ui.projects.copyNeedsAsking
import com.scottgerstl.lupe.ui.projects.copyWords
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.time.Instant

/** Phone projects (2026-11-17): the store's files, the Playing now row's words, the pool line, and what a failed transfer says. */
class PhoneProjectsTest {
    @get:Rule val tmp = TemporaryFolder()

    private var clock = Instant.parse("2026-11-17T09:28:00.456Z")
    private fun store(dir: File = tmp.root) = PhoneProjectStore(dir) { clock.also { clock = clock.plusSeconds(60) } }
    private fun skiff(patterns: Int): JsonElement =
        lupeJson.parseToJsonElement("""{"record":"AAEC","patterns":[${(1..patterns).joinToString(",") { """{"id":$it,"data":"AQ=="}""" }}],"firmware":"2.5.1"}""")

    // ---- the store

    @Test fun saveWritesAFileTheIpadCanReadAndReloads() {
        val s = store()
        val p = s.save("Night Drive", skiff(3), "fp1")
        assertEquals(listOf("Night Drive"), s.projects.map { it.name })
        assertEquals(3, p.patternCount)
        assertEquals("2026-11-17T09:28:00Z", p.saved)        // to the second: the iPad's ISO 8601 decoder takes no fractions
        val text = File(tmp.root, "${p.id}.json").readText()
        assertTrue(text.contains("\"format\": \"lupe-skiff-project\""))
        assertTrue(text.contains("\"version\": 1"))
        // a fresh store finds it again
        val again = store()
        assertEquals(p.copy(), again.get(p.id))
    }

    @Test fun overwriteKeepsTheNameAndIdAndReplacesTheMusic() {
        val s = store()
        val p = s.save("Night Drive", skiff(1))
        val q = s.overwrite(p.id, skiff(5), "fp2")!!
        assertEquals(p.id, q.id); assertEquals("Night Drive", q.name); assertEquals(5, q.patternCount); assertEquals("fp2", q.baseline)
        assertEquals(1, s.projects.size)
    }

    @Test fun renameDuplicateAndDelete() {
        val s = store()
        val p = s.save("Night Drive", skiff(2))
        assertTrue(s.rename(p.id, "  Dawn Run  "))
        assertEquals("Dawn Run", s.get(p.id)!!.name)
        assertFalse(s.rename(p.id, "   "))                     // a blank name changes nothing
        assertEquals("Dawn Run", s.get(p.id)!!.name)
        val d = s.duplicate(p.id)!!
        assertEquals("Dawn Run copy", d.name); assertEquals(2, d.patternCount); assertEquals("", d.baseline)
        assertEquals("Dawn Run copy 2", s.duplicate(p.id)!!.name)
        s.home = PhoneHome(p.id, "DAWN RUN", null)
        s.delete(p.id)
        assertNull(s.get(p.id))
        assertNull(s.home)                                     // deleting the playing music's file forgets its home
        assertEquals(2, s.projects.size)
    }

    @Test fun nextNameSkipsNumbersInUse() {
        val s = store()
        assertEquals("Project 1", s.nextName())
        s.save("Project 2", skiff(0))
        assertEquals("Project 3", s.nextName())                // count + 1 = 2 is taken
        s.save("", skiff(0))                                   // a blank name takes the next one
        assertEquals(listOf("Project 3", "Project 2"), s.projects.map { it.name })
        assertEquals("Project 4", s.nextName())
    }

    @Test fun namesAreTrimmedTo40() {
        val s = store()
        assertEquals(40, s.save("x".repeat(60), skiff(0)).name.length)
    }

    @Test fun safetyCopiesKeepTheNewestFiveAndARenameMakesOneAProject() {
        val s = store()
        repeat(7) { s.keepSafetyCopy("Before opening $it", skiff(1)) }
        assertEquals(PhoneProjectStore.KEPT_SAFETY_COPIES, s.safetyCopies.size)
        assertEquals("Before opening 6", s.safetyCopies.first().name)
        assertTrue(s.projects.isEmpty())
        val c = s.safetyCopies.first()
        s.rename(c.id, "Kept")
        assertEquals(listOf("Kept"), s.projects.map { it.name })
        assertFalse(s.get(c.id)!!.isSafetyCopy)
        assertFalse(File(tmp.root, "Safety copies/${c.id}.json").exists())   // it moved folders
        assertEquals(4, s.safetyCopies.size)
    }

    @Test fun anIpadFileOpensHere() {
        // as ios/FM1/Projects.swift writes it (JSONEncoder, sorted keys, .iso8601 dates)
        val id = "0B5A3C2E-9D1F-4E8A-A1B2-C3D4E5F60718"
        File(tmp.root, "$id.json").writeText("""
            {"baseline":"abc","format":"lupe-skiff-project","id":"$id","isSafetyCopy":false,"name":"From the iPad",
             "saved":"2026-11-16T20:00:00Z","skiff":{"firmware":"2.5.1","patterns":[{"data":"AQ==","id":4}],"record":"AAEC"},"version":1}
        """.trimIndent())
        File(tmp.root, "sloop.json").writeText("""{"format":"sloop-project","name":"old","saved":"2026-01-01T00:00:00Z","skiff":{}}""")
        val s = store()
        assertEquals(listOf("From the iPad"), s.projects.map { it.name })
        assertEquals(1, s.projects.single().patternCount)
    }

    @Test fun homeLastsAcrossLaunchesOnlyWhileItsFileDoes() {
        val s = store()
        val p = s.save("Night Drive", skiff(1))
        s.home = PhoneHome(p.id, "NIGHT DRIVE", 1)
        assertEquals(PhoneHome(p.id, "NIGHT DRIVE", 1), store().home)
        File(tmp.root, "${p.id}.json").delete()
        assertNull(store().home)
    }

    @Test fun skiffNameIsWhatTheFm1Shows() {
        assertEquals("NIGHT DRIVE ", skiffName("Night Drive 2026"))
        assertEquals("CAF", skiffName("Café"))   // (Skiff takes ASCII only)
    }

    // ---- Playing now

    private fun slots(current: Int? = null) = (0..3).map { ProjectSlot(it, used = it < 3, name = listOf("ALPHA", "BRAVO", "NIGHT DRIVE", "")[it], current = it == current) }

    @Test fun aSlotsMusicSaysWhichSlotAndTheFirmwaresChangedFlag() {
        val p = playingNow(ProjectsState(slots(1), name = "BRAVO", changed = true), null) { null }
        assertEquals(PlayingSource.Slot, p.source); assertEquals("BRAVO", p.name); assertEquals(1, p.slot)
        assertEquals("FM-1 P2", p.sourceText); assertEquals("From the FM-1's P2 · changed since", p.line)
        assertTrue(p.needsSaving)
    }

    @Test fun aPhoneFileIsHomeWhileTheFm1StillShowsItsNameAndSlot() {
        val home = PhoneHome("id1", "NIGHT DRIVE", null)
        val names = { id: String -> if (id == "id1") "Night Drive" else null }
        val p = playingNow(ProjectsState(slots(), name = "NIGHT DRIVE", phoneEdited = false), home, names)
        assertEquals(PlayingSource.Phone, p.source); assertEquals("Night Drive", p.name); assertEquals("Saved on this phone", p.line)
        assertFalse(p.needsSaving)
        // changed since: the core says so, and after a restart (unknown) it counts as changed
        assertTrue(playingNow(ProjectsState(slots(), name = "NIGHT DRIVE", phoneEdited = true), home, names).changed)
        assertTrue(playingNow(ProjectsState(slots(), name = "NIGHT DRIVE", phoneEdited = null), home, names).changed)
        // a slot loaded since (another slot current): the slot is home
        assertEquals(PlayingSource.Slot, playingNow(ProjectsState(slots(0), name = "ALPHA"), home, names).source)
        // the FM-1 shows another name: not the file's music any more
        assertEquals(PlayingSource.New, playingNow(ProjectsState(slots(), name = "OTHER"), home, names).source)
        // the file is gone
        assertEquals(PlayingSource.New, playingNow(ProjectsState(slots(), name = "NIGHT DRIVE"), home) { null }.source)
    }

    @Test fun savedToThePhoneFromASlotThePhoneIsHome() {
        val home = PhoneHome("id1", "BRAVO", 1)
        val p = playingNow(ProjectsState(slots(1), name = "BRAVO", changed = true, phoneEdited = false), home) { "Bravo on phone" }
        assertEquals(PlayingSource.Phone, p.source); assertFalse(p.changed)
    }

    @Test fun musicFromNowhereIsNewAndAlwaysNeedsASafetyCopy() {
        val p = playingNow(ProjectsState(slots(), name = ""), null) { null }
        assertEquals(PlayingSource.New, p.source); assertEquals("Untitled", p.name); assertEquals("New, not saved anywhere", p.line)
        assertFalse(p.changed); assertTrue(p.needsSaving)
    }

    // ---- Copy to phone's words

    @Test fun copyToPhoneSaysWhatHappensToThePlayingMusic() {
        val p3 = ProjectSlotUi(3, "NIGHT DRIVE", "kept on the FM-1")
        val fromP1 = playingNow(ProjectsState(slots(0), name = "ALPHA", changed = true), null) { null }
        assertEquals("Copy P3 NIGHT DRIVE to this phone? Lupe keeps a safety copy of your changes, loads P3, copies it, then puts your changes back. The FM-1 stops.", copyWords(p3, fromP1))
        val phone = playingNow(ProjectsState(slots(), name = "NIGHT", phoneEdited = false), PhoneHome("a", "NIGHT", null)) { "Night" }
        assertEquals("Copy P3 NIGHT DRIVE to this phone? Lupe loads P3, copies it, then opens Night again. The FM-1 stops.", copyWords(p3, phone))
        val fresh = playingNow(ProjectsState(slots(), name = ""), null) { null }
        assertTrue(copyWords(p3, fresh).contains("keeps a safety copy of what's playing"))
        // the playing slot, unchanged: nothing to keep, so no question
        val onP3 = playingNow(ProjectsState(slots(2), name = "NIGHT DRIVE", changed = false), null) { null }
        assertFalse(copyNeedsAsking(2, onP3))
        assertTrue(copyNeedsAsking(1, onP3))
    }

    // ---- the pool line

    @Test fun poolLineCountsPatternsOnlySlotsKeep() {
        val pool = PatternsState(
            free = 23, kept = 41, unused = 2,
            patterns = listOf(
                PoolPattern(1, len = 16, uses = 2, here = listOf(PatternUse(1, 0))),     // the music uses it (and a slot too)
                PoolPattern(2, len = 16, uses = 1, on = listOf(3)),                       // a track sits on it: the music's
                PoolPattern(3, len = 16, uses = 1),                                       // only a slot
                PoolPattern(4, len = 8, uses = 3, saved = true),                          // only slots
                PoolPattern(5, len = 16, uses = 0, unused = true),                        // nothing
                PoolPattern(6, len = 0, uses = 1),                                        // not kept (length 0)
            ),
        )
        val l = poolLine(pool)!!
        assertEquals(41, l.taken); assertEquals(2, l.unused); assertEquals(2, l.slotOnly)
        assertEquals("41 of 64 pattern numbers taken · 2 unused · 2 kept only by FM-1 slots", l.text)
    }

    @Test fun noPoolLineBeforeThePoolIsRead() = assertNull(poolLine(PatternsState()))

    // ---- words for a failed transfer

    @Test fun poolFullSaysNeededAgainstFreeAndTheUsualCause() {
        val w = transferWords(TransferEvent(1, "failed", error = "poolFull", needed = 14, free = 6), "open Night Drive")
        assertTrue(w.startsWith("Couldn't open Night Drive: it needs 14 pattern numbers and 6 are free. Nothing on the FM-1 changed."))
        assertTrue(w.contains("FM-1 slots"))
        assertTrue(w.contains("Copy a slot to this phone"))
        assertFalse(w.contains("—"))
        assertNotNull(transferWords(TransferEvent(1, "failed", error = "whatever"), "save"))
    }

    @Test fun transferEventsDecodeFromTheCore() {
        val e = Json { ignoreUnknownKeys = true }.decodeFromString(TransferEvent.serializer(),
            """{"id":4,"phase":"done","fingerprint":"f","skiff":{"record":"AA==","patterns":[],"firmware":"2.5.1"}}""")
        assertTrue(e.ok); assertNotNull(e.skiff)
        val p = PhoneProject(name = "x", saved = "2026-11-17T09:00:00Z", skiff = e.skiff!!)
        assertEquals(0, p.patternCount)
    }
}
