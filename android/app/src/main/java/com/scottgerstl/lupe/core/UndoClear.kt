package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Clear a pad without confirming, with Undo (batch item 13; P1's 2ea3f0c). The core clears the pad in a way that keeps its pattern for ten
// seconds, so undoing brings back the pattern with its notes, repeats, chain and sound.

/** A pad that was cleared and can come back: [track] 1…6, [entry] from 0, [pattern] absent when the pad held a REST. */
@Serializable
data class ClearedPad(val track: Int, val entry: Int, val pattern: Int? = null)

/** Undo the last clear, or (with a pad) that pad's: "Undo clear" in the pad's menu. A successful undo sends no notice; the pad coming back is the answer. */
@Serializable @SerialName("undoClear") data class UndoClear(val track: Int? = null, val entry: Int? = null) : Intent

/** "Cleared T2 pad F · pattern 07": what the Undo strip says. */
fun clearedWords(c: ClearedPad): String = "Cleared T${c.track} pad ${'A' + c.entry}" + (c.pattern?.let { " · pattern %02d".format(it) } ?: " · REST")
