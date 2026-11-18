---
component: Step inspector
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/StepInspector.swift        # SkiffStepInspector: a melodic Skiff track's selected step
  - ios/FM1/SelectedStepPanel.swift    # SelectedStepPanel: a drum kit's selected step (its synth branch is SLOOP's)
  - ios/FM1/SongTab.swift              # PatternPane places it beside the grid
  - ios/FM1/PhoneAppView.swift         # PhoneSequence: the Step N key and the slide-in panel on the iPhone
  - ios/FM1/DeviceFollow.swift         # SeqCursor: the selected step follows the FM-1's NOTES and FEEL cursor
  - ios/FM1/Knobs.swift                # KnobControl and ColumnFace draw its columns
  - ios/SloopKit/Sources/SloopKit/Session.swift       # lockStep, clearLocks, set(track:param:to:) writing locks
  - ios/SloopKit/Sources/SloopKit/SkiffDriver.swift   # MOTION op 6, clear locks
  # Android's step panel, on branch claude/android-p1-core-link-faf639 only (not on this branch):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/EditorPage.kt   # StepControls, HitPanel, LockBanner, StepCell
boards: ["15 (design/boards/steps.py)", "design/boards/stepstates.py", "50", "75 (design/boards/phone-edit-panel.html)", "design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-69   # Note chip
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-82   # Lock key
---

# Step inspector

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

> **Under revision (2026-11-14):** both phones' Edit consolidates on the iPhone's step grid (decision 31, vault `phone-skiff-decisions-2026-11-12.md`; `phone-consolidation-build-plan-2026-11-14.md`, row "Edit"). The iPhone's step panel is this component. Android's own step panel (NOTES · FEEL · SOUND tabs over four dials, `EditorPage.kt` on the Android branch) carries decisions 9a and 9b; this one doesn't. Board 75 leaves the step panel out ("Not shown: the step panel"). `[open]` Which step panel both phones carry, and whether 9a (hold a step to lock), 9b (each lock cleared on its own, Clear all confirmed in place) and the ◆ on locked steps come to it. Section 1 below is the iPad and iPhone as built.

## 1. Requirements

### Purpose and scope

The selected step's own values, beside the pattern editor's grid: its notes, the four values the FM-1's knobs turn on SEQ › NOTES, FEEL's four, what the track's sound is at that step, and the Lock key that turns knob moves into locks on it. One panel for a melodic Skiff track (`SkiffStepInspector`), another for a drum kit (`SelectedStepPanel`). Used while building a pattern, stopped or playing.

It is not the grid, not the track's knobs, and not where notes are added (that's the grid). Where it sits: `structure-map.md`, "Tabs" (Song) and "The phone with a Skiff FM-1", Edit.

### Anatomy

