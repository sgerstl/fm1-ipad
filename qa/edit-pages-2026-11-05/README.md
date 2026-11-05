# Skiff's EDIT engine pages, 2026-11-05

Scott: "let's get em done." These are the pages the FM-1's EDIT button shows after EDIT 1 and 2, laid out as on Skiff 2.2 (params.c PAGES 16–22, ui.c page_visible). The research is in the session notes' `edit-pages-spec.md`.

| Page | Shown on | Edits | How |
|---|---|---|---|
| OPERATOR (16) | FM6 | the track's patch, one operator: TONE, ENV 1, ENV 2, KEYS, MORE | FM6_GET / FM6_PUT (68, 69), whole patch |
| ALL OPS (17) | FM6 | the patch's voice: ALGO, PITCH 1 and 2, LFO, DEPTH | the same; ALGO and FEEDBACK also set their macros (P_E0, P_E1) back to 0, as the FM-1 does |
| LANES (18) | DRUM | a lane's LEVEL, TUNE, DECAY | track parameters (83+, 101+, 109+) |
| SOUND (19) | DRUM-X | a kit sound's A and B values, its mode, and LEVEL | KIT_GET / KIT_PUT (74, 75); LEVEL is the track's lane level |
| LANE MIX (20) | DRUM, DRUM-X | a lane's LEVEL, PAN | track parameters (83+, 127+; PAN 128+ goes out as wide ids) |
| SLICES (21) | SLICE | SOURCE and DIV here, plus "Open on the FM-1" | track parameters; no command reaches the markers |
| SAMPLES (22) | SAMPLE on USR1–3 | each sound's LEVEL, REVERB, DELAY | SMP_MIX (81), whole set |

OP1–OP4 ENV and OP LEVEL (23–27) are left out. They belong to DIGITAL, which Skiff 2.2 doesn't build, so no track ever shows them.

**Rules Skiff applies, now applied here too:** the one-shot kits (DRUM, DRUM-X) have no SCL, ENV or VOICE pages, and FM6 has no ENV. Their pads dim as on any empty button.

**KNOB 1's pick** comes from tiles or a knob on each page: the lane (shared by LANES, LANE MIX and SOUND), the sound on SAMPLES, the operator on OPERATOR (ALL OPS lights it in the chart). With the screen link's cursor build (`56 01 02`) the pick is the FM-1's, both ways, as MOD's route is. On a sheet (OPERATOR, ALL OPS, SOUND), the row the FM-1's knobs are on (SELECT steps it) is lit from SCREEN's second cursor.

**Not pushed:** Skiff never says when the patch, the kit or a mix changes on the FM-1. Each page reads its data when it opens, when the pick changes, and whenever the FM-1's screen state moves. A knob drag sends one write at a time, the latest value going out when the write before it is answered (`SkiffEditStore`). After a patch write, the track's PATCH parameter is read again, since Skiff sets it to OWN or F n.

**Formats:** Skiff's ST16 (format 14: TUNE, ±12 st in 3/16 steps) and its BIPCT (÷63 above zero) are now used on Skiff. Before, TUNE would have shown as SLOOP's swing.

## Checked

- `swift test`: all suites, including the new `SkiffEditTests`:
  - the patch's bit packing against eng_fm6.c;
  - a patch, a kit sound and a mix round trip through FakeSkiff;
  - a drag ending on its last value;
  - an empty user set.
- `SkiffTests` checks the page order and the lane ids found from the fixture.
- The simulator, with `-demo -demo-skiff -demo-link -page sound -family EDIT` and:
  - `-demo-track 4` (DRUM): `lanes-drum.jpg`;
  - `-demo-track 2` (FM6): `fm6.jpg`;
  - `-demo-track 5 -demo-usr` (SAMPLE on USR1): `samples.jpg`;
  - `-demo-track 6 -demo-engine 14` (DRUM-X): `drum-x.jpg`;
  - `-demo-track 3 -demo-engine 13` (SLICE): `slices.jpg`.
- In the demo, EDIT 1 and 2 and SLICES' knobs carry ANALOG's labels, because the fixture only recorded ANALOG's engine DESC. On the FM-1 they're the engine's own.

## Not checked

- **A real FM-1 or skiff-sim** for commands 68, 69, 74, 75 and 81. The byte layouts are from Skiff's source and its protocol doc, exercised against the fake only.
- **The pick following the FM-1** on these pages: it's the same path as MOD's, which has a test, but there's no test per page.
- **VoiceOver** through the sheets' rows.

## Design pre-flight

Ran it. Every card uses Shape's existing parts: the numbered columns, the merged-card row labels (here the FM-1's windows), the selected-key colours for tiles, and the recessed graph wells. The only new drawings are the lane faders, the zone map, the algorithm chart and the envelope lines, in the track's colour with white for the pick. All targets are 44 pt or more except the lane faders' tap columns, which are full height and about 50 pt wide. There's no motion.

## For the polish pass (cramped or uncertain)

- **The FM6 envelope graph is a sketch.** It uses rates as times and levels as heights, held at LEVEL 3. It isn't msfa's envelope run, so it doesn't have Skiff's heat colouring or its log time axis.
- **Graphs not ported:** KEYS and MORE's keyboard-scaling curve, ALL OPS' pitch-envelope and LFO drawings, SOUND's A/B bar table, and SAMPLES' waveform (only reachable through a backup, which stops the transport).
- **The OPERATOR and ALL OPS cards are tall** (five rows each), and the two sit side by side with the EDIT 1 and 2 cards above them.
- **SAMPLES' row** has an empty first column, because the tiles do KNOB 1's job.
- **LANES doesn't apply Skiff's per-kit lane names:** TOM becomes CONGA, RIM becomes CLAVE and BELL becomes CYM on some kits, and the user kits' empty lanes aren't dimmed.
- **On DRUM, LANES' lane isn't tied to the drum grid's selected lane**, as it is on the FM-1.

## ARP and ARP 2 graphs (added after)

Both cards draw Skiff's graph_arp (ui_pgraph.c):
- the arp's notes over 16 steps through OCTAVE and MODE (all fifteen modes, RND and WALK on Skiff's fixed picks, CHORD stacked);
- tiles as long as GATE, the off steps late by SWING, every fourth step white;
- the steps CHANCE would skip, outlined;
- all of it dim while MODE is OFF (`arp.jpg`).

It always shows Skiff's example chord, C E G. The protocol doesn't say which keys the FM-1 holds, so the "held notes" version can't be drawn. HOLD and ORDER don't change the drawing on the FM-1 either.
