package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.onSubscription
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

// Moving a whole Skiff project in and out of the FM-1 for the phone's project files (android/core/Sources/PhoneCore/PhoneProjects.swift).
// The files are the app's (PhoneProjectStore.kt); the core only reads, writes, loads a slot or saves one, and answers each request by its id.

/**
 * One request. [op]: "read" (the music with its patterns: stops the FM-1; allowed while read-only), "write" ([skiff] onto the FM-1 as the music,
 * named [name]), "loadSlot" / "saveSlot" ([slot] 0…3; a save under [name]).
 */
@Serializable @SerialName("projectTransfer")
data class ProjectTransfer(val id: Int, val op: String, val skiff: JsonElement? = null, val name: String? = null, val slot: Int? = null, val edited: Boolean? = null) : Intent

/**
 * The core's answer. [phase] "progress" (a write's [progress] 0…1), "done" (a read carries [skiff]) or "failed" with [error]: "poolFull" (it
 * needs [needed] pattern numbers and [free] are free), "playing", "notConnected", "readOnly", "busy", "empty", "refused", "noAnswer". [text]: the
 * core's words for it, for the log.
 */
@Serializable
data class TransferEvent(
    val id: Int, val phase: String, val progress: Double? = null, val skiff: JsonElement? = null, val fingerprint: String? = null,
    val error: String? = null, val text: String? = null, val needed: Int? = null, val free: Int? = null,
) {
    val ok: Boolean get() = phase == "done"
}

object TransferDefaults {
    /** A core that can't move projects: nothing ever answers (the request times out). */
    val none: SharedFlow<TransferEvent> = MutableSharedFlow()
    private var next = 0
    @Synchronized fun nextId(): Int = ++next
}

/**
 * Sends [op] and waits for its answer, passing a write's progress on. No answer within [timeoutMs]: a failed "noAnswer" event, so a caller never
 * hangs (a core that can't move projects, or an FM-1 that went away mid-way).
 */
suspend fun LupeCore.transfer(op: ProjectTransfer, timeoutMs: Long = 180_000, onProgress: (Double) -> Unit = {}): TransferEvent =
    withTimeoutOrNull(timeoutMs) {
        transfers.onSubscription { send(op) }
            .filter { it.id == op.id }
            .onEach { if (it.phase == "progress") it.progress?.let(onProgress) }
            .first { it.phase != "progress" }
    } ?: TransferEvent(op.id, "failed", error = "noAnswer", text = "no answer in ${timeoutMs / 1000} s")
