# Shape, redesigned as Skiff's pages (2026-11-05)

Design source: canvas boards 17 and 18 (lupe/shape.py). Behaviour source: Skiff 2.2's `ui_draw.c`, `ui_graph.c`,
`ui_pgraph.c`. The animation table came first: `animation.md`. The LFO's accuracy: `lfo.md`.

## What changed

- **Columns instead of knobs.** Each page shows four columns: label, the knob's number ①–④, the value large with its
  unit, and a 3 pt gauge in the track's colour (bipolar values from the middle). The column of the knob just turned
  goes white for 600 ms (Skiff's `hot_t`, 40 frames); a column being dragged here stays white. Tap opens the Arc or
  Slider control; drag up or down on a column changes it (sideways for fine control), and a double-tap puts the
  default back. An unused slot is an empty well, as on Skiff.
- **Rolling digits.** The changed digits roll as Skiff's do: 9 frames of 15 ms, Skiff's ease table, the ones digit
  first and each place a frame later. Shown at once for a fast turn (within 45 ms), a change of shape (sign, length,
  a name) and with Reduce Motion (Skiff's ANIM OFF).
- **Page graphs** under the columns, in the track's colour, ported from Skiff's drawing code in its 240 × 140 space:
  ENV and ENV 2 (the curve with three square handles you can drag: the peak sets ATTACK, the decay's end sets DECAY
  and SUSTAIN, the release's start sets RELEASE and SUSTAIN), LFO and LFO 2 (live, `lfo.md`), LFO DEST (each
  destination carries the running LFO, as tall as its depth), DRIVE (the transfer curve and a sine through it),
  DELAY (the dry hit and the echoes), REVERB (early reflections, the tail, DAMP's top), CHORUS (the drifting copy;
  FLANGER's comb and PHASER's notches), VOICE (the two notes and the glide).
- **Rows align to the top** in the page grid, so a short panel doesn't float beside a tall one.

## Compared with skiff-sim

`skiff-sim-env-lfo-drive.png` (Skiff's own screens, from the sim's `screen` command on a fresh unit) against
`jib-env.jpg`, `jib-lfo.jpg`, `jib-drive.jpg` (the demo, same factory sound, Analog · Acid):

- ENV: the same values (1.0 ms, 54 ms, 16 %, 8.8 ms), the same curve, the same three handles.
- LFO: 1.18 Hz, about 2.4 cycles across the 2 s window, the dot at the right edge once the window scrolls.
- DRIVE: SOFT at 16 %: the same curve over the straight line, the same sine through it.
- Differences on purpose: Jib's lines are 2.5 pt (Skiff's 2 px), the straight line on DRIVE is dashed, and the handles
  sit on a dark rim to stay visible on the fill.

## Not drawn yet

VOICE 2 (Jib doesn't know which voices sound), ARP and ARP 2 (the notes held), MOD (the route list), OPS and the
engine pages. They have their columns and no graph.

## Pre-flight (design-standards)

1. Right problem: the brief is the board; mirroring Skiff's own pages is the point. No change of framing.
2. Grayscale: the white hot column and the value size carry the hierarchy without colour; the gauges add colour only.
3. Spacing: 4 pt between columns, 10 pt between columns and graph, 16 pt panel padding (the 4/8 rhythm).
4. Type: 11 pt labels and units, 22 pt values (semibold), two weights; the 11 pt graph captions are Skiff's own words.
5. Tokens: Theme's well, control, text, textSecondary, stepEmpty, track colours. Two values from the board aren't
   tokens: the hot column's label grey (0x3A3A42) and gauge track (0xC9C9CF). Named here as a gap, not added.
6. States: column default, hot (FM-1 turn), dragging (white), empty slot. Graph handles: default, lit, grabbed. No
   loading or error state: the values are always there once connected.
7. Contrast (dark only; Jib has no light theme): labels 0xA1A1AA on 0x111114 ≈ 7.4:1; hot label 0x3A3A42 on 0xEDEDF0
   ≈ 9.6:1; the number badge 0xA1A1AA on 0x26262B ≈ 5.9:1; graph captions in 0xA1A1AA. The delay's beat numbers were
   moved from the tertiary grey (≈ 3.9:1) to the secondary one.
8. Keyboard: unchanged from the knobs (the columns keep KnobControl's actions). Not tested with a hardware keyboard.
9. Targets: a column is about 110 × 62 pt. VoiceOver: each column is one adjustable element (label, spoken value,
   Open, Reset to default); each graph is one element with a label and value; the ENV handles aren't separate
   VoiceOver elements (the columns set the same values). Not tested with VoiceOver.
   Motion: rolls off with Reduce Motion, and the hot column's fade too. The LFO keeps moving, as ANIM OFF leaves it
   on Skiff: it's the instrument's state. That's continuous motion for as long as the page is open, with no pause
   (WCAG 2.2.2): Scott to decide whether Reduce Motion should freeze it.
10. Taste anchor: data-dense tool. Every graph is the value drawn; no decoration.
11. Tells: `check-tells.sh` found no files it scans (Swift isn't one), so not a pass. Eyeball: the layout is the
    instrument's own, not a generic card grid.
12. Behaviour defaults: no new actions, toasts or destructive paths.
13. Rendered check: screenshots on the iPad sim (Look iPad), at its one size. `check-render.mjs` is for web pages and
    doesn't apply to a native view. Not checked: iPhone (PhoneShape still uses its own layout), split view widths.
14. Gold comparison: the gold here is Skiff's own screen (`skiff-sim-env-lfo-drive.png`); the one difference that
    matters is line weight, kept heavier for the larger, farther iPad screen.

Known limits:
- Dragging on the ENV graph doesn't scroll the page; scroll beside it.
- An ENV handle follows the finger exactly, so the whole of DECAY is about 95 pt of travel.
- The rolling digits aren't visible in a still screenshot; the rule is checked by reading against `roll_text`, not on screen.
