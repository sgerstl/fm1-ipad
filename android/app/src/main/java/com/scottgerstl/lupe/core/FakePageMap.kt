package com.scottgerstl.lupe.core

/**
 * What the fake core shows for a page the fixtures don't carry: the four controls with the FM-1's labels and plausible
 * values, and the graph where the page has one. PROVISIONAL and for testing only: the labels follow SloopKit's
 * SkiffPages (Skiff 2.5.1) and the values are made up; the real core reads both from the FM-1.
 */
internal object FakePageMap {
    private fun num(label: String, v: Int, min: Int = 0, max: Int = 127) = PageControl(label = label, value = v.toString(), raw = v, min = min, max = max)
    private fun lst(label: String, names: List<String>, i: Int = 0) =
        PageControl(label = label, value = names[i], raw = i, min = 0, max = names.size - 1, list = true, names = names)

    private val onOff = listOf("OFF", "ON")
    private val divs = listOf("1/4", "1/8", "1/8T", "1/16", "1/16T", "1/32")
    private val notes = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    private val lanes = listOf("KICK", "SNARE", "CLAP", "CL HAT", "OP HAT", "TOM", "RIM", "BELL")
    private val scaleNames = listOf("CHR", "MAJ", "MIN", "DOR", "MIX", "PEN", "MPEN", "HARM", "PHRY", "LYD", "LOC", "MEL", "BLUES", "WHOLE", "DIMHW", "DIMWH")

    private fun env(a: Int, d: Int, s: Int, r: Int) =
        listOf(num("ATTACK", a), num("DECAY", d), num("SUSTAIN", s), num("RELEASE", r)) to PageGraph(GraphKind.Env, values = listOf(a, d, s, r))

    private fun routes() =
        listOf("PITCH" to 8, "CUTOFF" to 62, "SHAPE" to 0, "AMP" to 30).map { PageRoute("LFO", it.first, it.second) } +
            listOf("PITCH" to 0, "CUTOFF" to 40, "SHAPE" to 0).map { PageRoute("ENV", it.first, it.second) } +
            listOf(PageRoute("SLOTS", "1 ENV2", 44), PageRoute("SLOTS", "2 VEL", 22), PageRoute("SLOTS", "3 —", 0, true), PageRoute("SLOTS", "4 —", 0, true))

