package com.scottgerstl.lupe.ui.patterns

import com.scottgerstl.lupe.core.PatternPicture
import com.scottgerstl.lupe.core.PatternsState
import com.scottgerstl.lupe.core.PoolPattern
import com.scottgerstl.lupe.core.usesText

/** The sheet's filters (board 79): everything kept, only what nothing uses, only what this project's pads use. */
enum class PatternFilter(val label: String) { All("All"), Unused("Unused"), ThisProject("This project") }

/** What the cards do on a tap: open the pattern's uses, pick the unused ones to clear, or pick one to put on a pad. */
enum class PatternMode { Browse, Select, Pick }

fun PatternsState.filtered(f: PatternFilter): List<PoolPattern> = when (f) {
    PatternFilter.All -> patterns
    PatternFilter.Unused -> patterns.filter { it.unused }
    PatternFilter.ThisProject -> patterns.filter { it.here.isNotEmpty() }
}

/** "52 kept · 12 free · 12 unused". */
fun PatternsState.countsText(): String = "$kept kept · $free free · $unused unused"

/** "07" for the numbers on the cards and in the confirm. */
fun num(n: Int) = "%02d".format(n)

/** What a tap on a used card says in Select mode: where it is used, so Scott can see why it can't be picked. */
fun usedWhere(p: PoolPattern): String {
    val parts = buildList {
        if (p.here.isNotEmpty()) add(usesText(p.here))
        if (p.saved) add("a saved project")
        if (isEmpty()) add("something on the FM-1")
    }
    return "Pattern ${num(p.number)} is used by ${parts.joinToString(" and ")}, so it can't be cleared."
}

/** The confirm's words: "Clear 5 patterns?" over the numbers, past eight the first eight and how many more. */
fun clearQuestion(n: Int) = "Clear $n pattern${if (n == 1) "" else "s"}?"
fun clearNumbers(numbers: List<Int>): String {
    val s = numbers.sorted(); val shown = s.take(8).joinToString(", ") { num(it) }
    return shown + (if (s.size > 8) " and ${s.size - 8} more" else "") + " · nothing uses them · can't be undone"
}

/** A pattern's card colour: the track of its first user in this project, else none (grey). */
fun firstUserTrack(p: PoolPattern): Int? = p.here.firstOrNull()?.track

/** The picture to draw for a pattern: the core's when it has one; while the stored ones are still being read, none. */
fun pictureFor(n: Int, pictures: List<PatternPicture>): PatternPicture? = pictures.firstOrNull { it.number == n }

/** One step's mark for the thumbnail: where it sits from the top (0…1) and how tall it is, or null for none. */
fun stepMarks(pic: PatternPicture): List<Pair<Int, Float>> {
    val len = pic.len.coerceAtLeast(1)
    return if (pic.drums) (0 until minOf(len, pic.hits.size)).mapNotNull { i -> pic.hits[i].takeIf { it > 0 }?.let { i to (1f - (it.coerceIn(1, 4) / 5f)) } }
    else {
        val ns = pic.notes.take(len).filter { it >= 0 }
        if (ns.isEmpty()) emptyList() else {
            val lo = ns.min(); val hi = ns.max(); val span = (hi - lo).coerceAtLeast(1)
            (0 until minOf(len, pic.notes.size)).mapNotNull { i -> pic.notes[i].takeIf { it >= 0 }?.let { i to (1f - (it - lo).toFloat() / span) } }
        }
    }
}
