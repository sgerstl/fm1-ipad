package com.scottgerstl.lupe.ui.projects

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PhoneHome
import com.scottgerstl.lupe.core.PhoneProject
import com.scottgerstl.lupe.core.PhoneProjectStore
import com.scottgerstl.lupe.core.PlayingNow
import com.scottgerstl.lupe.core.PlayingSource
import com.scottgerstl.lupe.core.ProjectTransfer
import com.scottgerstl.lupe.core.ProjectsState
import com.scottgerstl.lupe.core.TransferDefaults
import com.scottgerstl.lupe.core.TransferEvent
import com.scottgerstl.lupe.core.playingNow
import com.scottgerstl.lupe.core.skiffName
import com.scottgerstl.lupe.core.transfer
import com.scottgerstl.lupe.core.transferWords
import com.scottgerstl.lupe.ui.shell.MessageKind
import com.scottgerstl.lupe.ui.shell.MessageModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.JsonElement

/** What a phone-project job is doing: the words, and how far a write has got (null: no measure). */
data class ProjectsBusy(val label: String, val progress: Float? = null)

/**
 * The phone's projects and the jobs that move music between them and the FM-1 (Scott, 2026-11-17), as the iPad's ProjectStore does them:
 * Save to this phone, Save over a phone project, Open one (keeping a safety copy of unsaved work first), and Copy a slot to this phone. Every
 * result and refusal goes to the app strip ([messages]); progress shows in the sheet's Playing now row ([busy]).
 */