Names as in the code. Layouts: **full** and **short** (`ViewThatFits`, `collapsed`); **iPad** (in `PatternPane`) and **phone** (`PhoneSequence`'s slide-in `panel`).

- **header**: "T1 Acid" over "Step 5", the step keys (‹ ›) and, when the step has locks, **Clear locks**.
- **notes row** (`notes`): one **note chip** per note in the track colour, or a well saying why there are none.
- **NOTES columns**: PITCH, MOVE, LENGTH, VELOCITY, two by two, each badged with its FM-1 knob number (1–4).
- **FEEL columns**: CHANCE, RATCHET, COND, NUDGE in a row, unnumbered.
- **sound rows** (`soundAtStep`, `rows`): one per recorded parameter: a **mark**, the name, the value at this step.
- **Sound at this step** key: the short layout's way to the sound rows, as a menu.
- **Lock key** (`lockKey`): latches knob moves to this step.
- **Step key** (phone only, in Edit's ruler): "Step N", opens and closes the panel.

Drum kit (`SelectedStepPanel`, `drumDetails`):
- **Editing** readout: which hit the keys edit ("Kick · step 5").
- **level keys**: Normal / Accent on Skiff (ghost, soft, normal, hard elsewhere).
- **ratchet keys**: ×1 to ×4 for the whole step on Skiff.

Words to retire: "Motion at this step" (the 2026-11-06 motion boards) for the **sound rows**.

### Requirements

**Functional**
- **F1** It shows the selected track's selected step (`ui.selectedStep`), and follows any change to either.
- **F2** A melodic Skiff track gets `SkiffStepInspector`; a kit gets `SelectedStepPanel`, on the iPad and the phone alike.
- **F3** PITCH moves every note of the step together, keeping the chord's shape.
- **F4** MOVE swaps the step's contents with the step it's turned to, and the selection goes with it.
- **F5** LENGTH is the step plus the TIE steps after it; turning it sets the ties (`setLength`), as the roll's length grip does.
- **F6** RATCHET sets the same ratchet on every note of the step.
- **F7** COND picks from Skiff's list: --, FILL, !FILL, 1:2 … 4:4.
- **F8** The sound rows list every parameter with recorded motion on the track, with its value at this step and where the value comes from: a lock on this step, the latest recorded change before it, or the sound. Worked out from the records, without playing.
- **F9** Lock on: every knob turn on the selected track writes a lock on this step (MOTION op 5) and leaves the sound alone, from Lupe's controls or the FM-1's (`Session.set(track:param:to:)`).
- **F10** Lock follows the selection: with Lock on, picking another step moves the lock target there.
- **F11** Clear locks takes off this step's locks and keeps its recorded changes (MOTION op 6).
- **F12** On the iPad it never scrolls: the full layout when it fits, else the short one (Scott, 2026-11-06).
- **F13** On the phone it scrolls inside the slide-in panel (device check `2026-11-10-phone-pads-edit-mix.md` 7).
- **F14** Kit: the level and ratchet keys edit the hit on the selected lane and step; a lane name or a grid tap picks another.

**States**
- **S1** A step with notes: note chips, all eight columns live.
- **S2** An empty step: the well says "No notes: tap the grid to add one"; every column dim and inert.
- **S3** A tied step: the well says "Held from the step before"; columns dim.
- **S4** A FEEL column whose byte the step doesn't carry: dim (`extra` shorter than its index).
- **S5** Lock off: the key raised, open lock, "Lock knob turns to step N".
- **S6** Lock on: the key filled, closed lock, "Locking knob turns to step N".
- **S7** Song playing: Lock and Clear locks disabled.
- **S8** The step has locks: Clear locks shows in the header. None: it's absent.
- **S9** No motion on the track: one line, "Nothing recorded or locked on Tn."
- **S10** Sound row marks: a diamond for a lock, a short bar for recorded, a dashed line for the sound's own.
- **S11** Short layout: the notes ride on the header line, the sound rows go behind "Sound at this step ⌄", the Lock key shortens to "Lock" beside it.
- **S12** Kit with no hit on the lane and step: the readout says "No kick on step 5", dim; the keys show nothing picked and are disabled.
- **S13** Phone, panel open: the Step key latched, with ✕ on it for `SkiffStepInspector`; a kit's panel has its own ✕ key instead.
- **S14** Leaving the view turns Lock off (`onDisappear`).

**Behaviour**
- **B1** Slide on a column to change it, as every knob column; no − / + steppers (decision 10, Scott, 2026-11-13). Direction follows Settings › Slide to turn.
- **B2** Double tap a column: back to its default where it has one (VELOCITY 100, CHANCE 100%, LENGTH 1, RATCHET ×1, NUDGE 0, COND --). PITCH and MOVE have none.
- **B3** While a column slides, the Magnifier floats a bigger copy above the finger (`ValueLoupe.swift`; Settings).
- **B4** ‹ › step through the pattern, wrapping at either end.
- **B5** The FM-1 on SEQ › NOTES or FEEL: its step cursor moves the selected step here, and a range picked on the FM-1 is picked in the grid (Scott, 2026-11-08). Linked and screen-cursor on only.
- **B6** SEQ (NOTES, FEEL) on the FM-1: the iPad flashes the panel's ring; the phone opens the panel on Edit (device check `2026-11-10-phone-pads-edit-mix.md` 8).
- **B7** Phone: the Step key slides the panel in from the right over the grid's right side, at the iPad column's width, and closes it.
- **B8** Short layout: "Sound at this step ⌄" opens a placed menu listing the rows, a diamond or a dash before locked and recorded values.
- **B9** Clear locks acts at once, with no confirm. `[open]` DESIGN.md asks for a confirm in place on anything that loses work unless Undo covers it; decision 9b (phone) confirms Clear all. Does the iPad's Clear locks get a confirm, or Undo?
- **B10** `[open]` Decision 9a on the phone: holding a step locks knob turns to it while held, and long-press on a step means only that. Built on Android; not on the iPad or iPhone. Does it come to either?
- **B11** `[open]` Decision 9b on the phone: each ◆ row gets its own clear. The iPad clears a step's locks only all at once. Does per-row clear come to the iPad?
- **B12** `[open]` The motion pick of 2026-11-06 (`qa/motion-design-2026-11-06`: "A, with C's inspector rows as the precise path") asked for editable sound rows (value, Hold / Lock, Delete). Left for later (`qa/motion-lanes-a-2026-11-06` README); still read-only. Build, or drop?

**Content**
- **C1** Header: "T{n} {track name}" then "Step {n}". Short layout adds the note names after " · ".
- **C2** Empty and tied wells, word for word: "No notes: tap the grid to add one", "Held from the step before".
- **C3** Values: PITCH as a note name ("C3"), MOVE "Step N", LENGTH "N step(s)", VELOCITY a number, CHANCE "N%", RATCHET "×1"–"×4", NUDGE signed ("+4").
- **C4** Lock key words: "Lock knob turns to step N" / "Locking knob turns to step N"; "Lock" in the short layout.
- **C5** Kit help lines: "Tap a lane name to edit another hit." / "Tap the grid to add one, or a lane name to pick another."
- **C6** Kit ratchet label on Skiff: "Step ratchet (all its hits)", since Skiff keeps one ratchet a step.

**Accessibility**
- **A1** The panel is a container labelled "Step N"; its title line is a header.
- **A2** Note chips read the spoken note name.
- **A3** Each live column is adjustable (VoiceOver swipe up and down), with "Open" (the big control) and "Reset to default" actions; label the column name, value its spoken value.
- **A4** A dim column reads "{Name}, nothing to change on this step".
- **A5** Each sound row reads "name, value, locked on this step / recorded / the sound's own". The mark's shape doubles the colour; the source is said, not only drawn.
- **A6** The Lock key carries the toggle trait, its label the key's words, its hint what it does to knob turns.
- **A7** Clear locks hints that recorded changes stay.
- **A8** Step keys are labelled "Previous step" / "Next step"; full-size targets.
- **A9** Phone: the Step key reads "Step N panel", hints open or close, and carries selected while open.
- **A10** Lock on is shown by fill, icon and words together, never colour alone.
- **A11** Reduce Motion: the phone panel fades instead of sliding.
- **A12** Accessibility audit P3 (`qa/accessibility-2026-11-10/README.md`): a finger changes a column only by sliding; a tap only focuses it. VoiceOver is covered (A3). `[open]` The proposed fix (a hold or second tap opens the big control) isn't chosen.
- **A13** `[open]` No Dynamic Type (audit P1); the Lock key's words are flagged as clipping at larger sizes in the audit's TSV.

**Integration**
- **I1** Step writes go through `session.write(track:index:)` (TRACK_STEP); a kit hit through `write(drumIndex:)`.
- **I2** Skiff's step bytes after velocity carry hits, chance, ratchet, FLAM, COND, NUDGE (stored +32) and the tie mask (editor.c `ed_step_reply`). FEEL reads them from `extra`.
- **I3** Locks are Skiff MOTION records with the lock flag; the 64 records are shared across tracks (`motionMax`). Skiff refuses ids motion can't hold.
- **I4** Locks and clearing are Skiff only (`SkiffDriver`); SLOOP's step panel is `SelectedStepPanel`'s synth branch, not covered here.
- **I5** On the FM-1, knobs 1–4 on SEQ › NOTES turn PITCH, MOVE (START), LENGTH, VELOCITY of the step under its cursor; the badges say which.

### Ruled out

- A scrolling step inspector on the iPad: a short layout instead (Scott, 2026-11-06, code comment and `qa/mixer-batch-2026-11-06`).
- − / + steppers on any step value (decision 10, Scott, 2026-11-13).
- The track's knobs inside the step panel: they read as the step's (2026-11-02, `SelectedStepPanel.swift` comment); SWING, LEVEL, STEPS and PAN left the inspector's foot (`qa/track-controls-2026-11-05`).
- Writing notes from the FM-1's keys into the selected step on the phone: every key pressed while stopped overwrote a step (decision 5, Scott, 2026-11-13).
- Long-press on a step opening step menus, on the phone: long-press means lock only; step menus move to a visible key (decision 9a, 2026-11-12).

### Out of scope

- The grid, step numbers, velocity lane, motion lanes, selection bar and the editor header: see `pattern-editor.md`.
- The phone's Edit tab layout, its ruler and the piano edge: see `pattern-editor.md`.
- The column face and its slide (`ColumnFace`, `KnobControl`, `Knobs.swift`), the big control (`KnobPanel`) and the Magnifier (`ValueLoupe.swift`).
- `TrackPanel` (whole-track knobs) and the track controls box.
- SLOOP's synth step panel (`SelectedStepPanel` synth branch).

## 2. Design

Boards: 15 (`design/boards/steps.py`, the step inspector), `design/boards/stepstates.py` (step states), 50 (phone Edit), 75 (`design/boards/phone-edit-panel.html`, phone Edit without the step panel), `design/boards/phone-consolidation.html`.

Particular to this component: the phone panel slides in with the iPad's side-panel timing (hard-coded in `PhoneSequence.setPanel`, not in Labs).

### Decision log

- 2026-11-05: the step inspector settled on the canvas first (board 15), its columns numbered as the FM-1's knobs (code comment, 7630985).
- 2026-11-06: never a scroll on the iPad; the short layout fits at the divider's lowest, which rose so it always does (Scott; 618f21c).
- 2026-11-08: the selected step follows the FM-1's NOTES and FEEL cursor, and a range picked there is picked here (Scott, `DeviceFollow.swift`).
- 2026-11-10: on the phone a Step N key in Edit's ruler slides the panel in, ✕ on the key (structure map, board 50).
- 2026-11-12: phone locks: hold a step plus the Lock key (9a); each lock cleared on its own, Clear all confirmed in place, ◆ on locked steps (9b) (Scott).
- 2026-11-13: slide on the control, no steppers; the Magnifier comes too (decision 10, Scott).
- 2026-11-17: **the Edit step panel, redesigned and connected to the FM-1's knobs** (Scott: "Build it"). Header "STEP N" over what it holds, a connected ‹ › pager (44 × 40), ⋯ (Copy, Paste, Clear step, confirms as before); Notes · Feel · Sound as a 40-tall connected group. **Notes:** four hybrid parameter tiles numbered to the FM-1's knobs, from Skiff 2.5.1's source (`ui_input.c` step_edit; no live probe, the FM-1 wasn't on the Mac): 1 PITCH, 2 START (the mock's MOVE: it moves the note a step a turn), 3 LENGTH, 4 VELOCITY; the cursor is the FM-1's PRESETS encoder, so the ‹ › pager stands for it. Linked both ways: the FM-1's SEQ cursor on NOTES or FEEL is the picked step (the panel opens on that tab, the grid pages to it); a step picked with the panel on Notes or Feel sends the FM-1 there with its cursor on it (screenGoto's new cursor, the core's showOnDevice). Knob turns are the FM-1's own: no StepAdjust is sent for them. Tiles still slide by touch, sideways only. Lock and Clear all below, 40 tall. **Feel:** CHANCE slider, RATCHET 1–4 pills, COND as a picker row (the core's twelve), NUDGE centred slider at −32…31 (the core's and the firmware's range; ±12 before). **Sound:** the lock rows, clear keys 40 tall. Kits aren't linked to the knobs yet (on a kit the FM-1's NOTES knobs are LANE HIT ACC VELOCITY).
- 2026-11-17 (amended, main session for Scott; he can override): **Feel is knob tiles too, one control language for both tabs.** Source for every knob: Skiff firmware v2.5.1's source in the repo (`ui_input.c` step_edit, feel_turn, grid_edit), not a live probe; device check 72 confirms it on the real FM-1. Feel: 1 CHANCE (0–100, then on into the trig conditions as on the FM-1, shown as the condition, "2nd of 4"; a small "Conditions ⌄" row is a touch shortcut to the same value), 2 RATCHET (1–5 on the FM-1; the core writes 1–4 for now), 3 NUDGE (−32…31), 4 TYPE (shown; the core has no field for it, so the FM-1's knob turns it). The mock's sliders and ratchet pills are gone (Scott may want the pills back as a shortcut). Drum steps: NOTES tiles 1 LANE, 2 HIT, 3 ACC (shown; no accent intent yet), 4 VELOCITY, and the Feel tiles under them. The ‹ › pager stands for the PRESETS encoder.
- 2026-11-18: **the kit's step panel** (Scott): titled "LANE · STEP n" ("KICK · STEP 5"), with ‹ › through that lane's hits, round from end to end. Its NOTES (LANE, HIT, ACC, VELOCITY) and FEEL (CHANCE, RATCHET, NUDGE, TYPE) tiles stay stacked in one scroll rather than in tabs (a kit has no Sound tab). It opens from a held hit or the Step key.
- 2026-11-18: the step panel's swipe-away follows the finger, as the sound panel's does (logged in `sound-panel.md`).
- 2026-11-18: **the step panel's motion fixed** (Scott: "a little janky… the grid stays and lags behind… sometimes just doesn't want to let go"). Causes, from the code. (1) Jank: the panel's animated width was read in composition, so the whole Edit tab (pattern bar, grid, tiles) recomposed and re-laid out every frame of the open and close. (2) Lag: the grid switched to its full layout the moment the panel started to close, then glided to its place on its own; after a swipe, only once the panel had left. (3) Won't let go: most of the panel is tiles, which take a sideways drag as an edit (as they should); the grab handle was 48 dp tall; and 15b's release needs 35 % of the panel (about 126 dp), where round 7's took 32 dp. Fixes: the panel moves only as an offset. The pattern bar and grid lay out once per state: at rest only one layout is there. While the panel slides or is dragged, the 8-step layout beside it and the full one are both laid out and cross-fade by the panel's own position, frame by frame (they share the pitch scroll). The grab handle's touch area is the panel's whole leading edge, 24 dp wide, on the step panel and the sound panel. Tiles still edit on a sideways drag; the header, gaps and handle move the panel. Device checks 152–154.

## 3. Build notes

- A lock is a mode on `Session` (`lockStep`), not a flag on a control, so every knob path (sound panel, FM-1 echo) honours it. Keep it there.
- The phone reuses the iPad's views inside a `ScrollView` at `Overview.boxWidth`, so the keys lay out as on the iPad.
- Android's step panel (branch `claude/android-p1-core-link-faf639`, `EditorPage.kt`) already has 9a and 9b: `LockMode` Held / Latched, a lock banner over the ruler, per-row `LockClear`, `LocksClearAll` behind a `ConfirmBox`, ◆ in `StepCell`. Its drum `HitPanel` carries CHANCE and NUDGE per hit; the iPad's kit panel has neither.
- Code issues found while writing this, not fixed:
  - NUDGE: the iPad reads −32…31 (64ths of a step, from editor.c); Android's dial runs −12…12. One is wrong for Skiff 2.5.1. Not checked against firmware here.
  - `stepperStep` still lives in every `KnobSpec`; since decision 10 it only sets VoiceOver's adjust step.

### Decision log

## 4. Usage

- Show a step's values with this panel; don't add step controls to the grid's header or the track controls.
- A new knob-driven control that should be lockable needs nothing here: going through `Session.set(track:param:to:)` makes Lock apply.
- To pick which step it shows from elsewhere, set `ui.selectedStep[track]`; to bring it forward, flash `.stepPanel`.
