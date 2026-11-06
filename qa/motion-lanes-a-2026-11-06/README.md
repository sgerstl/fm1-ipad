# Motion lanes, approach A: tap a lane, it opens into an editor (2026-11-06)

Scott picked A from the [design round](../motion-design-2026-11-06/README.md) ([canvas](https://claude.ai/artifact/AfJdG7fXUqDkg52g8FCaWC)). This is A as designed, on Skiff's Song tab.

## What it does

- **A closed lane is a button** the full width, 36 pt tall (was 28), with its name and a chevron. A tap opens it in place; one lane is open at a time.
- **The open lane** (`MotionLaneEditor`) has three parts:
  - **Header.** The lane's name (tap to close) and the selected step's value with what it is: "recorded, holds to step 10", "locked on this step only", or "the sound's own". Then Hold / Lock (what a touch writes), − / + (one unit; holding repeats), ⋯ (lock or hold this change, delete it, clear the lane) and Done.
  - **Plot, 140 pt.** Draw across steps to paint, drag a point up or down (44 pt grab), or tap a step to set it there. The axis is labelled in the parameter's own units, with the sound's value dashed.
  - **Hint line.** It names the three gestures and what the lane uses of the shared 64. While you draw it shows what the stroke costs instead (`03-paint.jpg`).
- **A stroke writes little** (`MotionPaint` in SloopKit):
  - A change is written only where the value differs from the step before.
  - A stroke puts back what played after it, so the steps you didn't touch still sound as before.
  - A single tap writes a change that holds on, as a recorded change does.
  - Lock mode puts a lock on each step touched. Locks already on the lane survive a Hold stroke.
  - The restore is sent first, so a stroke cut short by the 64 never changes the steps after it, and the refusal is said on the lanes.
- **While the song plays**, the lanes go read-only:
  - Closed lanes show one line above them with Stop (`01-playing-closed.jpg`).
  - An open editor dims, its header swaps the controls for "Stop to edit" and a primary Stop (`05-playing-open.jpg`).
- **The divider rises** by up to 120 pt while a lane is open on the shown track, and goes back on Done. The song's lanes never go below their least.

## A fix found on the way: "Stop to edit" never showed on Skiff

The lanes' playing rule read `session.song.songPlaying`. That flag comes from SLOOP's LIVE reply, so on Skiff it's always false, and the lanes were editable while the song played. Skiff's firmware doesn't refuse the write either: `editor.c` ED_MOTION never answers rc 3, and skiff-sim took a write mid-play.

`MotionLanes.songPlays` now decides it:
- **SLOOP:** LIVE, as before.
- **Skiff:** the transport playing with SONG ON or ONCE. Then the next entry loads its own motion (bank.c), so an edit wouldn't last.
- **Loop entry** keeps one entry going, so its motion stays editable while it plays.

## Files touched

- `ios/FM1/MotionLanes.swift`: the closed lane, `MotionLaneDrawing` and `MotionLaneEditor`. `MotionChip` is unchanged apart from the playing rule.
- `ios/FM1/FM1App.swift` (`EditorUI`): `openLane` and `motionWritesLocks`, plus `-motion-lane <id>` to open a lane for screenshots.
- **`ios/FM1/SongTab.swift` (song-editor's file), 3 lines in `SkiffSongPage.body`:** `let lift` and the `top` line lift the divider while a lane is open, and one `.animation(…, value: ui.openLane)` after the existing `poolOpen` animation. Nothing else there changed.
- **`ios/FM1/PianoRoll.swift` is not touched.** It already shortens the grid by `MotionLanes.height(…)`, down to its 120 pt floor, and the editor's height comes through that.
- `ios/SloopKit/Sources/SloopKit/MotionPaint.swift` (new): the stroke planner.
- `ios/SloopKit/Sources/SloopKit/Session.swift`: `paintMotion(track:id:plan:)` sends a plan and stops at the first refusal.
- `ios/SloopKit/Sources/SloopKit/MIDITransport.swift`: `FELUCCA_PORT` picks a port other than "felucca". Several sessions were running skiff-sims on this Mac, two under the same name, and this keeps a test off another session's sim.
- Tests: `MotionPaintTests.swift` (new), and `SkiffSimTests.aPaintedStrokeLandsOnTheFirmware`.

DEBUG only: `-motion-paint 1:20,2:28,…` holds a stroke mid-draw and `-motion-locks` picks Lock, for screenshots. Neither writes anything.

## Checked

- **`swift test --filter MotionPaint`:** 10 tests pass.
  - The planner: a flat stroke, a rising stroke, a stroke matching what plays, a fast finger skipping steps, Hold leaving locks alone, a Lock stroke, a tap holding on, the pattern's end.
  - The fake Skiff: a stroke landing as planned, and the 64 stopping a stroke cleanly.
- **skiff-sim** (Skiff 2.2's firmware, run as "Felucca motion sim"), with `SKIFF_SIM=1 FELUCCA_PORT="Felucca motion sim" swift test --filter SkiffSimTests/...`:
  - A painted stroke on T6 REVERB lands as planned: changes at 41 and 43, the sound put back at 45, no record on the steps that hold. The test then cleans up.
  - A write while a pattern plays is taken (rc 0).
  - `motionIsRecordedExactlyWhereLupeOffersIt` still passes.
- **The full suite:**
  - In parallel on this loaded Mac, timing tests failed (SessionTests, SkiffTests, WorkflowTests).
  - One of those, `everyParameterAndFollowingTheKnobs`, then indexed an empty array after its 5 s wait and crashed the run.
  - Run alone, the two I re-ran pass.
  - **Serially (`swift test --no-parallel`): 248 of 249 pass.** The one failure is `FirmwareInstallTests.cutRepeatedly` ("the FM-1 stopped asking for data"), which passes alone (44 s). It's a timing test under load, not this change.
- **The iPad Air 13-inch simulator** (its own "Motion iPad", demo Skiff), screenshots 01–05:
  - closed lanes while playing;
  - open while stopped;
  - mid-stroke;
  - Lock mode;
  - open while playing.

  These come from launch arguments.
- **Design pre-flight (design-standards):**
  - **Contrast:**
    - the header's secondary text (#C4C4CC) on the lifted editor (#34343B): 7.5:1;
    - axis labels on the well: 7.4:1;
    - the track line on the well: 6.1:1.
  - **Targets:**
    - keys: 44 pt;
    - the Hold / Lock pair: 40 pt inside a 44 pt group;
    - a closed lane: 36 pt × full width;
    - points: a 44 pt grab.
  - **State and motion:** state isn't colour alone (the readout says it in words, locks are a shape). Reduce Motion drops the open and close animation.
  - **Grayscale:** the hierarchy holds.

## Not checked

- **Touch on the simulator.** The simulator panel needs Scott's OK for the new "Motion iPad" device, and it wasn't given while I worked. Painting, dragging, tapping, − / + repeat and ⋯ were never driven by a finger. The gesture code is the same shape as the old lane's, and the write path is covered by the tests above. **First thing to try:** open REVERB, draw across a bar, and check that the cost readout and the result match.
- **On the FM-1.**
- **A VoiceOver pass:**
  - The lane is one adjustable element with Next step, Previous step, Lock or Hold, Delete and Close actions.
  - A closed lane says "REVERB motion, 3 changes and a lock" and "Opens the lane editor".
- **iPhone** (`PhoneSequence` has no lanes) and **drum tracks** (no lanes, as before).
- **The piano roll at its 120 pt floor:** with a lane open, about 2.5 rows show. Scott asked for "the grid squeezed above", but whether that's enough rows needs his eye on the iPad.

## Follow-ups

- **The C-style inspector rows** (value bar, − / +, Hold / Lock on "Sound at this step"). They belong in `StepInspector.swift`, which the song-editor session owns, so they're left for after its merge.
- **Painting across the bar line:** the plot shows one bar (the grid's pan), so a stroke stays in the bar in view.
- **Undo of a stroke** (Skiff's SAVE-held undo covers MOTION clear only).
