package com.scottgerstl.lupe.core

/**
 * A made-up pattern pool for the fake core, as board 79 draws it: 52 kept numbers of 64, twelve of them unused, the rest used by a pad or two
 * of this project, some also held by a saved project. Pictures come from a small deterministic pattern per number.
 */
internal object FakePool {
    private val FREE = setOf(5, 9, 18, 23, 30, 41, 44, 50, 57, 61, 62, 64)
    val UNUSED = listOf(3, 12, 15, 27, 33, 38, 46, 52, 55, 58, 60, 63)

    fun initial(): List<PoolPattern> {
        var seed = 7L
        fun rnd(): Double { seed = (seed * 9301 + 49297) % 233280; return seed / 233280.0 }
        return (1..64).filter { it !in FREE }.map { n ->
            val t = (rnd() * 6).toInt(); val unused = n in UNUSED
            val here = if (unused) emptyList() else buildList {
                add(PatternUse(t + 1, (rnd() * 6).toInt()))
                if (rnd() > 0.7) add(PatternUse((t + 2) % 6 + 1, (rnd() * 6).toInt()))
            }.sortedWith(compareBy({ it.track }, { it.entry }))
            val saved = !unused && rnd() > 0.6
            PoolPattern(n, listOf(16, 16, 32, 8, 16, 64)[(rnd() * 6).toInt()], here.size + if (saved) 1 else 0, here, here.map { it.track }.distinct(), saved, unused)
        }
    }

    /** The counts, recycle number and flags for [list]; [playing] puts the pictures on "wait for a stop". */
    fun state(list: List<PoolPattern>, playing: Boolean): PatternsState {
        val unused = list.filter { it.unused }.map { it.number }
        return PatternsState(free = 64 - list.size, kept = list.size, unused = unused.size, recycle = unused.minOrNull(), picturesWaitForStop = playing, patterns = list)
    }

    fun pictures(list: List<PoolPattern>, playing: Boolean): PatternPictures =
        PatternPictures(list.filter { !playing || it.on.isNotEmpty() }.map { p ->
            val drums = p.number % 5 == 0
            var r = p.number * 13 % 17
            val notes = MutableList(p.len) { i -> r = (r * 7 + 3) % 17; if ((p.number + i) % 3 == 0) -1 else 48 + r }
            val hits = MutableList(p.len) { i -> if (i % 4 == 0 || (p.number + i) % 5 == 0) 1 + i % 3 else 0 }
            PatternPicture(p.number, p.len, drums, if (drums) emptyList() else notes, if (drums) hits else emptyList(), live = p.on.isNotEmpty())
        })
}
