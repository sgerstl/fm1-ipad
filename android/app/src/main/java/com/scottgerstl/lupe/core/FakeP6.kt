package com.scottgerstl.lupe.core

/**
 * What the fake knows of P6's areas (timeline, automation), answering P1's intents with the core's rules
 * (P6State.kt): blocks are a track's list of entries played back to back, so a block's place in time is the sum of the
 * ones before it; "move" reorders among the track's blocks, "stretch" is REPS, delete over a pattern used nowhere else and
 * drawing over recorded changes need `confirmed`. Recordings from P1's core carry the real state; scenarios without one
 * are seeded from the pads.
 */
object FakeP6 {
    fun seedTimeline(pads: PadsState): TimelineState {
        val kept = pads.rows.flatMap { r -> r.entries.mapNotNull { if (it.kind == PadKind.Pattern) it.pattern else null } }.distinct().sorted()
        val tracks = pads.rows.map { r ->
            var id = 0
            val blocks = r.entries.mapIndexedNotNull { i, e ->
                if (e.kind == PadKind.Empty) null else TimelineBlock(id = i, first = i, last = i, kind = if (e.kind == PadKind.Rest) "rest" else "pattern",
                    pattern = e.pattern, patterns = listOfNotNull(e.pattern), reps = e.passes ?: (if (i % 2 == 0) 4 else 8), passBars = 1.0)
            }
            TimelineTrack(r.track, r.name, blocks = blocks, entriesUsed = r.entries.count { it.kind != PadKind.Empty })
        }
        return layout(TimelineState(mode = "on", tracks = tracks, kept = kept))
    }

    /** Places every block in time (cumulative bars, ids as list positions) and finds the song's length. */
    fun layout(s: TimelineState): TimelineState {
        val tracks = s.tracks.map { t ->
            var at = 0.0
            var id = 0
            val blocks = t.blocks.map { b ->
                val len = b.reps * b.passBars
                val n = b.last - b.first + 1
                b.copy(id = id, first = id, last = id + n - 1, startBar = at, lengthBars = len).also { at += len; id += n }
            }
            t.copy(blocks = blocks, endBar = at, entriesUsed = id)
        }
        return s.copy(tracks = tracks, bars = tracks.maxOfOrNull { it.endBar } ?: 0.0)
    }

    private fun edit(s: TimelineState, track: Int, f: (List<TimelineBlock>) -> List<TimelineBlock>) =
        layout(s.copy(tracks = s.tracks.map { if (it.track == track) it.copy(blocks = f(it.blocks)) else it }))

    fun timeline(s: TimelineState, i: Intent): TimelineState = when (i) {
        is BlockMove -> edit(s, i.track) { bs ->
            val at = bs.indexOfFirst { it.id == i.block }; val to = at + i.by
            if (at < 0 || to !in bs.indices) bs else bs.toMutableList().also { val b = it.removeAt(at); it.add(to, b) }
        }
        is BlockStretch -> edit(s, i.track) { bs -> bs.map { if (it.id == i.block) it.copy(reps = i.reps.coerceIn(1, 16)) else it } }
        is BlockDelete -> {
            val b = s.tracks.firstOrNull { it.track == i.track }?.blocks?.firstOrNull { it.id == i.block }
            val used = b?.pattern?.let { p -> s.tracks.sumOf { t -> t.blocks.count { it.pattern == p } } } ?: 0
            if (b != null && used <= 1 && b.kind == "pattern" && !i.confirmed) s            // a pattern used nowhere else would be erased: refused unconfirmed
            else edit(s, i.track) { bs -> bs.filter { it.id != i.block } }
        }
        is BlockSetPattern -> edit(s, i.track) { bs -> bs.map { if (it.id == i.block) it.copy(kind = "pattern", pattern = i.pattern, patterns = listOf(i.pattern)) else it } }
        is BlockDuplicate -> edit(s, i.track) { bs ->
            val at = bs.indexOfFirst { it.id == i.block }
            if (at < 0 || bs.sumOf { it.last - it.first + 1 } >= 16) bs else bs.toMutableList().also { it.add(at + 1, bs[at]) }
        }
        is BlockInsert -> edit(s, i.track) { bs ->
            if (bs.sumOf { it.last - it.first + 1 } >= 16) bs
            else bs.toMutableList().also { it.add(i.at.coerceIn(0, bs.size), TimelineBlock(0, 0, 0, if (i.pattern == 65) "rest" else "pattern", if (i.pattern == 65) null else i.pattern, listOfNotNull(i.pattern.takeIf { it != 65 }), reps = 1, passBars = 1.0)) }
        }
        else -> s
    }

    // ---- automation: derived from the editor's pattern, so drawing and the grid agree

    fun automation(ed: EditorState, lane: String): AutomationState {
        val lanes = ed.lanes.mapIndexed { n, l ->
            AutomationLane(l, 30 + n, recorded = ed.steps.count { s -> s.values.any { it.param == l && !it.locked } }, locks = ed.steps.count { s -> s.values.any { it.param == l && it.locked } })
        }
        val show = lane.takeIf { l -> ed.lanes.contains(l) } ?: ed.lanes.firstOrNull().orEmpty()
        val base = FakeData.baseValue(show)
        var held = base
        var heldSource = "sound"
        val points = if (show.isEmpty()) emptyList() else ed.steps.mapIndexed { i, s ->
            val v = s.values.firstOrNull { it.param == show }
            when {
                v != null && v.locked -> AutomationPoint(i, v.value, "lock", "${v.value * 100 / 127}%")
                v != null -> { held = v.value; heldSource = "recorded"; AutomationPoint(i, v.value, "recorded", "${v.value * 100 / 127}%") }
                else -> AutomationPoint(i, held, heldSource, "${held * 100 / 127}%")
            }
        }
        return AutomationState(track = ed.track, pattern = ed.pattern, steps = 16, lanes = lanes, lane = show, min = 0, max = 127, base = base, points = points)
    }
}
