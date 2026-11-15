package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * A pad dragged onto another place of its track (P1 is adding the real one: `padMove{track, from, toTrack, to}`; this copy is the same
 * shape so the merge drops one of them). [track] 1…6, [from] and [to] entries from 0. The FM-1 rewrites a list only while stopped, so
 * playing it is refused with its notice.
 */
@Serializable @SerialName("padMove") data class PadMove(val track: Int, val from: Int, val toTrack: Int, val to: Int) : Intent

/** Wipe a pattern's notes and keep the pad (decision 41's Clear steps; P1's d953844): works while playing when the track is on that pad; the Undo is `undoClear` for ten seconds, its item `kind` "steps". */
@Serializable @SerialName("clearSteps") data class ClearSteps(val track: Int, val entry: Int) : Intent
