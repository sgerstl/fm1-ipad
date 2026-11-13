package com.scottgerstl.lupe.core

/**
 * What the fake knows of P5's areas (mix, sounds, projects), so the screens can be driven without an FM-1. Recordings
 * from P1's core (fixtures ready, lost) carry the real state; scenarios without them are seeded from the pads' names.
 * The refusals copy P1's core (P5State.kt): an unconfirmed store over a used slot, a load over changes, a save over
 * the music's own slot.
 */
object FakeP5 {
    val engineNames = listOf("ANALOG", "-", "PHASE", "LOFI", "SAMPLE", "VOICE", "TRIO", "WHEEL", "GRAIN", "PHYS", "DRUM")

    fun presetNames(engine: Int): List<String> = List(if (engine == 10) 8 else 12) { i -> "${engineNames.getOrElse(engine) { "ENG" }} ${i + 1}" }

    fun seedMix(names: List<String>, selected: Int): MixState = MixState(
        sections = listOf(MixSection("mixer", "Mixer", 30), MixSection("delay", "Delay", 31), MixSection("reverb", "Reverb", 32), MixSection("chorus", "Chorus", 33), MixSection("global", "Global", 34)),
        rows = names.mapIndexed { i, n -> MixRow(i + 1, n, selected = i + 1 == selected, level = 90 + i * 4, levelText = db(90 + i * 4), reverb = 10 + i * 12, reverbText = "${(10 + i * 12) * 100 / 127}%") },
    )

    fun db(level: Int) = if (level <= 0) "OFF" else "${((level - 100) * 0.4f).toInt()} dB"

    fun card(section: String): MixCard? = when (section) {
        "delay" -> MixCard("Delay", listOf(PageControl("TIME", "3/16", 40, 0, 127, list = true), PageControl("FEEDBACK", "62", 62), PageControl("COLOR", "70", 70), PageControl("MIX", "30", 30)),
            settings = listOf(PageControl("DELAY MODE", "STEREO", 0, 0, 2, list = true, names = listOf("STEREO", "PING-PONG", "MONO"))))
        "reverb" -> MixCard("Reverb", listOf(PageControl("TYPE", "ROOM", 1, 0, 3, list = true), PageControl("SIZE", "70", 70), PageControl("DAMP", "40", 40), PageControl("MIX", "25", 25)))
        "chorus" -> MixCard("Chorus", listOf(PageControl("RATE", "50", 50), PageControl("DEPTH", "60", 60), PageControl("MIX", "30", 30), null))
        "global" -> MixCard("Global", listOf(PageControl("TEMPO", "120", 120), PageControl("SWING", "0", 0), PageControl("MASTER", "100", 100), PageControl("TRANSPOSE", "0", 64)))
        else -> null
    }

    fun seedSounds(track: Int, name: String): SoundsState = SoundsState(
        target = SoundTarget(track), trackName = name, engine = 0, preset = 0,
        engines = engineNames.mapIndexed { i, n -> SoundEngine(i, n, offered = n != "-", kit = n == "DRUM") },
        viewing = 0, presets = presetNames(0).mapIndexed { i, n -> SoundPreset(i, n, current = i == 0) },
        user = List(32) { UserSlot(it, used = it < 3, name = if (it < 3) "USER ${it + 1}" else "") },
    )

    fun seedProjects(): ProjectsState = ProjectsState(
        slots = listOf(ProjectSlot(0, true, "NIGHT DRIVE", current = true), ProjectSlot(1, true, "KOTO"), ProjectSlot(2), ProjectSlot(3, true, "ACID TEST")),
        name = "NIGHT DRIVE", changed = true,
    )

    // ---- mix

