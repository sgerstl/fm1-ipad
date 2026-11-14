package com.scottgerstl.lupe.core

/**
 * What the fake core shows for a page the fixtures don't carry: the four controls with the FM-1's labels and plausible
 * values, and the tiles where a knob picks from names. PROVISIONAL and for testing only: the labels follow SloopKit's
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

    private fun env(a: Int, d: Int, s: Int, r: Int) = listOf(num("ATTACK", a), num("DECAY", d), num("SUSTAIN", s), num("RELEASE", r)) to null as PageTilesState?

    private fun routes() =
        listOf("PITCH" to 8, "CUTOFF" to 62, "SHAPE" to 0, "AMP" to 30).map { PageRoute("LFO", it.first, it.second) } +
            listOf("PITCH" to 0, "CUTOFF" to 40, "SHAPE" to 0).map { PageRoute("ENV", it.first, it.second) } +
            listOf(PageRoute("SLOTS", "1 ENV2", 44), PageRoute("SLOTS", "2 VEL", 22), PageRoute("SLOTS", "3 —", 0, true), PageRoute("SLOTS", "4 —", 0, true))

    private val none: PageTilesState? = null

    /** The controls and tiles for the page titled [title]; null for a title the map doesn't know. */
    fun build(title: String): Pair<List<PageControl?>, PageTilesState?>? = when (title) {
        "ENV" -> env(12, 48, 64, 90)
        "ENV 2" -> env(30, 60, 40, 70)
        "LFO" -> listOf(num("RATE", 80), lst("WAVE", listOf("SIN", "TRI", "SAW", "SQR", "S&H")), num("PHASE", 0), num("FADE", 0)) to none
        "LFO 2" -> listOf(lst("SYNC", listOf("OFF", "4BAR", "2BAR", "1/1", "1/2", "1/4", "1/8", "8T", "1/16", "16T", "1/32")), lst("TRIG", listOf("NOTE", "FREE")), lst("POLARITY", listOf("BI", "UNI")), lst("ENV SYNC", onOff)) to none
        "MOD" -> listOf(PageControl("ROUTE", "LFO→CUT", 1, 0, 10, ringless = true), PageControl("SRC", "LFO", fixed = true), PageControl("DEST", "CUTOFF", fixed = true), num("AMT", 62)) to
            PageTilesState("routes", routes = routes(), picked = 1)
        "FX" -> listOf(num("DIST", 72), num("CHORUS", 20), num("DELAY", 30), num("REVERB", 40)) to none
        "DELAY" -> listOf(num("SEND", 30), lst("TIME", divs, 1), num("FEEDBACK", 40), num("COLOR", 64)) to none
        "REVERB" -> listOf(num("SEND", 40), lst("TYPE", listOf("ROOM", "SPRING", "HALL"), 2), num("SIZE", 70), num("DAMP", 30)) to none
        "DRIVE" -> listOf(num("DIST", 72), lst("TYPE", listOf("SOFT", "HARD", "FOLD", "CRUSH", "FUZZ")), num("TONE", 40), null) to none
        "INSERT" -> listOf(lst("TYPE", listOf("OFF", "FILTR", "COMB", "RING")), num("A", 64), num("B", 40), num("C", 0)) to none
        "INSERT 2" -> listOf(num("MIX", 64), null, null, null) to none
        "SLICER" -> listOf(lst("SLICER", onOff), num("PATTERN", 3), lst("RATE", divs, 3), num("DEPTH", 80)) to none
        "DUCK" -> listOf(lst("BY", listOf("OFF", "T1", "T2", "T3")), num("DEPTH", 60), num("RELEASE", 40), null) to none
        "SCALE" -> listOf(lst("ROOT", notes), lst("SCALE", scaleNames, 2), lst("QUANTIZE", onOff, 1), PageControl("TRANSP", "0", 0, -24, 24)) to none
        "CHORD" -> listOf(lst("CHORD", listOf("OFF", "MAJ", "MIN", "7TH")), lst("VOICING", listOf("CLOSE", "OPEN")), PageControl("STRUM", "0 ms", 0, 0, 127), lst("DIR", listOf("UP", "DOWN"))) to none
        "FOLLOW" -> listOf(lst("FOLLOW", listOf("OFF", "1", "2", "3")), lst("MODE", listOf("NOTE", "CHORD")), num("NOTE", 0), null) to none
        "EDIT 1" -> listOf(lst("WAVE", listOf("SAW", "SQR", "TRI", "SIN", "PWM")), num("DETUNE", 22), num("MIX", 64), num("NOISE", 6)) to none
        "EDIT 2" -> listOf(num("CUTOFF", 70), num("RESO", 30), null, null) to none
        "VOICE" -> listOf(lst("VOICE", listOf("POLY", "MONO", "LEG", "UNI")), num("GLIDE", 0), lst("GL MODE", listOf("ALWAYS", "LEGATO")), lst("PRIORITY", listOf("LAST", "LOW", "HIGH"))) to none
        "VOICE 2" -> listOf(lst("ALLOC", listOf("ROBIN", "FIRST")), num("DETUNE", 8), num("SPREAD", 20), null) to none
        "LANES" -> listOf(PageControl("LANE", "SNARE", 1, 0, 7, list = true, ringless = true, names = lanes), num("LEVEL", 100), PageControl("TUNE", "-3", 61), num("DECAY", 44)) to
            PageTilesState("pick", labels = lanes, picked = 1)
        "LANE MIX" -> listOf(PageControl("LANE", "SNARE", 1, 0, 7, list = true, ringless = true, names = lanes), num("LEVEL", 100), PageControl("PAN", "C", 64), null) to
            PageTilesState("pick", labels = lanes, picked = 1)
        // the dense pages carry the four controls the FM-1's knobs turn (decision 25), with the operator or sound picked as tiles
        "OPERATOR" -> listOf(num("RATE 1", 99), num("LEVEL 1", 99), num("RATE 2", 60), num("LEVEL 2", 80)) to PageTilesState("pick", labels = (1..6).map { "OP$it" }, picked = 3)
        "ALL OPS" -> listOf(num("ALGO", 1, 1, 32), num("FEEDBACK", 3), null, null) to none
        "SOUND" -> listOf(num("PITCH A", 56), num("PITCH B", 52), num("P MOD A", 0), num("P MOD B", 0)) to PageTilesState("pick", labels = listOf("BD", "SD", "CP", "CH", "OH", "TM", "RS", "CB"), picked = 1)
        "SLICES" -> List<PageControl?>(4) { null } to none
        "ARP" -> listOf(lst("MODE", listOf("OFF", "UP", "DOWN", "UP/DN", "RAND"), 1), lst("RATE", divs, 3), PageControl("OCTAVE", "2", 2, 1, 4), PageControl("GATE", "60%", 76)) to none
        "ARP 2" -> listOf(num("SWING", 0), PageControl("CHANCE", "100%", 127), lst("HOLD", onOff), lst("ORDER", listOf("UP", "DOWN"))) to none
        else -> null
    }

    /** An FM6 patch to draw: algorithm 5, a carrier and two modulators with different envelopes. Made up. */
    private fun fm6() = Fm6Patch(
        algorithm = 4, feedback = 3, picked = 2, lit = 1,
        ops = listOf(
            Fm6Operator(99, "1×", listOf(90, 60, 40, 55), listOf(99, 80, 60, 0)), Fm6Operator(70, "2×", listOf(80, 50, 30, 45), listOf(99, 70, 40, 0)),
            Fm6Operator(99, "1×", listOf(95, 70, 50, 60), listOf(99, 90, 70, 0)), Fm6Operator(60, "3×", listOf(70, 40, 35, 50), listOf(99, 60, 30, 0)),
            Fm6Operator(99, "0.5×", listOf(85, 55, 45, 65), listOf(99, 85, 65, 0)), Fm6Operator(0, "1×", listOf(99, 99, 99, 99), listOf(99, 99, 99, 0)),
        ),
        lines = listOf("TRANSPOSE 0 st", "LFO SINE · RATE 35 · FADE 0", "VIBRATO 0 · TREMOLO 0"),
    )

    private fun sheet(): SoundSheet {
        fun c(l: String, v: String) = SheetCell(l, v)
        return SoundSheet(
            lane = 2, lanes = listOf("BD", "SD", "CP", "CH", "OH", "TM", "RS", "CB"), lit = 1,
            rows = listOf(
                SheetRow("PITCH", listOf(c("PITCH A", "56"), c("PITCH B", "52"), c("P MOD A", "0"), c("P MOD B", "0"))),
                SheetRow("DECAY NOISE", listOf(c("DECAY A", "40"), c("DECAY B", "60"), c("NOISE A", "20"), c("NOISE B", "30"))),
                SheetRow("COLOR LEVEL", listOf(c("COLOR A", "64"), c("COLOR B", "80"), c("LEVEL", "100"), c("DRIVE", "OFF"))),
                SheetRow("MODE", listOf(c("WAVE", "SIN"), c("FILTER", "LP"), c("SNAP", "OFF"), c("P SHAPE", "DECAY"))),
            ),
            note = "The kit is the project's: every DRUM-X track plays it, MORPH blending A into B.",
        )
    }

    /** The picture for the page titled [title], from its controls' values (decision 30: Show graphics); none for a page without one. */
    fun graph(title: String, controls: List<PageControl?>): PageGraph {
        val v = controls.map { it?.raw ?: 0 }
        return when (title) {
            "ENV", "ENV 2" -> PageGraph(GraphKind.Env, values = v)
            "LFO", "LFO 2" -> PageGraph(GraphKind.Lfo, values = if (title == "LFO") v else listOf(80, 0, 0, 0), caption = "3.4 Hz")
            "FX" -> PageGraph(GraphKind.Fx, values = v)
            "DRIVE" -> PageGraph(GraphKind.Drive, values = v.take(3), caption = controls.getOrNull(1)?.value ?: "TUBE", side = "drive ${v[0]} · tone ${v[2]}")
            "SCALE" -> PageGraph(GraphKind.Scale, root = v[0], notes = listOf(0, 2, 3, 5, 7, 8, 10), side = "C minor · ● root")
            "EDIT 1" -> PageGraph(GraphKind.Analog, values = listOf(v[0], v[1], v[2], v[3], 70, 30), caption = "OSC · SAW · 2 voices", side = "FILTER · 710 Hz")
            "EDIT 2" -> PageGraph(GraphKind.Analog, values = listOf(0, 22, 64, 6, v[0], v[1]), caption = "OSC · SAW · 2 voices", side = "FILTER · 710 Hz")
            "ARP" -> PageGraph(GraphKind.Arp, values = listOf(v[0], v[1], v[2], v[3], 0, 127, 0, 0), side = "UP · 2 oct · 1/16 · gate 60%")
            "ARP 2" -> PageGraph(GraphKind.Arp, values = listOf(1, 3, 2, 76, v[0], v[1], v[2], v[3]), side = "UP · 2 oct · 1/16 · gate 60%")
            "OPERATOR" -> PageGraph(GraphKind.Fm6Op, fm6 = fm6(), title = "OPERATOR · 2")
            "ALL OPS" -> PageGraph(GraphKind.Fm6All, fm6 = fm6().copy(algorithm = (v[0] - 1).coerceIn(0, 31), feedback = v[1].coerceIn(0, 7)), title = "ALL OPS")
            "SOUND" -> PageGraph(GraphKind.Sound, sheet = sheet())
            else -> PageGraph()
        }
    }
}
