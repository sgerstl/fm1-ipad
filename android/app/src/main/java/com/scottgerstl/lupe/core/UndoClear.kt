package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Clear a pad without confirming, with Undo (batch item 13; P1's 2ea3f0c). The core clears the pad in a way that keeps its pattern until the
// next change to the song (Scott, 2026-11-17, messages rule; it was ten seconds), so undoing brings back the pattern with its notes, repeats,
// chain and sound.

/**
 * What was cleared or deleted and can come back: [track] 1…6, [entry] from 0, [pattern] absent when it held a REST. For a Timeline block
 * ([block] true) [entry] is the block's id (its first entry) and [pattern] its first entry's; undoing it puts the whole block back, with the
 * entries after it, but only while the track's list is exactly as the delete left it (P1's 4d2e44a).
 */
@Serializable
data class ClearedPad(val track: Int, val entry: Int, val pattern: Int? = null, val block: Boolean = false, val kind: String = "pad")

/** Undo the last clear, or (with a pad) that pad's: "Undo clear" in the pad's menu. A successful undo sends no notice; the pad coming back is the answer. */
@Serializable @SerialName("undoClear") data class UndoClear(val track: Int? = null, val entry: Int? = null) : Intent

/** "Cleared T2 pad F · pattern 07": what the app strip says. */
fun clearedWords(c: ClearedPad): String =
    (if (c.block) "Deleted T${c.track} block ${'A' + c.entry}" else if (c.kind == "steps") "Cleared T${c.track} pad ${'A' + c.entry}'s notes" else "Cleared T${c.track} pad ${'A' + c.entry}") + (c.pattern?.let { " · pattern %02d".format(it) } ?: " · REST")