    fun mix(s: MixState, i: Intent): MixState = when (i) {
        is MixSectionPick -> s.copy(section = i.section, card = card(i.section))
        is SetLevel -> row(s, i.track) { it.copy(level = i.value.coerceIn(0, 127), levelText = db(i.value.coerceIn(0, 127))) }
        is SetPan -> row(s, i.track) { it.copy(pan = i.value.coerceIn(-64, 63), panText = pan(i.value.coerceIn(-64, 63))) }
        is SetReverb -> row(s, i.track) { it.copy(reverb = i.value.coerceIn(0, it.reverbMax), reverbText = "${i.value * 100 / it.reverbMax}%") }
        is TrackSolo -> row(s, i.track) { it.copy(solo = !it.solo) }
        is Intent.TrackMute -> row(s, i.track) { it.copy(mute = !it.mute) }
        is Intent.TrackSelect -> s.copy(rows = s.rows.map { it.copy(selected = it.track == i.track) })
        is SetMixSetting -> s.copy(card = s.card?.copy(settings = s.card.settings.mapIndexed { n, c -> if (n == i.index) c.copy(raw = i.value, value = c.names.getOrElse(i.value) { c.value }) else c }))
        is SetMixParam -> s.copy(card = s.card?.copy(controls = s.card.controls.mapIndexed { n, c -> if (n == i.slot && c != null) c.copy(raw = i.value, value = if (c.list && c.names.isNotEmpty()) c.names.getOrElse(i.value) { c.value } else if (c.list) c.value else "${i.value}") else c }))
        else -> s
    }

    private fun row(s: MixState, track: Int, f: (MixRow) -> MixRow) = s.copy(rows = s.rows.map { if (it.track == track) f(it) else it })
    fun pan(v: Int) = when { v == 0 -> "C"; v < 0 -> "L${-v}"; else -> "R$v" }

    // ---- sounds

    fun sounds(s: SoundsState, i: Intent, userNameOf: (Int) -> String = { "USER ${it + 1}" }): SoundsState = when (i) {
        is SoundsTargetPick -> s.copy(target = SoundTarget(i.track, i.entry), refusal = null)
        is SoundsView -> s.copy(viewing = i.engine, presets = presetNames(i.engine).mapIndexed { n, name -> SoundPreset(n, name, current = s.engine == i.engine && s.preset == n) })
        is PickPreset ->
            if (s.target.entry != null) s.copy(entrySound = EntrySound("preset", i.engine, i.preset, name = "${s.engines.getOrNull(i.engine)?.name ?: ""} ${presetNames(i.engine).getOrElse(i.preset) { "" }}".trim()), refusal = null)
            else s.copy(engine = i.engine, preset = i.preset, presets = presetNames(s.viewing).mapIndexed { n, name -> SoundPreset(n, name, current = s.viewing == i.engine && n == i.preset) }, refusal = null)
        is PickUser -> s.copy(user = s.user.map { it.copy(current = it.slot == i.slot) }, refusal = if (s.user.getOrNull(i.slot)?.used == true) null else "User slot ${i.slot + 1} is empty")
        is ClearEntrySound -> s.copy(entrySound = null)
        is SaveSound -> {
            val used = s.user.getOrNull(i.slot)?.used == true
            if (used && !i.confirmed) s.copy(refusal = "User slot ${i.slot + 1} holds ${s.user[i.slot].name}: confirm to replace it")
            else s.copy(user = s.user.map { if (it.slot == i.slot) it.copy(used = true, name = i.name, engine = s.engine, engineName = s.engines.getOrNull(s.engine)?.name, current = true) else it }, refusal = null)
        }
        is EraseUser -> if (!i.confirmed) s.copy(refusal = "Confirm to erase user slot ${i.slot + 1}") else s.copy(user = s.user.map { if (it.slot == i.slot) UserSlot(it.slot) else it }, refusal = null)
        else -> s
    }

    // ---- projects

    fun projects(s: ProjectsState, i: Intent): ProjectsState = when (i) {
        is ProjectLoad ->
            if (s.changed && !i.confirmed) s
            else s.copy(slots = s.slots.map { it.copy(current = it.slot == i.slot) }, name = s.slots.getOrNull(i.slot)?.name.orEmpty(), changed = false)
        is ProjectSave -> if (!i.confirmed) s else s.copy(changed = false)
        is ProjectSaveAs -> {
            val used = s.slots.getOrNull(i.slot)?.used == true
            if (used && !i.confirmed) s else s.copy(slots = s.slots.map { if (it.slot == i.slot) ProjectSlot(it.slot, true, i.name, current = true) else it.copy(current = false) }, name = i.name, changed = false)
        }
        is ProjectRename -> s.copy(slots = s.slots.map { if (it.slot == i.slot) it.copy(name = i.name) else it }, name = if (s.slots.getOrNull(i.slot)?.current == true) i.name else s.name)
        else -> s
    }
}