    /** The controls and graph for the page titled [title]; null for a title the map doesn't know. */
    fun build(title: String): Pair<List<PageControl?>, PageGraph>? = when (title) {
        "ENV" -> env(12, 48, 64, 90)
        "ENV 2" -> env(30, 60, 40, 70)
        "LFO" -> listOf(num("RATE", 80), lst("WAVE", listOf("SIN", "TRI", "SAW", "SQR", "S&H")), num("PHASE", 0), num("FADE", 0)) to
            PageGraph(GraphKind.Lfo, values = listOf(80, 0, 0, 0), caption = "3.4 Hz")
        "LFO 2" -> listOf(lst("SYNC", listOf("OFF") + divs), lst("TRIG", listOf("FREE", "NOTE")), lst("POLARITY", listOf("BI", "UNI")), lst("ENV SYNC", onOff)) to
            PageGraph(GraphKind.Lfo, values = listOf(80, 0, 0, 0), caption = "3.4 Hz")
        "MOD" -> {
            val r = routes()
            listOf(PageControl("ROUTE", "LFO→CUT", 1, 0, 10, ringless = true), PageControl("SRC", "LFO", fixed = true), PageControl("DEST", "CUTOFF", fixed = true), num("AMT", 62)) to
                PageGraph(GraphKind.Mod, routes = r, picked = 1)
        }
        "FX" -> listOf(num("DIST", 72), num("CHORUS", 20), num("DELAY", 30), num("REVERB", 40)) to PageGraph(GraphKind.Fx, values = listOf(72, 20, 30, 40))
        "DELAY" -> listOf(num("SEND", 30), lst("TIME", divs, 1), num("FEEDBACK", 40), num("COLOR", 64)) to PageGraph()
        "REVERB" -> listOf(num("SEND", 40), lst("TYPE", listOf("ROOM", "HALL", "PLATE"), 1), num("SIZE", 70), num("DAMP", 30)) to PageGraph()
        "DRIVE" -> listOf(num("DIST", 72), lst("TYPE", listOf("TUBE", "HARD", "FOLD", "CRUSH", "FUZZ")), num("TONE", 40), null) to
            PageGraph(GraphKind.Drive, values = listOf(72, 0, 40), caption = "TUBE", side = "drive 72 · tone 40")
        "INSERT" -> listOf(lst("TYPE", listOf("OFF", "FILTR", "COMB", "RING")), num("A", 64), num("B", 40), num("C", 0)) to PageGraph()
        "INSERT 2" -> listOf(num("MIX", 64), null, null, null) to PageGraph()
        "SLICER" -> listOf(lst("SLICER", onOff), num("PATTERN", 3), lst("RATE", divs, 3), num("DEPTH", 80)) to PageGraph()
        "DUCK" -> listOf(lst("BY", listOf("OFF", "T1", "T2", "T3")), num("DEPTH", 60), num("RELEASE", 40), null) to PageGraph()
        "SCALE" -> listOf(lst("ROOT", notes), lst("SCALE", scaleNames, 2), lst("QUANTIZE", onOff, 1), PageControl("TRANSP", "0", 0, -24, 24)) to
            PageGraph(GraphKind.Scale, root = 0, notes = listOf(0, 2, 3, 5, 7, 8, 10), side = "C minor · ● root")
        "CHORD" -> listOf(lst("CHORD", listOf("OFF", "MAJ", "MIN", "7TH")), lst("VOICING", listOf("CLOSE", "OPEN")), PageControl("STRUM", "0 ms", 0, 0, 127), lst("DIR", listOf("UP", "DOWN"))) to PageGraph()
        "FOLLOW" -> listOf(lst("FOLLOW", listOf("OFF", "1", "2", "3")), lst("MODE", listOf("NOTE", "CHORD")), num("NOTE", 0), null) to PageGraph()
        "EDIT 1" -> listOf(lst("WAVE", listOf("SAW", "SQR", "TRI", "SIN", "PWM")), num("DETUNE", 22), num("MIX", 64), num("NOISE", 6)) to
            PageGraph(GraphKind.Analog, values = listOf(0, 22, 64, 6, 70, 30), caption = "OSC · SAW · 2 voices", side = "FILTER · 710 Hz")
        "EDIT 2" -> listOf(num("CUTOFF", 70), num("RESO", 30), null, null) to
            PageGraph(GraphKind.Analog, values = listOf(0, 22, 64, 6, 70, 30), caption = "OSC · SAW · 2 voices", side = "FILTER · 710 Hz")
        "VOICE" -> listOf(lst("VOICE", listOf("MONO", "POLY"), 1), num("GLIDE", 0), lst("GL MODE", listOf("ALWAYS", "LEGATO")), lst("PRIORITY", listOf("LAST", "LOW", "HIGH"))) to PageGraph()
        "VOICE 2" -> listOf(lst("ALLOC", listOf("ROBIN", "FIRST")), num("DETUNE", 8), num("SPREAD", 20), null) to PageGraph()
        "LANES" -> listOf(PageControl("LANE", "SNARE", 1, 0, 7, list = true, ringless = true, names = lanes), num("LEVEL", 100), PageControl("TUNE", "-3", 61), num("DECAY", 44)) to
            PageGraph(GraphKind.Tiles, tiles = lanes.map { PageTile(it) }, picked = 1)
        "LANE MIX" -> listOf(PageControl("LANE", "SNARE", 1, 0, 7, list = true, ringless = true, names = lanes), num("LEVEL", 100), PageControl("PAN", "C", 64), null) to
            PageGraph(GraphKind.Tiles, tiles = lanes.map { PageTile(it) }, picked = 1)
        "OPERATOR" -> List<PageControl?>(4) { null } to PageGraph(GraphKind.Card, title = "OP 2 · RATIO")
        "ALL OPS" -> List<PageControl?>(4) { null } to PageGraph(GraphKind.Card, title = "ALL OPS · OP 3 · LEVEL")
        "ARP" -> listOf(lst("MODE", listOf("OFF", "UP", "DOWN", "UP/DN", "RAND"), 1), lst("RATE", divs, 3), PageControl("OCTAVE", "2", 2, 1, 4), PageControl("GATE", "60%", 76)) to
            PageGraph(GraphKind.Arp, values = listOf(1, 3, 2, 76, 0, 127, 0, 0), side = "UP · 2 oct · 1/16 · gate 60%")
        "ARP 2" -> listOf(num("SWING", 0), PageControl("CHANCE", "100%", 127), lst("HOLD", onOff), lst("ORDER", listOf("UP", "DOWN"))) to
            PageGraph(GraphKind.Arp, values = listOf(1, 3, 2, 76, 0, 127, 0, 0), side = "UP · 2 oct · 1/16 · gate 60%")
        else -> null
    }
}
