# Shape on the FM-1: dropped frames, scrolling, touches, focus (2026-11-05)

Scott, on the real FM-1 with the new Shape page: turning an encoder drops frames and the digits don't roll
smoothly; scrolling isn't smooth; a finger put down to scroll changes a value; the white focused column is too loud.

## Profiling: what I could and couldn't measure

**Instruments on the device: not done.** Scott's iPad was offline to this Mac (`xctrace list devices`: "Devices
Offline: Scott's iPad"), and installing on it is Scott's. On the iPad Air 13-inch (M3) simulator:

- **SwiftUI and Hitches:** these instruments aren't supported there ("Hitches is not supported on this platform").
- **Time Profiler:** sampled only the launch (217 samples, none after the first second).

So there are **no frame-time or hitch numbers yet**; those need Scott's iPad, plugged in (Instruments, SwiftUI +
Hitches templates, while turning an encoder with the LFO page on screen).

**What I measured instead:** how many times each Shape view's body runs per second. This is a debug counter,
`-count-bodies`, on a Release build on the M3 simulator, while `-demo-turn 9` pushes CHANGED for LFO RATE every
40 ms, like an encoder turned slowly. Body runs are the work that drops frames when a page redraws everything for one
value. Raw lines: `bodies-before.txt`, `bodies-after.txt`.

| per second, while turning | before | after |
|---|---|---|
| the Shape page's body | 14–17 | 0 |
| cards | 250–306 | 0 (a burst of 8–16 for ~4 s) |
| knob bodies | 975–1,182 | 18–34, the one column and the "last turned" card (a burst of ~100) |
| graphs | 140–170 | 0 (the LFO draws inside its own canvas) |
| the turning column | 28–37 | 8–18 |

The goal (120 Hz on the iPad Air M3, an encoder turning, the LFO running) still has to be confirmed on the device.

## What caused it

1. **Every parameter came from one observed array** (`session.params`). Each push from an encoder changed it, so
   every column and every graph on the page depended on every parameter and redrew together.
2. **The page watched the FM-1's touches.** `onChange(of: session.lastTouched)` sat on the Shape page itself, and
   the "knob just turned" mark was written on every push. One encoder rebuilt the whole scroll 15 times a second.
3. **The resync rewrote unchanged values.** Every few seconds it re-assigned each track's fields, and each write to
   `tracks` invalidated everything that reads it.
4. **Columns grabbed every touch.** Their drag began at zero distance and claimed the touch before the scroll view,
   so a vertical drag both moved the value and stopped the page scrolling.

## What changed

- **One observed cell per parameter** (`session.cell(id)`, `ParamCell`). Columns, graphs, the LFO, MOD and the
  motion lanes read their own parameters, so a push redraws what shows that parameter.
