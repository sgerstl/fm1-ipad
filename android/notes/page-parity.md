# Page parity with the FM-1 (decision 22, "match first")

2026-11-14, P1. The check is `android/core/Tests/LupeCoreTests/PageParityTests.swift`
(`everySoundPageMatchesTheFM1`). It compares PhoneCore's page area with what the FM-1 on Skiff 2.5.1 draws.

The FM-1's side is printed by Skiff's own code, not by our reading of it. `android/scripts/skiff-page-dump.sh` exports
the v2.5.1 tag and builds `android/tools/skiff-pagedump/pagedump.c` against Skiff's `tests/ui_test.c`. The dump uses
the firmware's `PAGES`, `page_visible`, `page_desc`, `track_desc` and `param_format`. The result is
`android/fixtures/skiff/skiff-2.5.1-pages.json`.

## What it checks (on FakeSkiff 2.5.1, through the phone's own intents)

For each of the 14 engines, at its first preset, loaded with `pickPreset` as the FM-1 loads it on an engine change:

- **Reach:** which pages each family's key steps through. This is the FM-1's `page_visible` against the page row
  the phone shows (`SoundPage.counted(reached)`).
- **Labels:** the four labels of every page reached.
- **Values:** each knob's text at a spread of raw values: every value of a list, and for a number the ends, the
  default and about a dozen steps between.

The phone writes the FM-1's value and unit (two lines on its screen) as one string: "15.2 kHz", "47%".

The check also covers INSERT under each of its 10 TYPEs and ENV with ENV SYNC on. It also covers HOME's four knobs
for each engine (decision 21): which parameters they are (`SkiffHomeKnobs` against each engine's `.knob` line,
through `home_param`), their labels, and their text. That makes 289 checks, with no mismatches except the sharp
sign below.

## The sheets (decision 25, 2026-11-14)

FM6's OPERATOR and ALL OPS, and DRUM-X's SOUND, are sheets on the FM-1: their four knobs are a window over a table,
which SELECT moves (Skiff `ui.c sheet_t`). The page area now gives the four the FM-1's knobs turn now. That's the
window the FM-1 is on, of the operator or sound picked, from the screen link's two cursors. The values come from the
patch (FM6_GET) or the kit sound (KIT_GET). `PhoneCore/Sheets.swift` ports `ui_fm6.c` and `ui_dx.c`.
`everySheetMatchesTheFM1` checks every window's labels and every card's text at every value against Skiff's own
`fm_val` and `dx_cards` tables, and FINE in all eight mode and coarse cases: no mismatches. setParam writes the patch
or the kit sound back whole (FM6_PUT, KIT_PUT). ALGO and FEEDBACK do what the FM-1's knob does: they write what plays
into the patch and set EDIT 1's ALGO or FEEDBACK back to neutral. SOUND's LEVEL is the lane's track parameter.

What the link can't do, and the smallest fix:

- **The phone can't move a sheet's window.** The second cursor is read only (EDITOR_PROTOCOL.md: SCREEN_GOTO sets
  the first cursor only). The phone shows the window the FM-1 is on and follows its SELECT, but has no way to walk the
  sheet itself. **Smallest fix: firmware.** On the three sheet pages, let SCREEN_GOTO take a third byte that sets the
  window. That's a few lines in the screen-link patch, beside its cursor byte. Then a `pickWindow` intent can follow.
  The alternative, a window kept on the phone apart from the FM-1's, would show four knobs the FM-1's knobs don't turn,
  against decision 25.
- **The FM-1 pushes no patch or kit change.** When its own knob turns an operator value, nothing reaches the phone.
  **Fixed on the phone:** while a sheet shows, its patch or sound is read again every 300 ms (one FM6_GET or KIT_GET).
  The store skips a read within a second of the phone's own edit. A firmware push (a CHANGED for the patch) would
  replace the reads, but isn't needed now.
