package com.scottgerstl.lupe.core

/**
 * What [FakeLupeCore] does with the page area: it learns every page the fixtures show (by title), answers SetParam by
 * changing the number it was given, and PickPage by switching to the page it knows. A page it has never seen comes up
 * with empty wells and no graph. PROVISIONAL: the real core answers from the FM-1 and the screen link.
 */
class FakePages {
    private val library = mutableMapOf<String, PageState>()
    private val rows = mutableMapOf<String, List<PageRef>>()

    /** Skiff 2.5.1's rows for a family the fixtures never showed (EDIT as an ANALOG track has it). */
    private val defaults = mapOf(
        "ENV" to listOf(0 to "ENV", 1 to "ENV 2"), "LFO" to listOf(2 to "LFO", 3 to "LFO 2", 4 to "MOD"),
        "FX" to listOf(5 to "FX", 46 to "DELAY", 47 to "REVERB", 6 to "DRIVE", 7 to "INSERT", 8 to "INSERT 2", 9 to "SLICER", 10 to "DUCK"),
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
        val g = p.graph
        val graph = when (g.kind) {
            GraphKind.Env, GraphKind.Fx, GraphKind.Lfo, GraphKind.Drive, GraphKind.Arp, GraphKind.Analog ->
                if (slot < g.values.size) g.copy(values = g.values.mapIndexed { i, x -> if (i == slot) v else x }) else g
            GraphKind.Scale -> if (slot == 0) g.copy(root = v) else g
            else -> g
        }
        return p.copy(controls = controls, graph = graph)
    }

    fun pick(p: PageState, family: String, page: Int?, track: Int = p.track, trackName: String = p.trackName): PageState {
        val row = rows[family] ?: defaults[family] ?: emptyList()
        val ref = (if (page == null) row.firstOrNull() else row.firstOrNull { it.index == page }) ?: return p.copy(family = family)
        library[ref.title]?.let { return it.copy(track = track, trackName = trackName, lock = p.lock, turned = -1) }
        // a page the fixtures don't carry: built from the map (FakePageMap), else four empty wells
        val (controls, graph) = FakePageMap.build(ref.title) ?: (List<PageControl?>(4) { null } to PageGraph())
        return p.copy(family = family, pages = row, page = ref.index, track = track, trackName = trackName, controls = controls, graph = graph, turned = -1)
    }

    fun pickRoute(p: PageState, route: Int): PageState =
        if (p.graph.kind == GraphKind.Mod) p.copy(graph = p.graph.copy(picked = route.coerceIn(0, p.graph.routes.size - 1))) else p

    fun pickTile(p: PageState, tile: Int): PageState =
        if (p.graph.kind == GraphKind.Tiles) p.copy(graph = p.graph.copy(picked = tile.coerceIn(0, p.graph.tiles.size - 1))) else p
}

/** The FM-1's knob [slot] turned (the demo's stand-in for the screen link's knob report): lights it on the phone. */
fun FakePages.fm1Turn(p: PageState, slot: Int): PageState = p.copy(turned = slot, turnSeq = p.turnSeq + 1)