@Stable
class ProjectsController(
    private val core: LupeCore,
    private val store: PhoneProjectStore,
    private val scope: CoroutineScope,
    private val messages: MessageModel,
) {
    var busy by mutableStateOf<ProjectsBusy?>(null); private set
    var files by mutableStateOf(store.projects); private set
    var safetyCopies by mutableStateOf(store.safetyCopies); private set
    private var home by mutableStateOf(store.home)

    fun nextName(): String = store.nextName()

    /** The playing music, from the core's projects area and the phone's own record of where it lives. */
    fun playing(state: ProjectsState): PlayingNow = playingNow(state, home) { id -> files.firstOrNull { it.id == id }?.name }

    /** A load or save on an FM-1 slot was asked for: the music lives there now, not in a phone file. */
    fun leftPhone() { moveHome(null) }

    // ---- jobs

    /** What the FM-1 holds, into a new phone project named [name]; the music lives in that file from now on. */
    fun saveToPhone(name: String) = job("Saving to this phone…") {
        val e = read() ?: return@job fail("save to this phone")
        val p = io { store.save(name, e.skiff!!, e.fingerprint.orEmpty()) }
        rememberHome(p.id)
        confirm("Saved ${p.name} on this phone.")
    }

    /** Save on a phone project: the FM-1's music over that file. */
    fun saveOver(projectId: String) {
        val name = files.firstOrNull { it.id == projectId }?.name ?: return
        job("Saving $name…") {
            val e = read() ?: return@job fail("save $name")
            io { store.overwrite(projectId, e.skiff!!, e.fingerprint.orEmpty()) }
            rememberHome(projectId)
            confirm("Saved $name on this phone.")
        }
    }

    /**
     * A phone project onto the FM-1 as the music. Over unsaved work, a safety copy is kept first (the iPad's rule). A safety copy goes on
     * unnamed and isn't anyone's home.
     */
    fun open(p: PhoneProject) = job("Opening ${p.name}…", 0f) {
        if (playing(core.projects.value).needsSaving) {
            step("Keeping a safety copy…")
            read()?.let { e -> io { store.keepSafetyCopy("Before opening ${p.name}", e.skiff!!, e.fingerprint.orEmpty()) } }
                ?: return@job fail("keep a safety copy before opening ${p.name}")
        }
        step("Opening ${p.name}…", 0f)
        val name = if (p.isSafetyCopy) "" else p.name
        val e = write(p.skiff, name)
        if (!e.ok) return@job refuse(transferWords(e, "open ${p.name}"))
        if (p.isSafetyCopy) moveHome(null) else rememberHome(p.id, skiffName(name))
        confirm("Opened ${p.name} on the FM-1.")
    }

    /**
     * FM-1 slot [slot] (0…3) copied into a phone project named after it. The playing music is kept first (to its home when it changed, or as a
     * safety copy when it has none: the same rule as opening), the slot is loaded and read, and then what was playing goes back.
     */
    fun copyToPhone(slot: Int) {
        val st = core.projects.value
        val slotName = st.slots.firstOrNull { it.slot == slot }?.name.orEmpty().ifEmpty { "P${slot + 1}" }
        val p = playing(st)
        val tag = "P${slot + 1}"
        job("Copying $tag to this phone…") {
            // 1. what's playing, kept, and how to put it back
            var restore: (suspend () -> TransferEvent)? = null
            var keptWhere = ""
            when (p.source) {
                PlayingSource.Phone -> {
                    val id = p.projectId!!
                    if (p.changed) {
                        // its changes: a safety copy, written back after under its name (as iOS), the file left as saved
                        step("Keeping a safety copy…")
                        val e = read() ?: return@job fail("keep a safety copy before copying $tag")
                        val copy = io { store.keepSafetyCopy("Before copying $tag", e.skiff!!, e.fingerprint.orEmpty()) }
                        keptWhere = "as a safety copy on this phone"
                        restore = { write(copy.skiff, p.name, edited = true).also { r -> if (r.ok) rememberHome(id, skiffName(p.name)) } }
                    } else keptWhere = "on this phone"
                    if (restore == null) restore = {
                        val f = store.get(id)
                        if (f == null) TransferEvent(0, "failed", error = "refused")
                        else write(f.skiff, f.name).also { r -> if (r.ok) rememberHome(id, skiffName(f.name)) }
                    }
                }
                PlayingSource.Slot -> {
                    val home = p.slot!!
                    moveHome(null)
                    if (p.changed) {
                        // changed since its slot: a safety copy, written back after (as iOS), never saved over the slot unasked
                        step("Keeping a safety copy…")
                        val e = read() ?: return@job fail("keep a safety copy before copying $tag")
                        val copy = io { store.keepSafetyCopy("Before copying $tag", e.skiff!!, e.fingerprint.orEmpty()) }
                        keptWhere = "as a safety copy on this phone"
                        restore = { write(copy.skiff, st.name, edited = true) }
                    } else if (home != slot) {
                        keptWhere = "in P${home + 1}"
                        restore = { run(ProjectTransfer(TransferDefaults.nextId(), "loadSlot", slot = home)) }
                    }
                }
                PlayingSource.New -> {
                    step("Keeping a safety copy…")
                    val e = read() ?: return@job fail("keep a safety copy before copying $tag")
                    val copy = io { store.keepSafetyCopy("Before copying $tag", e.skiff!!, e.fingerprint.orEmpty()) }
                    keptWhere = "as a safety copy on this phone"
                    restore = { write(copy.skiff, "", edited = true).also { r -> if (r.ok) moveHome(null) } }
                }
            }
            // 2. the slot becomes the music
            if (!(p.source == PlayingSource.Slot && p.slot == slot && !p.changed)) {
                step("Loading $tag…")
                val e = run(ProjectTransfer(TransferDefaults.nextId(), "loadSlot", slot = slot))
                if (!e.ok) return@job refuse(transferWords(e, "load $tag") + if (keptWhere.isNotEmpty() && p.changed) " ${p.name} is kept $keptWhere." else "")
            }
            // 3. read it into a phone project
            step("Copying $tag to this phone…")
            val got = read()
            val saved = got?.let { e -> io { store.save(store.uniqueName(slotName), e.skiff!!, e.fingerprint.orEmpty()) } }
            // 4. put back what was playing, whatever happened in 3
            val back = restore?.let { r -> step("Putting back ${p.name}…", 0f); r() }
            when {
                saved == null && back?.ok != false -> refuse("Couldn't copy $tag: the FM-1 didn't send it. ${if (back != null) "${p.name} is back on the FM-1. " else ""}Try again.")
                saved == null -> refuse("Couldn't copy $tag, and ${p.name} didn't go back on the FM-1. $tag is playing now; ${p.name} is kept $keptWhere.")
                back?.ok == false -> refuse("Copied $tag to this phone as ${saved.name}, but ${p.name} didn't go back on the FM-1. " +
                    "$tag is playing now; ${p.name} is kept $keptWhere${if (back.error == "poolFull") " (not enough free pattern numbers)" else ""}.")
                else -> confirm("Copied $tag to this phone as ${saved.name}.")
            }
        }
    }

    // ---- managing (no FM-1 needed)

    fun rename(id: String, name: String) { scope.launch { if (!io { store.rename(id, name) }) refuse("Couldn't rename it. Type a name, then try again."); reload() } }
    fun duplicate(id: String) { scope.launch { io { store.duplicate(id) }?.let { confirm("Made ${it.name}.") }; reload() } }
    fun delete(id: String) { scope.launch { io { store.delete(id) }; reload() } }

    // ---- plumbing

    private fun job(label: String, progress: Float? = null, body: suspend () -> Unit) {
        if (busy != null) return refuse("A project job is still going. Wait for it to finish.")
        if (core.projects.value.busy) return refuse("A project load or save is still going on the FM-1. Wait for it to finish.")
        busy = ProjectsBusy(label, progress)
        scope.launch {
            try { body() } finally { busy = null; reload() }
        }
    }

    private fun step(label: String, progress: Float? = null) { busy = ProjectsBusy(label, progress) }

    private var lastFailure: TransferEvent? = null

    /** The FM-1's music and patterns; null when it failed (kept in [lastFailure] for [fail]). */
    private suspend fun read(): TransferEvent? {
        val e = core.transfer(ProjectTransfer(TransferDefaults.nextId(), "read"))
        return if (e.ok && e.skiff != null) e else { lastFailure = e; null }
    }

    private suspend fun write(skiff: JsonElement, name: String, edited: Boolean = false): TransferEvent =
        core.transfer(ProjectTransfer(TransferDefaults.nextId(), "write", skiff = skiff, name = name, edited = edited.takeIf { it }), timeoutMs = 300_000) { v ->
            busy = busy?.copy(progress = v.toFloat())
        }

    private suspend fun run(op: ProjectTransfer): TransferEvent = core.transfer(op)

    private fun fail(what: String) =
        refuse(transferWords(lastFailure ?: TransferEvent(0, "failed", error = "noAnswer"), what))

    private fun refuse(text: String) = messages.refuse(text)
    private fun confirm(text: String) = messages.post(MessageKind.Confirmation, text)

    /** The music lives in phone file [id] now: remembered with the name the FM-1 shows and its current slot, once the core has published them. */
    private suspend fun rememberHome(id: String, fm1Name: String? = null) {
        val st = if (fm1Name == null) core.projects.value
            else withTimeoutOrNull(2000) { core.projects.first { it.name == fm1Name } } ?: core.projects.value
        moveHome(PhoneHome(id, st.name, st.slots.firstOrNull { it.current }?.slot))
    }

    private fun moveHome(h: PhoneHome?) { store.home = h; home = h }

    private suspend fun reload() { io { store.load() }; files = store.projects; safetyCopies = store.safetyCopies; home = store.home }

    private suspend fun <T> io(body: () -> T): T = withContext(Dispatchers.IO) { body() }
}
