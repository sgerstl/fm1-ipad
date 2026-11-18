package com.scottgerstl.lupe.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonObject
import java.io.File
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

// Projects saved on the phone (Scott, 2026-11-17), the Android twin of the iPad's ProjectStore (ios/FM1/Projects.swift): the same file format,
// so a file from one opens on the other. A project file is Skiff's project record and the patterns it plays (`skiff`, exactly as the core's
// `transfer` read gives it), a name, when it was saved, and whether Lupe took it by itself before opening something over unsaved work.
// Kept in the app's own storage (filesDir/Projects, its safety copies in Projects/Safety copies).

/** One project file. [saved] is ISO 8601 to the second (the iPad's decoder takes no fractions). */
@Serializable
data class PhoneProject(
    val format: String = FORMAT,
    val version: Int = 1,
    val id: String = UUID.randomUUID().toString().uppercase(),
    val name: String,
    val saved: String,
    /** A copy Lupe took by itself before opening something over it ("Before opening Night Drive"). */
    val isSafetyCopy: Boolean = false,
    /** The project's fingerprint when saved or opened (the iPad recognises it by this). */
    val baseline: String = "",
    val skiff: JsonElement,
) {
    /** How many patterns travel with it. */
    val patternCount: Int get() = (runCatching { skiff.jsonObject["patterns"] as? JsonArray }.getOrNull())?.size ?: 0
    val savedAt: Instant? get() = runCatching { Instant.parse(saved) }.getOrNull()

    companion object { const val FORMAT = "lupe-skiff-project" }
}

/**
 * Where the playing music lives, so Save knows where to write it back. A phone file ([projectId]), remembered with the name the FM-1 shows for
 * it ([fm1Name]) and the slot the FM-1 called current then ([slotAtSave], 0…3 or null): while both still match, the music is that file's.
 */
@Serializable
data class PhoneHome(val projectId: String, val fm1Name: String, val slotAtSave: Int? = null)

/** A name as Skiff stores it: upper case, ASCII 32…126, 12 at most (SkiffDriver.nameBytes). */
fun skiffName(name: String): String = name.uppercase().filter { it.code in 32..126 }.take(12)

class PhoneProjectStore(private val dir: File, private val now: () -> Instant = { Instant.now() }) {
    private val safetyDir = File(dir, "Safety copies")
    private val homeFile = File(dir, "home.json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; prettyPrint = true }

    /** Newest first. */
    var projects: List<PhoneProject> = emptyList(); private set
    var safetyCopies: List<PhoneProject> = emptyList(); private set

    init { load() }

    fun get(id: String): PhoneProject? = (projects + safetyCopies).firstOrNull { it.id == id }

    /** Where the playing music lives, when it's one of the phone's files (kept across launches). */
    var home: PhoneHome?
        get() = runCatching { json.decodeFromString(PhoneHome.serializer(), homeFile.readText()) }.getOrNull()?.takeIf { get(it.projectId) != null }
        set(v) { if (v == null) homeFile.delete() else { dir.mkdirs(); homeFile.writeText(json.encodeToString(PhoneHome.serializer(), v)) } }

    /** A new project from what the FM-1 gave. */
    fun save(name: String, skiff: JsonElement, baseline: String = ""): PhoneProject {
        val p = PhoneProject(name = cleaned(name) ?: nextName(), saved = stamp(), baseline = baseline, skiff = skiff)
        write(p); return p
    }

    /** Save over [id] (Save on a phone project): its music replaced, its name kept. */
    fun overwrite(id: String, skiff: JsonElement, baseline: String = ""): PhoneProject? {
        val old = get(id) ?: return null
        val p = old.copy(skiff = skiff, baseline = baseline, saved = stamp())
        write(p); return p
    }

    /** A safety copy, before something is opened over unsaved work; only the newest [KEPT_SAFETY_COPIES] are kept. */
    fun keepSafetyCopy(name: String, skiff: JsonElement, baseline: String = ""): PhoneProject {
        val p = PhoneProject(name = cleaned(name) ?: "Safety copy", saved = stamp(), isSafetyCopy = true, baseline = baseline, skiff = skiff)
        write(p)
        safetyCopies.drop(KEPT_SAFETY_COPIES).forEach { file(it).delete() }
        load(); return p
    }

    /** A new name; a safety copy renamed becomes a project. False: no such file, or a blank name. */
    fun rename(id: String, name: String): Boolean {
        val p = get(id) ?: return false
        val n = cleaned(name) ?: return false
        write(p.copy(name = n, isSafetyCopy = false)); return true
    }

    fun duplicate(id: String): PhoneProject? {
        val p = get(id) ?: return null
        val q = p.copy(id = UUID.randomUUID().toString().uppercase(), name = uniqueName("${p.name} copy"), saved = stamp(), isSafetyCopy = false, baseline = "")
        write(q); return q
    }

    fun delete(id: String) {
        val p = get(id) ?: return
        file(p).delete()
        if (home?.projectId == id) home = null
        load()
    }

    /** "Project 4": the next number no project uses (the iPad's nextName). */
    fun nextName(): String {
        val used = projects.map { it.name }.toSet()
        var n = projects.size + 1
        while ("Project $n" in used) n++
        return "Project $n"
    }

    /** [base], or "[base] 2", "[base] 3"… when a project has that name already. */
    fun uniqueName(base: String): String {
        val b = cleaned(base) ?: return nextName()
        val used = projects.map { it.name }.toSet()
        if (b !in used) return b
        var n = 2
        while ("$b $n" in used) n++
        return "$b $n"
    }

    fun load() {
        fun read(d: File): List<PhoneProject> = (d.listFiles { f -> f.isFile && f.name.endsWith(".json") && f.name != homeFile.name } ?: emptyArray())
            .mapNotNull { runCatching { json.decodeFromString(PhoneProject.serializer(), it.readText()) }.getOrNull() }
            .filter { it.format == PhoneProject.FORMAT }
            .sortedByDescending { it.savedAt ?: Instant.EPOCH }
        projects = read(dir).filter { !it.isSafetyCopy }
        safetyCopies = read(safetyDir).filter { it.isSafetyCopy }
    }

    private fun file(p: PhoneProject) = File(if (p.isSafetyCopy) safetyDir else dir, "${p.id}.json")

    private fun write(p: PhoneProject) {
        safetyDir.mkdirs()
        // a safety copy renamed into a project moves folders
        listOf(File(dir, "${p.id}.json"), File(safetyDir, "${p.id}.json")).filter { it != file(p) }.forEach { it.delete() }
        val target = file(p)
        val tmp = File(target.parentFile, "${target.name}.tmp")
        tmp.writeText(json.encodeToString(PhoneProject.serializer(), p))
        if (!tmp.renameTo(target)) { target.delete(); check(tmp.renameTo(target)) { "couldn't write ${target.name}" } }
        load()
    }

    private fun stamp(): String = now().truncatedTo(ChronoUnit.SECONDS).toString()

    companion object {
        const val KEPT_SAFETY_COPIES = 5
        /** A name trimmed, 40 at most; null when blank. */
        fun cleaned(name: String?): String? = name?.trim()?.take(40)?.ifEmpty { null }
    }
}
