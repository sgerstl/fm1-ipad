package com.scottgerstl.lupe.core

/**
 * What [FakeLupeCore] does with the page area: it learns every page the fixtures show (by title), answers SetParam by
 * changing the number it was given, and PickPage by switching to the page it knows. A page it has never seen comes up
 * with empty wells and no tiles. PROVISIONAL: the real core answers from the FM-1 and the screen link.
 */
class FakePages {
    private val library = mutableMapOf<String, PageState>()
    private val rows = mutableMapOf<String, List<PageRef>>()

    /** Skiff 2.5.1's rows for a family the fixtures never showed (EDIT as an ANALOG track has it). */
    private val defaults = mapOf(
        "ENV" to listOf(0 to "ENV", 1 to "ENV 2"), "LFO" to listOf(2 to "LFO", 3 to "LFO 2", 4 to "MOD"),
        "FX" to listOf(5 to "FX", 46 to "DELAY", 47 to "REVERB", 6 to "DRIVE", 7 to "INSERT", 9 to "SLICER", 10 to "DUCK"),   // Skiff 2.5.1: seven; INSERT 2 is Lupe's row only on 2.2
        "SEL" to listOf(11 to "SCALE", 12 to "CHORD", 13 to "FOLLOW"),
        "EDIT" to listOf(14 to "EDIT 1", 15 to "EDIT 2", 28 to "VOICE", 29 to "VOICE 2"),
        "ARP" to listOf(39 to "ARP", 40 to "ARP 2"),
    ).mapValues { (_, v) -> v.map { PageRef(it.first, it.second) } }

    fun learn(p: PageState) {
        val title = p.pages.firstOrNull { it.index == p.page }?.title ?: return
        library[title] = p
        if (p.pages.isNotEmpty()) rows[p.family] = p.pages
    }

    private fun clamp(c: PageControl, v: Int) = v.coerceIn(c.min, c.max)

    fun setParam(p: PageState, slot: Int, value: Int): PageState {
        val c = p.controls.getOrNull(slot) ?: return p
        if (c.fixed || c.ringless) return p
        val v = clamp(c, value)
        val shown = if (c.list && c.names.isNotEmpty()) c.names.getOrElse(v) { v.toString() } else v.toString()
        val controls = p.controls.mapIndexed { i, x -> if (i == slot) c.copy(raw = v, value = shown) else x }
        // the picture follows the values it is drawn from
        val title = p.pages.firstOrNull { it.index == p.page }?.title.orEmpty()
        return p.copy(controls = controls, graph = if (p.graph.kind == GraphKind.None) p.graph else FakePageMap.graph(title, controls).takeIf { it.kind != GraphKind.None } ?: p.graph)
    }

    fun pick(p: PageState, family: String, page: Int?, track: Int = p.track, trackName: String = p.trackName): PageState {
        val row = rows[family] ?: defaults[family] ?: emptyList()
        val ref = (if (page == null) row.firstOrNull() else row.firstOrNull { it.index == page }) ?: return p.copy(family = family)
        library[ref.title]?.let { return it.copy(track = track, trackName = trackName, lock = p.lock, turned = -1, graph = if (it.graph.kind == GraphKind.None) FakePageMap.graph(ref.title, it.controls) else it.graph) }
        // a page the fixtures don't carry: built from the map (FakePageMap), else four empty wells
        val (controls, tiles) = FakePageMap.build(ref.title) ?: (List<PageControl?>(4) { null } to null)
        val window = if (ref.title == "OPERATOR") PageWindow(1, 5, "ENV 1") else null
        return p.copy(family = family, pages = row, page = ref.index, track = track, trackName = trackName, controls = controls, tiles = tiles, graph = FakePageMap.graph(ref.title, controls), title = if (ref.title == "OPERATOR") "OPERATOR 4" else "", window = window, turned = -1)
    }

    fun pickRoute(p: PageState, route: Int): PageState =
        p.tiles?.takeIf { it.kind == "routes" }?.let { p.copy(tiles = it.copy(picked = route.coerceIn(0, it.routes.size - 1))) } ?: p

    fun pickTile(p: PageState, tile: Int): PageState =
        p.tiles?.takeIf { it.kind == "pick" }?.let { p.copy(tiles = it.copy(picked = tile.coerceIn(0, it.labels.size - 1))) } ?: p
}

/** The FM-1's knob [slot] turned (the demo's stand-in for the screen link's knob report): lights it on the phone. */
fun FakePages.fm1Turn(p: PageState, slot: Int): PageState = p.copy(turned = slot, turnSeq = p.turnSeq + 1)
