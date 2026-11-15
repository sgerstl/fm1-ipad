# Device check: claude/skiffdraw-all-pages (SkiffDraw on every sound page, Android), 2026-11-15

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel with the FM-1 on Skiff-Lupe 2.5.1, THEME SKIFF, Settings › Show graphics on. Everything is read-only; no backup needed. Expected look: `qa/skiffdraw-android-2026-11-15/all-sound-pages-fake-2.5.1.png` (the fake's ANALOG track 1).

| # | Do this | You should see | Result |
|---|---|---|---|
| 1 | SEL 1/3 SCALE, 2/3 CHORD, 3/3 FOLLOW; change ROOT and SCALE. | SCALE: the FM-1's octave of bars, root white, in the track's colour. CHORD and FOLLOW: the FM-1's own text or chord picture. (While a chord key is held, or the followed track plays, the FM-1 shows the live chord and the phone shows the setting: expected.) | ☐ pass ☐ fail: |
| 2 | FX 1/7 FX, DRIVE, INSERT, SLICER, DUCK (with BY set to a track that has steps). | FX's four send sliders, DRIVE's curve and wave, INSERT's curve with its MIX card, SLICER's gates, DUCK's dips under the source track's hits, all as on the FM-1. | ☐ pass ☐ fail: |
| 3 | LFO › MOD; turn KNOB 1 through the routes. | Lupe's route tiles stay (tappable). Under them, the FM-1's route table with the same route lit, when the panel is tall enough (each half ≥ 2× the FM-1's pixels); otherwise only the tiles. | ☐ pass ☐ fail: |
| 4 | EDIT › VOICE and VOICE 2; ARP and ARP 2. | VOICE's picture (LEG / POLY with glide), VOICE 2's voice grid, ARP's example pattern. (Notes being held or sounding show on the FM-1 only: expected.) | ☐ pass ☐ fail: |
| 5 | An FM6 track: OPERATOR, then ALL OPS; on the FM-1 move SELECT. | Lupe's operator tiles; the FM-1's sheet under them with the same operator and window lit. | ☐ pass ☐ fail: |
| 6 | A DRUM-X track: LANES, LANE MIX, SOUND; pick lanes on the FM-1. | Lupe's lane / sound tiles; the FM-1's picture under them with the same lane lit and the kit's own values. | ☐ pass ☐ fail: |
| 7 | A SAMPLE track's EDIT pages and SAMPLES; a SLICE track's SLICES. | The phone's own hand-drawn pictures (the waveforms live in the FM-1's flash). | ☐ pass ☐ fail: |
| 8 | GLO's four pages again. | Unchanged from the last check: grey, filling the box. | ☐ pass ☐ fail: |

**Not covered:** TalkBack wording (the description is the page's title plus the old one where there was one, else "the FM-1's picture"), other THEMEs, iOS (unchanged).
