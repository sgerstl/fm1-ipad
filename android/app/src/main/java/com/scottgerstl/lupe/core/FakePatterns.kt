package com.scottgerstl.lupe.core

import kotlin.random.Random

/**
 * What the fake knows about patterns, so every pad can be opened in the editor. The real core reads them from
 * the FM-1. Deterministic per (track, pattern): the same pad always shows the same steps.
 */
object FakeData {
    val trackNames = listOf("Acid", "Pad", "Pulse Ld", "Drum Kit", "Piano", "Perc Kit")
    fun isDrum(track: Int) = track == 4 || track == 6 // 1-based
    val drumLanes = listOf("BD", "SD", "CH", "OH", "CP", "TM")
    val rollLanes = listOf("CUTOFF", "DECAY", "RESONANCE", "ATTACK")
    val drumAutoLanes = listOf("LEVEL", "TUNE", "DECAY")
    val conds = listOf("ALWAYS", "1:2", "2:2", "1:4", "FILL")
    // SloopKit writes the sharp sign "♯" (C♯4); parseNote also takes "#"
    private val names = arrayOf("C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B")
    fun noteName(midi: Int) = names[midi % 12] + (midi / 12 - 1)
    fun parseNote(n: String): Int {
        val oct = n.takeLastWhile { it.isDigit() || it == '-' }.toIntOrNull() ?: 4
        return (names.indexOf(n.dropLastWhile { it.isDigit() || it == '-' }.replace('#', '♯')).coerceAtLeast(0)) + (oct + 1) * 12
    }
    // C minor
    private val minor = intArrayOf(0, 2, 3, 5, 7, 8, 10)
    val knobParams = listOf("CUTOFF", "DECAY", "RESONANCE", "ATTACK")
    fun baseValue(param: String) = when (param) { "CUTOFF" -> 84; "DECAY" -> 30; "RESONANCE" -> 40; "ATTACK" -> 10; "LEVEL" -> 100; "TUNE" -> 64; else -> 50 }
}

class FStep(
    var on: Boolean = false, var midi: Int = 60, var extra: Int = 0, var length: Int = 1, var velocity: Int = 100,
    var chance: Int = 100, var ratchet: Int = 1, var nudge: Int = 0, var cond: String = "ALWAYS",
    var lanes: MutableSet<Int> = mutableSetOf(), val values: MutableList<StepValue> = mutableListOf(),
    /** The chord's notes beyond [midi], once the phone's keys have written them (else [extra] made-up ones). */
    var more: MutableList<Int> = mutableListOf(),
) {
    fun copyOf() = FStep(on, midi, extra, length, velocity, chance, ratchet, nudge, cond, lanes.toMutableSet(), values.toMutableList(), more.toMutableList())

    /** Every note on the step, root first. */
    fun notes(): List<Int> = if (!on) emptyList() else if (more.isNotEmpty()) listOf(midi) + more else (0..extra).map { midi + it * 2 + if (it > 0) 1 else 0 }

    fun toStep(drum: Boolean): Step {
        val note = if (!on) "" else if (drum) lanes.sorted().joinToString(" ") { FakeData.drumLanes[it] } else FakeData.noteName(midi)
        val pitch = if (!on) "" else if (drum) note else notes().joinToString(" ") { FakeData.noteName(it) }
        return Step(on, note, if (drum) 0 else extra, length, velocity, chance, ratchet, cond, nudge, pitch, values.toList())
    }

    companion object {
        fun from(s: Step, drum: Boolean): FStep {
            val lanes = if (drum) s.note.split(" ").mapNotNull { n -> FakeData.drumLanes.indexOf(n).takeIf { it >= 0 } }.toMutableSet() else mutableSetOf()
            val midi = if (!drum && s.note.isNotEmpty()) FakeData.parseNote(s.note) else 60
            return FStep(s.on, midi, s.extra, s.length, s.velocity, s.chance, s.ratchet, s.nudge, s.cond, lanes, s.values.toMutableList())
        }

        fun generate(track: Int, pattern: Int): MutableList<FStep> {
            val r = Random(track * 1000 + pattern)
            val drum = FakeData.isDrum(track)
            val minor = intArrayOf(0, 2, 3, 5, 7, 8, 10)
            return MutableList(16) { i ->
                if (drum) {
                    val lanes = mutableSetOf<Int>()
                    if (i % 4 == 0) lanes += 0
                    if (i % 8 == 4) lanes += 1
                    if (i % 2 == 0) lanes += 2 else if (r.nextInt(5) == 0) lanes += 3
                    if (r.nextInt(9) == 0) lanes += 4
                    FStep(on = lanes.isNotEmpty(), lanes = lanes, velocity = 70 + r.nextInt(50), length = 1)
                } else {
                    val on = r.nextInt(100) < 55
                    val deg = minor[r.nextInt(7)]
                    FStep(on, 48 + deg + 12 * r.nextInt(2), if (r.nextInt(8) == 0) 1 else 0, 1 + r.nextInt(3), 60 + r.nextInt(60))
                }
            }
        }
    }
}
