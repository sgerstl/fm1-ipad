# Motion lanes and the step inspector (2026-11-05)

Design: canvas boards 15 and 16; their generators are kept in `design/boards/steps.py` and `stepstates.py`.
Behaviour: Skiff 2.2's `motion.c` (how a step sounds), `editor.c` (MOTION ops 3–7, the step's bytes).

## What changed (Skiff)

- **The step inspector** (the left panel, synth tracks): T#, Step N, ‹ ›; the step's notes as chips.
  - **"The FM-1's knobs on NOTES" ①–④:** PITCH, MOVE, LENGTH, VELOCITY, in the order of Skiff's NOTES page
    (`params.c`: PITCH START LENGTH VELOCITY). Laid out 2 × 2 because the panel is narrower than the board.
    - PITCH moves the chord.
    - MOVE swaps the step with the one it lands on, and the selection follows.
    - LENGTH is the step plus the TIE steps after it, set the way the roll's grip sets it.
  - **FEEL's four** (no knob numbers): CHANCE 0–100 %, RATCHET ×1–×4, COND (`TC_NAME`), NUDGE −32…31.
  - **"The sound at step N":** every parameter with a lane, its value at this step and where it comes from.
  - **"Clear this step's locks"** (MOTION op 6).
  - **Lock knob turns to step N** (see the note below).
- **Whole track's knobs:** white rings.
- **Motion lanes** under the velocity, one per recorded parameter (plus any added with + Lane):
  - a recorded change is a step-and-hold line in the track's colour;
  - a lock is a diamond on its step;
  - the sound's own value is a dashed baseline;
  - the selected step's column runs through every lane.
- **The header:** the shared 64 as a meter and "N of 64 records · shared by all tracks", the legend, + Lane. More
  than three lanes scroll. The grid gets shorter by the lanes' height.
- **Editing:**
  - drag a point for its value (a bubble shows it);
  - tap an empty step for a recorded change at the value that step sounds now;
  - hold a point for Jib's menu: Lock step N only / Make it hold from here, Delete this change, Clear the lane.
- **States:**
  - **Empty:** says the two ways in.
  - **Full** (64 of 64): "Show what uses them" lists the tracks by count.
  - **Song playing:** the lanes go read-only with Stop.
  - **Recording:** the REC bar at the foot (as before) and red rings on the recorded columns on Shape.
- The bars under the step numbers (d42a88f) are gone from the synth roll: the lanes say it. The drum grid keeps them,
  as it has no lanes yet. The track's MOTION tag stays.

## How a step sounds (motion.c, ported as `TrackMotion.value(of:at:base:)`)

Each pass starts from the sound's own values (`motion_restore` at step 0). At step s, a lock on s wins. Otherwise
the latest recorded change at a step up to s applies. Otherwise the sound's own value. A lock holds for its step
only (`motion_unlock` puts back the last recorded change). Jib's base is the track's value as it reads it; while
playing, Skiff writes motion values into the sound, so the base can be off during playback.

## Two calls I made (for Scott)

1. **"Turning a knob with a step selected locks it."** Jib always has a selected step, so every knob turn would
   become a lock. That includes the Whole track knobs and every Shape column. So locking is a toggle in the step
   panel, "Lock knob turns to step N". While it's on, any knob of the selected track sets a lock on that step
   (MOTION op 5) and leaves the sound alone, and the knob shows the lock's value. It follows the selected step and
   turns off when the panel goes. The FM-1's own hold-a-step lock is Skiff's and needs nothing from Jib.
2. **Read-only while the song plays.** The brief says Skiff refuses motion edits then (MOTION rc 3). It doesn't:
   `editor.c`'s MOTION answers rc 0, 1 (invalid) or 2 (all 64 used), never 3. The lanes still go read-only while a
   song plays, as Jib's own rule, because an entry that starts brings its pattern's own motion. The banner says that
   ("the next entry brings its own"), not that Skiff refuses.

## Tests

- `SkiffMotionTests.whatAStepSounds`: the motion.c rule (sound at step 0, holds, a lock on its step only).
- `motionEditsOnTheFake`: op 3, op 5, a lock made to hold, op 6, op 4, a lane cleared, and a knob turned while
  locking (a lock there, the sound untouched).
- `motionEditsOnTheRealFirmware` (stock skiff-sim, `SKIFF_SIM=1`): the same ops, and rc 1 for a parameter motion
  can't hold. Passed. The fake now answers ops 3–6 as `editor.c` does (op 3 and 4 without the kinds).

## Fixed on the way

- NUDGE on the wire is NUDGE + 32 (`ed_step_reply`), not a 6-bit two's complement: a plain step read −32.
- The step's last byte is the notes' tie mask, not a length: LENGTH counts the TIE steps instead.

## Pre-flight (design-standards)

1. Framing: Scott's boards. Two deviations, named above.
2. Grayscale: lines against dashed baselines, diamonds against dots, the white selected column: shape carries
   meaning, colour only adds the track.
3. Spacing: 14 pt between inspector groups, 4 pt between columns and lanes, 8 pt header to lanes.
4. Type: 22 pt step title, 11–15 pt labels and values; two weights.
5. Tokens: Theme throughout.
6. States: empty, full, song playing, recording, dim columns on a step with no notes; drag (bubble), hold (menu).
7. Contrast (dark): lane labels and legend 0xA1A1AA on panel ≈ 7:1; the baseline is decoration (the value is in
   the inspector and VoiceOver); disabled "Clear this step's locks" 0x71717A is an inactive control.
8. Keyboard: not tested.
9. Targets: ‹ › 44 pt, + Lane 36 pt high (above 24), lanes 52 pt tall with a 22 pt touch radius on points.
   VoiceOver: each lane is adjustable (the selected step's value), with its value and source spoken; the inspector
   rows combine. Not tested with VoiceOver. Motion: none new.
10. Taste anchor: data-dense tool.
11. Tells: not scanned (Swift). Eyeball: lanes read as an instrument's automation, not a chart widget.
12. Behaviour defaults: Clear the lane is in the menu's own group (hold, then choose), no toast.
13. Rendered: iPad sim, the demo (T1 with CHORUS and REVERB motion). Not checked: drum tracks, many lanes, iPhone.
14. Gold: the boards; difference: the inspector's 2 × 2 knobs (narrower panel).