- **The operator and sound pickers:** pickTile moves the first cursor (SCREEN_GOTO's second byte), so the phone can
  pick them.

## Fixed in this pass (2026-11-14)

1. **Skiff's number rules** (`DeviceDisplay.skiffValue`, used wherever `formatValue(…, skiff: true)` is):
   - No 0 before a point: Skiff writes ".05 Hz" and "-.5" (`libc.c fmt_fix`).
   - Percent is a share of 127 unless the range is 0..100. GLO › DELAY FEEDBACK (0..120) read 50% where the FM-1
     shows 47%.
   - CUTOFF is in tenths of a kHz all the way up: "15.2 kHz", not "15 kHz".
   - dB always shows a tenth: "-55.5 dB", not "-56 dB".

   SLOOP's rules are unchanged. **This changes the iPad too**: its Sound tab, graphs and track chips on Skiff use these.
2. **FM6's ALGO and PATCH names:** "PAT", 1..32; F1..F8, OWN. They are numbers with a name list, and DESC sends names
   only for lists, so they are written in `SkiffDisplay.engineDesc` as the other engines' hooks are.
3. **The engine's knobs after a preset of another engine:** Skiff pushes nothing for a PRESET the editor sent
   (`editor.c ed_load_after`). Until now the EDIT pages kept the last engine's names and values until the track was
   selected again. `Session.loadPreset` now reads them after the reply on Skiff. **iPad too.**
4. **A knob the FM-1 labels "-"** (SAMPLE's EDIT 2, knobs 2 and 4) is a blank column, as on the FM-1, not a control.
   This is PhoneCore only.
5. **FakeSkiff** (rule 5, taught from Skiff's own tables: `tests/descdump.c` → `skiff-2.5.1-engines.json`):
   - DESC answers the track's engine's EDIT descriptors.
   - PRESET loads the preset's values, with no push, as the firmware does.
   - The 2.2 SAMPLE SET names no longer stand in for 2.5.1's.

## Open, for Scott

- **♯ or #.** The phone writes the sharp sign (C♯, F♯) where the FM-1's font has "#". It's the same note, and the
  sign comes from `Music.noteNames`, which the editor, the piano roll and VoiceOver use too. The test treats them as
  equal. Say if the phone should write "#" here.
- **MOD.** The FM-1 draws the route on its picture. Its columns are blank for a fixed route, except knob 4, which it
  labels with the route's destination ("PITCH"). The phone shows ROUTE, SRC, DEST, AMT (P4's layout). Is that
  difference kept on purpose?
- **LANES and LANE MIX.** The FM-1 draws LANE above the columns; the phone makes it control 1. The values of LEVEL,
  TUNE, DECAY and PAN follow the same rules, but only lane 1's are reached by the test.

## What the test can't decide

- **Pictures** (ENV, LFO, DRIVE, FX, SCALE, CHORD, ARP, ANALOG's wave, MOD's routes): drawn, not printed. Decision 22's
  second half ("then pictures") is checked by eye, family by family.
- **Sheets:** OPERATOR and ALL OPS (FM6), SOUND (DRUM-X), SLICES and SAMPLES. The FM-1 draws them as sheets, and the
  phone's own versions are read-only pictures. Their reach is checked; their contents aren't.
- **GLO's pages** (DELAY, REVERB, CHORUS, GLOBAL): on the phone they are Mix's cards (P5), not the page area. Their
  values use the same `formatValue`, so the number rules above hold there too, but no test walks the cards.
- **Engine modes past the first preset.** Labels that change with an engine's own mode (ANALOG's SYNC and SUB waves,
  PHYS's four models, LOFI's STEP and WRAM, NOISE's LFSR and META) are checked at each engine's first preset only.
  The dump could step through each mode the same way it does INSERT's TYPEs.
- **A knob's travel order.** For divisions, the FM-1's knob and gauge go longest first (`params.c DIV_ORDER`,
  `SLDIV_ORDER`, `DTIME_ORDER`: 4BAR 2BAR 1/1 … with the triplets between their neighbours), not in the stored
  order. The test checks the text of each value, not the order a slide passes them in.
- **Dimmed columns** (`card_dead`: a control that does nothing in the current state) aren't compared.
- **Light tracks** (T5, T6) refuse some engines. That isn't covered: the test loads every engine on track 1.

## Running it again

```bash
android/scripts/skiff-page-dump.sh            # after a Skiff release: point SKIFF_TAG at it, rename the fixture
cd android/core && swift test --filter everySoundPageMatchesTheFM1
```