- **Cards are views of their own** (`SoundCard`) and Equatable, so a rebuilt scroll doesn't rebuild them.
- **The scroll is its own view** (`ShapeScroll`), and the FM-1's touches are watched by a view that draws nothing
  (`TouchFollower`). The mark is written only when it changes (`ShapeMarks`, which also holds the tapped page and
  MOD's route).
- **The resync writes only changed values**: the track list, the selected track, the parameters.
- **The live LFO graphs pause when scrolled off screen** (`onScrollVisibilityChange`).
- **Columns turn on a horizontal drag only**: UIKit's pan (`HorizontalPan`) begins only when the finger moves more
  across than up or down, so every vertical drag is the page's scroll. Right raises; the whole range is about
  240 pt. A tap still opens the big control, and a double-tap resets. The dials elsewhere (Whole track, the mixer)
  keep their own drag.
- **ENV:** only a drag that starts on a handle moves it (a 44 pt target each); the graph's background scrolls.
- **Focus:** a 3 pt white bar along the top of the column, shown while the knob turns (on the FM-1, held 600 ms as
  Skiff's hot_t), the column in its own colours.

## Rolling digits

Unchanged in rule: Skiff's own (9 frames of 15 ms, the ones digit first, a turn faster than 45 ms between changes
shows plain numbers, a change mid-roll restarts from the value it was heading to). At 40 ms a push, as here, about
half the changes roll; faster, they show plain, as on the FM-1. The column now redraws on its own instead of with the
whole page, so the rolls aren't starved of frames. Smoothness on slow turns needs a look on the device.

## Checked on the simulator

- A vertical swipe that starts on DELAY's column scrolls the page; DELAY stays 35 %.
- A horizontal drag on it takes it to 61 % (`horizontal-drag-delay-35-to-61.png`).
- An ENV handle drag sets DECAY and SUSTAIN; a swipe on the ENV graph's background scrolls.

## Not done or not checked

- Frame and hitch numbers on the device (above).
- A virtualised stack: not needed by these numbers; I'd decide after the device profile.
- The short burst of scroll rebuilds. `_printChanges` blames the track list and the FM-1's touches, but which nested
  closure reads them I haven't pinned down. With the cards Equatable it costs one or two card bodies.

## Pre-flight (design-standards)

The focus bar is 3 pt white (≈ 15:1 on the column's well) and isn't the only cue: the column's value and gauge move.
Turning targets are the whole column (about 110 × 62 pt); vertical drags never change a value, which also fixes the
"scroll changed a setting" error. Motion: unchanged rules, Reduce Motion as before.

## Folded into the same pass (Scott, via the parent session)

### "Last turned on the FM-1" removed

The card on Shape's left is gone; its space is left empty. It also caused the short burst of rebuilds in the numbers
above: it redrew on every push.

### Whole-track knobs

SWING, LEVEL, STEPS and PAN have white value rings on the dark-grey track, the one set, at the foot of Sequence's left
panel (`hold-drag-level-81-to-100.png`). This has been so since 7630985. If Scott still sees colours, his install is
older than that, or it's another screen: tell me which.

### Knobs: hold, then drag (14c1962's "drag straight on" reverted)

- **Every dial** (Whole track, the mixer's PAN and REV, the step inspector's velocity, the knob panel): press and
  hold 0.3 s (a light haptic when it takes), then drag up or down. Sideways is finer. Release to finish. While
  held, a bubble shows the value and the page doesn't scroll. Moving before the hold takes fails it, so the page
  scrolls and no knob steals a scroll (UIKit's long press, `HoldDrag`). The mixer's faders work the same way.
- **Tap:** the big control at the finger (Arc or Slider, Developer › Knob tap), with **Cancel** and **Done**.
  - Done (the primary chiclet, Return, or a tap outside) keeps the value.
  - Cancel (or Escape) puts back the value it had when it opened.
  - Changes go to the FM-1 as they're made either way, so it previews live (`knob-panel-done-cancel.jpg`).
- Double-tap resets to the default; the ticks at the ends and the centre stay.
- **Shape's columns** keep the horizontal drag; their tap opens the same control with Done and Cancel.

### State-dependent descriptors

Skiff's DESC answers with `param_desc_of` (editor.c `ed_tdesc`), which skips `track_desc`'s rules, so Jib showed the
generic names. Ported into `SkiffDisplay` / `skiffTrackDesc`. Each rule reads only the values it depends on, each
from its own cell, so a knob relabels as soon as the value it depends on changes, and redraws for nothing else.

| Where (Skiff 2.2) | What depends on what | Status |
|---|---|---|
| `track_desc`: INSERT A B C | TYPE: the drives DRIVE / TONE (cutoff) / LEVEL (dB); CRUSH BITS (1–16) / RATE (689…44k Hz) / LPF; the swept ones RATE (LFO Hz) / DEPTH / FDBK; OFF the generic | fixed (Scott's report) |
| `track_desc`: ENV's ATTACK DECAY RELEASE | ENV SYNC on: 25 note values, 0 … 4BAR | fixed |
| `analog_desc` | WAVE SYNC: DTN is SYNC; WAVE SUB: MIX is SUB (%) | fixed |
| `phys_desc` | MODEL MEMB: HARM, BEND; SYMP: CHRD (OCT…ROOT), SYMP, BUZZ | fixed |
| `lofi_desc` | WAVE WRAM: WAV# (SQ50…STAIR); CHIP STEP: DCY (CONST, D0–D15, L1–L15) | fixed |
| `noise_desc` | MODE LFSR / META: LEN (L23… / 127…); CLK in st | fixed |
| `mod_dst_name` | the matrix's DEST E1–E8 by the engine's own labels | fixed |
| other engines | no hook (grep `.desc =` in `eng_*.c`: only the four above) | nothing to do |
| `page_desc`: MOD | the route picks a fixed route's AMOUNT or a slot's SOURCE DEST AMOUNT | done in 90ed59a (ModColumns) |
| `page_desc`: LANES, LANE MIX | the lane KNOB 1 picks (LEVEL TUNE DECAY / LEVEL PAN of that lane) | pages not in Jib yet (next batch); will need the cursor from the new screen link |
| `page_desc`: SAMPLES | the sample KNOB 1 picks (LEVEL REVERB DELAY) | page not in Jib yet (next batch) |

Tests: `descriptorsFollowTheirState` (TYPE OFF → HARD → CRUSH → FLANG relabels A B C; ENV SYNC turns ATTACK into
note values) and `enginesNameTheirModesKnobs`.
