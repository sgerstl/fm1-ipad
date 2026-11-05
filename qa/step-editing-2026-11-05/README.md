# Step editing in the Song tab (2026-11-05)

Scott's brief (via the parent session), built into the Song tab's bottom half (iPad, Skiff). The edit rules are a
pure type, `PatternEdit` (SloopKit), tested on its own, against the fake and on skiff-sim. Writes go through
TRACK_STEP as every edit does (`Session.writePattern`: the steps that changed, one request per step at a time, and
LENGTH).

## What changed

1. **Tap rules** (roll): an empty cell gets a note, picked (`03-tap-adds-and-picks.png`). The picked note tapped
   again goes, so a mistaken tap is undone by a second (`04-second-tap-deletes.png`). A note that isn't picked is
   picked, not deleted. Slide-to-paint stays: a drag that starts at once paints along its row (or, from a note's
   grip, sets its length), so it doesn't conflict.
2. **Picking several:**
   - **Steps:** a drag along the step numbers picks a range, the same gesture as Arrange's bar ruler. While some
     are picked, a tap on a number adds or takes it off. Picked steps are lit with a white edge, their notes ringed
     (`01-steps-picked-bar.jpg`).
   - **Notes:** a hold on empty grid (0.35 s, a light haptic), then a box, picks the notes it touches. A hold that
     doesn't move picks nothing; a tap still adds.
   - **The bar** floats at the grid's foot: Duplicate after (the primary key), Copy, Paste, Move ‹ ›, Transpose − +,
     Delete, Cancel (Escape).
3. **Duplicate after grows the pattern:** the selection again right after itself. Whole steps when steps were
   picked; the notes alone when notes were. Past LENGTH, LENGTH grows to fit, up to 64. The line says it ("steps
   9–16 added, length 8 → 16") with Undo (⌘Z), which puts back both the steps and LENGTH (`02-duplicated-undo.jpg`).
   At 64 it says there's no room.
4. **Moving:** hold a note, then drag it to another step or pitch (by rows, so it stays in the folded scale). It
   lifts with a shadow (level 3) where it would land, and the original fades. The picked notes all move together.
   - A note alone on its step takes its step's fields (velocity, chance, ratchet, FLAM, COND, NUDGE) and its length.
   - One of a chord leaves the chord (`05-hold-drag-moved.png`: D3 out of step 3's chord to step 4).
   - A note that can't land (a TIE, four notes there, past 64) stays where it was.
   - The note's right-edge grip keeps its own drag (length).
5. **Skiff's rules:** at most four notes a step (a fifth isn't added); a note's TIE steps go with it; a kit step's
   hits clear with Delete.

## The drum grid

- **Tap rules:** an empty cell gets a hit, picked; the picked hit tapped again goes; another hit is picked. The
  picked hit is the selected step and lane, as before.
- **Step range picking** along the numbers, and the bar on whole steps (no Transpose).
- **Not done for drums:** the hold-and-box lasso and moving hits by dragging. Use the step range and Move ‹ ›.

## The iPhone

Unchanged (it has no Song tab). It would need:
- the same tap rules in PhoneSequence;
- a step-range pick on its step strip;
- the bar as a bottom sheet (it won't fit as one row);
- hold-and-drag moves (the phone's cells are 42 pt).

## Tests

- `PatternEditTests`: add and remove (four at most, TIEs go with the last note); moves keeping length and every
  step field, a chord split, past 64 staying; Duplicate after growing LENGTH 8 → 16, refusing at 64, notes alone;
  the changed steps.
- `duplicateAfterReachesTheDevice` (fake): the steps and LENGTH written and read back.
- `duplicateAfterOnTheRealFirmware` (stock skiff-sim, `SKIFF_SIM=1`): a three-note chord and a held note
  duplicated, LENGTH 8 → 16, read back as Skiff keeps them. Passed.

## Fixed on the way

- The Song tab's divider minimum was 180 pt, which let six lanes spill over the top bar and the pattern header. It
  now follows the lanes (the tool row, the ruler, every lane at 28 pt), and the top half clips.
- A long press placed first in an exclusive gesture chain kept the roll's taps from ever firing. It sits alongside
  now, and a tap after a hold is ignored.

## Pre-flight (design-standards)

1. Framing: Scott's brief.
2. Grayscale: picked notes ring white, picked steps get a white top edge; the lifted carry has a shadow, not a colour.
3. Spacing: the bar floats 12 pt above the grid's foot, 6 pt between keys.
4. Type: 13 pt semibold keys; the count and the "added" line 13 pt.
5. Tokens: Theme throughout.
6. States: nothing picked (the selected step as before), notes picked, steps picked, a carry, a box, after a change
   (Undo), no room at 64.
7. Contrast: key text Theme.text on Theme.control, ≈ 13:1; the primary key's ink on white.
8. Keyboard: Escape cancels the pick, ⌘Z undoes the last change. Not tested with a hardware keyboard.
9. Targets: keys 36 pt high. VoiceOver: the steps' rotor actions as before (add or remove a note); the bar's keys
   are buttons with labels. Lasso and carry have no VoiceOver form; picking steps by the numbers isn't exposed
   either. A known gap. Motion: none new (Reduce Motion unaffected).
10. Taste anchor: data-dense tool.
11. Tells: not scanned (Swift).
12. Behaviour defaults: destructive Delete is undoable at once (the line); no confirmation, as the line's Undo covers it.
13. Rendered: iPad sim, the demo; not checked: the drum grid's taps on the sim, Paste across tracks, a real FM-1.
14. Gold: Arrange's section bar for the same pick-and-act pattern.
