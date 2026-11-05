# Shape by FM-1 button, first batch (2026-11-05)

Brief: Scott's plan, relayed by the parent session. Shape is organised by FM-1 button in the order Skiff's PAGES
table lists them (`firmware/src/params.c`), each button's pages exactly as Skiff defines them, pages that drive one
thing merged into rows over one graph. Visuals first; each graph ported from Skiff's drawing code.

## What changed

- **Sections, one scroll:** ENV, LFO, FX, SEL (Skiff's SCL), EDIT, ARP, then GLO (left where it was until the
  navigation decision), then SEQ's PATTERN pages. A section header names the button; the left pads scroll to their
  section, and so does following the FM-1.
- **Skiff's pages, not Jib's splits:** `SkiffPages.specs` now follows PAGES: ENV, ENV 2 · LFO, LFO 2, MOD · FX,
  DRIVE, INSERT, INSERT 2, SLICER, DUCK · SCALE, CHORD, FOLLOW · EDIT 1, EDIT 2, VOICE, VOICE 2 · DELAY, REVERB,
  CHORUS, GLOBAL · ARP, ARP 2 · PATTERN. ENV DEST, LFO DEST and MOD 1–4 are gone as pages; their parameters make up MOD.
- **Merged cards:** LFO + LFO 2 (one running wave), INSERT + INSERT 2 (one transfer or sweep). Each row is labelled
  with its page; tapping the label focuses the row and, linked, shows that page on the FM-1, so its knobs are the
  row's four. Touching a column also focuses its row.
- **FX** (`graph_fx`): the four sends as sliders under their columns.
- **INSERT** (`graph_insert`, `pg_ins_curve`): the drives and CRUSH as a transfer curve blended by MIX with a sine
  through it (TONE / LPF, LEVEL, CRUSH's hold); PHASR, FLANG, CHOR as their sweep over a cycle and two cycles at the right.
- **SLICER** (`graph_slicer`): the 16-step pattern (Skiff's SL_PAT), GATE's closed steps as high as DEPTH leaves them,
  STUT's repeats as dashes, dim when OFF. The step playing isn't shown (Jib doesn't know the slicer's own step).
- **DUCK** (`graph_duck`): the level over a bar of the source's hits (a kit's KICK lane only), down by DEPTH, back in
  a line over RELEASE; the source's hits under it in its colour; BY OFF or itself: the empty box.
- **MOD** (`graph_mod`, `MOD_FIXED`, `mod_ui_route`): ROUTE (1–11) picks the route; 1–7 the fixed LFO → PITCH CUT
  SHAPE AMP and ENV → PITCH CUT SHAPE with SOURCE and DEST dim and AMOUNT turning; 8–11 the matrix's slots with
  SOURCE, DEST, AMOUNT. The graph: the fixed routes' grid and the slots' list, the route picked white as on Skiff.
  Tapping a value in the graph picks its route. The route is Jib's own: the protocol doesn't report the FM-1's.

## Compared with skiff-sim

`skiff-sim-mod-fx-insert-slicer-duck.png` (Skiff's screens, a fresh unit, Analog · Acid) against
`jib-lfo-mod-fx.jpg` and `jib-duck-sel.jpg` (the demo, the same sound):

- MOD: the same grid (ENV → CUT lit, ENV → AMP "–"), the same slots (8–11 OFF → OFF 0 %), route 1 picked white.
  One difference: Skiff writes ENV → CUT as +76, Jib as +75. Jib's percent for a bipolar value (×100/64) isn't
  Skiff's; this predates the redesign and shows in the columns too. To fix with the value formats.
- FX: the sliders at DIST 16, DELAY 35, REVERB 12, CHORUS empty, in the same places under the columns.
- INSERT OFF: the straight line and a clean sine. SLICER OFF: the dim pattern 1. DUCK BY OFF: the empty box.
- `jib-duck-by-t3.jpg`: BY T3 (every other 1/16): eight hits in T3's colour, each dip recovering over 199 ms.

## Not done in this batch

- Labelling SEQ's and SAVE's places with their FM-1 page names (NOTES, FEEL, PATTERN, AUTOMATION, SONG, PRESETS,
  USER, PATTERNS, PROJECT).
- The next batch (FM6's EDIT pages, LANES, LANE MIX, SOUND, SLICES, SAMPLES), GLO's place, as asked.

## Pre-flight (design-standards)

1. Framing: Scott's plan; no change.
2. Grayscale: section headers, the focused row's white label and the white MOD route carry the structure without colour.
3. Spacing: 24 pt between sections, 10 pt header to cards, 16 pt between cards, 4 pt between columns.
4. Type: section headers 13 pt semibold; row labels 11 pt semibold; graph text 11–13 pt; two weights.
5. Tokens: Theme throughout. Gap as before: the hot column's two greys.
6. States: rows focused / not; MOD route picked / not, a route doing nothing dim, fixed SOURCE and DEST dim. DUCK
   with no source: the empty box. No loading or error states (the values are there once connected).
7. Contrast (dark only): section headers 0xA1A1AA on the page ≈ 7.6:1, lit 0xEDEDF0; row label ink 0x101012 on
   0xEDEDF0 and 0xA1A1AA on 0x26262B ≈ 5.9:1; MOD's dim text is 0x71717A (≈ 3.9:1), as Skiff's DIM: it marks routes
   that do nothing, and their values are also given by VoiceOver.
8. Keyboard: not tested.
9. Targets: row labels 52 × 62 pt. VoiceOver: row labels are buttons with "Puts the FM-1's knobs on this row";
   the MOD graph is adjustable (route up and down); fixed SOURCE and DEST say "fixed". Not tested with VoiceOver.
   Motion: section scroll is 0.2 s; nothing else new moves.
10. Taste anchor: data-dense tool.
11. Tells: Swift isn't scanned by `check-tells.sh`. Eyeball: the layout is Skiff's page table.
12. Behaviour defaults: no new actions or destructive paths.
13. Rendered: iPad sim, one size. Not checked: iPhone (PhoneShape is separate), split view.
14. Gold: Skiff's own screens, compared above.
