---
component: Pattern editor
lifecycle: built   # the phone's piano edge on Edit is requested (decision 31), see the amendment
status:
  requirements: draft      # written 2026-11-14 from code, vault notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/SongTab.swift         # SkiffSongPage (divider, SongPosition, EditorPanelShape, the tab), PatternPane (header, Follow, picker, waiting line)
  - ios/FM1/PianoRoll.swift       # PianoRoll, PianoRollContent, StepNumbers, AuditionLabel, EditorPlayhead, VelocityLane
  - ios/FM1/DrumGrid.swift        # DrumGrid, DrumGridContent
  - ios/FM1/StepSelection.swift   # StepEdits, SelectionBar
  - ios/FM1/MotionLanes.swift     # MotionLanes, MotionLaneEditor, MotionChip, Diamond
  - ios/FM1/PhoneAppView.swift    # PhoneSequence (the iPhone's Edit tab), PhonePianoRoll, PhoneDrumGrid
  - ios/FM1/Labs.swift            # holdToPaint, songSlide, flickSpeed, DividerFeel
  # Android (branch claude/android-p1-core-link-faf639, not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/EditorPage.kt   # Android's Edit tab (decision 28), replaced under decision 31
boards: [19, 20, 32, 33, 34, 50, 73, 75, "design/boards/compose.py", "design/boards/steps.py", "design/boards/stepstates.py", "design/boards/phone-edit-panel.html", "design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-25    # Note cell
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-44    # Drum hit
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-52    # Velocity bar
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-64    # Step number
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-113   # Editor header key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=13-118   # Piano edge key
---

# Pattern editor

> **Under revision (2026-11-14), the phones only:** decision 31 (`phone-skiff-decisions-2026-11-12.md`) makes the iPhone's step grid the Edit tab on both phones, **with a small piano down its left edge to show white and black keys** (requested, not built: Figma 13:118 is a sketch), and the Pads sound pop-ups reused there. Android's keyboard strip and its dials swap (decisions 28 and 30) go. Decision 32 docks the sound panel on the right, about a third wide, beside the grid. Board 75 (`design/boards/phone-edit-panel.html`) draws it at the iPhone's size with two ways to share the width, A and B, for Scott to pick. What changes on each phone: vault `phone-consolidation-build-plan-2026-11-14.md`, row "Edit". Section 1 below is the iPad and the iPhone as built until this closes.

## 1. Requirements

### Purpose and scope

The selected track's pattern, under the divider on the Song page (Pads or Timeline above it): a piano roll for a synth track, a drum grid for a kit, the step panel beside it, and a header saying whose pattern and which entry. It follows what the track plays unless pinned. Used whenever steps are written: stopped while building, or while playing on what's playing now. On the phone it's the Edit tab.

It is not the step panel's contents, not the pads, and not the Timeline. Where it sits: `design/structure-map.md`, "Tabs" and "The three positions (the divider)"; the phone's Edit: "Edit (board 50)".

### Anatomy

Names as in the code. Divider positions: **No grid** = `.none`, **Half** = `.half`, **Max** = `.max` (`SongPosition`).

- **panel** (`EditorPanelShape`): the selected track's tint under the editor, with its **tab** rising from the top left.
- **tab**: the divider's handle, three **carets** (`TabCarets`) pointing the ways it can go.
- **header strip**: the panel's top edge to the grid; drags the panel like the tab.
- **header** (`PatternPane.header`): track chip and name (at Max on Pads, the **tracks key**), the **pattern key**, the **waiting line**, the **Motion chip**, the **shared line** with **Make unique**, the **selection bar**, the **Follow toggle**.
- **step panel**: the left column; its contents belong to `step-inspector.md`.
- **grid**: the **piano roll** (`PianoRoll`) or the **drum grid** (`DrumGrid`), one bar in view, in a well.
- **step numbers** (`StepNumbers`): one per step over the grid; picks steps.
- **row labels** (`AuditionLabel`): note names or drum lane names; play the sound while touched.
- **note cell** / **hit**: a written note or drum hit, in the track colour; a note has a **length grip** at its right end.
- **playhead** (`EditorPlayhead`): the step playing, while the song plays.
- **velocity lane** (`VelocityLane`): a bar per note step under the piano roll. Display only.
- **motion lanes** (`MotionLanes`): a closed lane per recorded parameter under the velocity lane; one opens into the **lane editor** (`MotionLaneEditor`).
- **lasso**: the box drawn by a hold then drag on empty grid.
- **carried notes**: the lifted copy while a hold then drag moves notes.
- **selection bar** (`SelectionBar`): what's picked and what can be done to it, then the undo line.

Words to retire: "Sequence" for the editor (the iPad's old tab; the phone's tab is Edit), "Open / Close / Less" for the tab (it's carets now), "Following the song" (the pill that became Follow).

### Requirements

**Functional**
- **F1** The editor shows the selected track's pattern: a piano roll folded to the track's scale for a synth track, a drum grid for a kit.
- **F2** One bar is in view; the grid pans along the pattern and settles on a bar. The playhead never pages the grid (Scott, 2026-11-01).
- **F3** The divider has three places, never a free resting split. A drag snaps to the nearest on the spring; one setting serves Pads and Timeline, which share the editor (Scott, 2026-11-07). Kept across launches.
- **F4** At Max on Pads the track strip is gone, so the header's track chip becomes the tracks key (Scott, 2026-11-07, board 34).
- **F5** Rows shown stay while the track is on screen, so removing the highest or lowest note never pulls its row from under the finger.
- **F6** The drum grid shows whole lanes only; the rest scroll (Scott, 2026-11-08: a half lane looked cut off).
- **F7** Both editors are the same height, so switching between a synth and a kit track moves nothing below.
- **F8** Motion lanes show on Skiff for parameters the firmware records (motion_param only); + Lane offers only those (2026-11-05: the FM-1 refused every other).

**States**
- **S1** No grid: the panel shut to its lip; the carets all point up.
- **S2** Half (the default): one caret up, two down.
- **S3** Max: the editor largest; all carets down.
- **S4** Following: Follow is latched with its LED lit; the editor shows what the track plays now and changes with it.
- **S5** Pinned: Follow is raised and says "pinned to C".
- **S6** Pinned to an entry the track isn't on, while playing: the editor stays on what plays, editable; the header's waiting line says "C opens when it comes in" with "Stop and edit C". Nothing covers the steps (Scott, 2026-11-09). It switches by itself when the entry starts.
- **S7** No live pattern (pinned and not loaded, stopped edge case): the grid dims and takes no touches.
- **S8** Shared pattern: the header says "also on entries D, E" and shows Make unique.
- **S9** Motion chip low: amber with a warning mark when fewer than 8 of the shared 64 records are free.
- **S10** Selected step with a note: the note cell is ringed and lifted. With no note: a hollow column.
- **S11** Picked notes or steps: picked steps lit with a top edge, their numbers marked; the selection bar shows a count and its keys.
- **S12** Dim cells: soft or ghost level, or past the track's length; past the length is also shaded over.
- **S13** Drum hit levels: hard hits carry a bright cap, ratchets split the hit, so level never rests on brightness alone.
- **S14** Carrying: the originals faint in place, the lifted copy where they'd land. Lasso: a dashed box.
- **S15** Playing: the playhead shows; stopped, it's hidden.
- **S16** Offline: the pattern key and Make unique are off.
- **S17** While playing: Make unique is off; motion edits wait for stop when the song moves through entries (SONG ON, ONCE), and the lanes say so; Loop entry keeps one entry, so its motion stays editable.

**Behaviour**
- **B1** Tap the tab: No grid → Half, Half → No grid, Max → Half. Drag the tab, or the header strip, to move the divider. The lift that ends a drag isn't a tap.
- **B2** Let go: a flick past `flickSpeed` goes one place on in its direction from where the drag began, however short; slower, the nearest place (Scott, 2026-11-09). Spring: Labs › `DividerFeel`.
- **B3** Shut, a swipe up from the page's foot (the scene row and a little above) opens the editor, so the tab needn't be found (Scott, 2026-11-07).
- **B4** Edit pattern from a pad, the FREE TAKE picker or the sampler, with the editor shut, opens it to Half.
- **B5** Pads ↔ Timeline: the top half slides; the editor stays put under it (`songSlide`).
- **B6** Tap an empty cell: a note (or hit) goes in, picked. Tap a note that isn't picked: it's picked, not deleted. Tap the picked note again: it goes (Scott's tap rules).
- **B7** One finger pans (Scott, 2026-11-07). Two fingers pan too; a second finger mid-gesture turns it into the pan with no stray notes (device check `2026-11-09-lupe-batch-2026-11-06.md` 11).
- **B8** Piano roll: hold (`holdToPaint`), then drag from a note to carry the picked notes by whole steps and rows; from empty grid, a lasso picks what it touches. A hold that doesn't move only picks.
- **B9** Drum grid: hold, then slide along a lane to paint: from an empty step it lights each step passed, from a lit one it clears them. The lane is the one the hold began in.
- **B10** A drag from a note's grip sets its length; any other drag pans. A tap on the grip still toggles.
- **B11** Tap a step number: selects that step without touching its notes. Drag along the numbers: picks a range; while some are picked, a tap adds or removes a step.
- **B12** Touch a row label: plays that note or drum while held. A drum lane's label also picks the lane the step panel edits.
- **B13** Selection bar: Duplicate before (replaces the steps to the left), Duplicate after (adds to the right, the pattern growing up to 64), Copy, Paste, Move ←/→ a step, Transpose ↓/↑ (piano roll only), Delete, Cancel. Paste replaces what it covers; a hold on Paste offers Paste and keep (Scott, 2026-11-06).
- **B14** Every change is one step of Undo; the bar shows what changed ("Deleted C3") and Undo until dismissed.
- **B15** Follow tapped while following pins the entry showing; tapped while pinned, follows again.
- **B16** Stopped while pinned to another entry: the track goes to that entry and its pattern opens.
- **B17** The pattern key opens the picker: New empty pattern, the pool's used patterns, the count of free ones, Show the pattern pool.
- **B18** Make unique gives the entry its own copy of the pattern.
- **B19** The Motion chip opens a menu: lanes shown or hidden, + Lane, clear the track's motion, which tracks use the shared 64.
- **B20** Tap a closed motion lane: it opens (closing any other).
- **B21** The FM-1's keys play the sound and never write steps from Lupe; step entry from the keys is the FM-1's own step record, and a played phrase comes back through FREE TAKE (decision 5, Scott, 2026-11-13).
- **B22** iPhone Edit: the Step N key slides the step panel in over the grid's right side and closes it (✕ on the key while open). The FM-1's SEQ lands on Edit with the panel open. Velocity is a toggle.
- **B23** iPhone Edit follows the selected pad: a pad tapped on Pads, or another track's number, changes what Edit shows.
- **B24** Android grid, drum and melodic alike (Scott, 2026-11-17, after a page swipe on a kit placed hits): a **tap** toggles or writes a cell on touch-up, only if the finger never moved past touch slop. Movement past slop is a **page swipe** wherever it starts (empty cell, hit or note) and the cell isn't touched, unless the finger pressed on a note or hit and held still for 150 ms first (the pad drag's press-before-slide): then the note lifts and **drags**. A still hold for the hold time is lock (decision 9a; on a kit, pick). Either swipe or drag cancels the pending tap. One rule in code: `Roll.move`.
- **B25** Android melodic grid (Scott, 2026-11-17): a note's right end (two grip marks) is a resize handle, reaching 18 dp into the note and 10 dp past its end when the next cell on that row is empty. Moving past slop there resizes at once, with no dwell. The end snaps per step on the spatial spring with a tick, a "3 steps" readout above it, and the grid pages at its edge. On release it writes LENGTH, the step panel's knob 3, on that step, within 1…the step's `maxLength`. **Hold lifts:** a note or hit held still for 150 ms lifts at once (1.08, its shadow, a light haptic). A move drags it, keeping its length and the grab point. Lifting without moving settles it back unchanged; a drum hit is also picked for the panel. **No lock from the grid:** no `StepHold` from grid touches. **Bodies:** a touch anywhere on a note's drawn body (start to end, its row) belongs to that note. A tap there is a tap on the note: the first picks it and its start step, and a tap on the picked note removes the whole note. Nothing new is made inside a body, and only the edge resize changes length. An empty cell has no hold: a lift is a tap, a move a swipe. The non-drag way is the LENGTH tile (A5).

**Content**
- **C1** Header: track name, "pattern 07", never "entry B" on the key (Scott, 2026-11-07).
- **C2** Waiting line: "C opens when it comes in", key "Stop and edit C". Plain words saying what each button does (Scott, 2026-11-06).
- **C3** Shared line: "also on entry D" / "also on entries D, E".
- **C4** Follow: "Follow", plus "pinned to C" when off.
- **C5** Motion chip: "Motion 12/64".
- **C6** Selection count: "3 notes" or "steps 5–8".
- **C7** Off-scale rows keep a readable grey and say so with " ∗", not a fainter grey.
- **C8** iPhone ruler: "5 Piano · B · pattern 12 · C minor · 16 steps".

**Accessibility**
- **A1** The tab: "Pattern editor", value closed / half / largest, adjustable. Swipe up makes the editor larger (fixed 2026-11-10; device check `2026-11-10-accessibility.md` 5).
- **A2** Each step is a button read in step order, the selected one with the selected trait, "picked" as its value.
- **A3** Each step's actions: Pick step / Unpick step, and Add / Remove each note on its rows (drums: each lane), so the selection bar is reachable without the drag (2026-11-10, WCAG 2.1.1; check `2026-11-10-accessibility.md` 12).
- **A4** Row labels: "Play C3", a button.
- **A5** Every drag has a non-drag way: carry by the bar's Move and Transpose; lasso by Pick step; paint by tapping steps; length by the step panel's LENGTH (WCAG 2.5.7). `[review]`
- **A6** Follow: "Follow the song", value on / "off, pinned to entry C", toggle trait.
- **A7** Pattern key: "Pattern 07", hint names the picker. Make unique and Stop and edit carry hints.
- **A8** Selection bar keys are named ("Duplicate after", "Move a step earlier", "Undo: Deleted C3"); Paste and keep is a VoiceOver action.
- **A9** Motion chip: "Motion, 12 of 64 records used by all tracks, N free". The lane editor is adjustable with Next / Previous step, Lock, Delete and Close actions; while playing its hint says "Stop the song to edit".
- **A10** The velocity lane and the playhead are hidden from VoiceOver; velocity is read and set in the step panel.
- **A11** Not by colour alone: picked has an edge and the count, selected a ring and the trait, hard hits a cap, ratchets dividers, off-scale a mark.
- **A12** Targets: rows meet the 44 pt aim on the iPad; selection bar keys are 44 to touch. On the iPhone a step narrows to fit a bar, above the 24 pt floor. `[review]`
- **A13** Reduce Motion: the divider eases instead of springing; Pads ↔ Timeline cross-fades; the playhead steps instead of sliding; the iPhone's step panel fades. Check `2026-11-10-accessibility.md` 19.
- **A14** `[open]` Dynamic Type and Increase Contrast in the editor: not read (as the grid's P1 and P11).

**Integration**
- **I1** Writes go through TRACK_STEP (Session.writePattern), one change at a time, kept for Undo.
- **I2** Skiff edits only the pattern a track is on; that's why a pinned entry waits (S6) and why stopping sends LIST op 3 (B16).
- **I3** The picker uses LIST op 1 and op 7; Make unique is LIST copy.
- **I4** Following rereads the track's steps once when its entry or pattern changes (one trigger for both; 2026-11-11, two had read the track twice).
- **I5** Motion records share the FM-1's 64 across all tracks.
- **I6** Skiff takes motion writes while playing (editor.c ED_MOTION, checked on skiff-sim 2026-11-06), but an entry starting loads its own motion (bank.c), so Lupe holds motion edits until stop under SONG ON or ONCE.
- **I7** The FM-1's SEQ › NOTES and FEEL go to the step panel; PATTERN, AUTOMATION and SONG to the Song tab (structure map, "The FM-1's buttons").
- **I8** The editor's place also holds the sampler and the FREE TAKE picker (form A), which push the editor aside and back.

### Ruled out

- Paging the grid with the playhead: removed, since what's on the grid is read by where it sits (Scott, 2026-11-01).
- A free divider drag that rests anywhere: three places (Scott, 2026-11-07, boards 32–34).
- A slide that paints notes along a row in the piano roll: one finger pans instead (Scott, 2026-11-07).
- The selection bar as words over the grid's foot: it covered the velocity and motion lanes; icon keys in the header instead (Scott, 2026-11-06).
- "Following the song" as a pill beside a separate Follow button: one toggle (Scott, 2026-11-06).
- A panel over the steps saying the pinned entry will open: it interrupted too often; the header line instead (Scott, 2026-11-09).
- Words on the tab (Open, Close, Less): three carets, since words don't say the possibilities (Scott, 2026-11-09).
- The panel's tint 16 pt in from the page edges: it read too narrow; full width (Scott, 2026-11-09; check `2026-11-09-song-grid-panel-tint.md`).
- "entry B" on the pattern key (Scott, 2026-11-07).
- Writing steps from the FM-1's keys on the phone: every key pressed while stopped overwrote a step, and 14 keys replaced pattern 56 on the device test (decision 5, Scott, 2026-11-13).
- The phone's Chord key: it only served key entry (decision 5).
- Android's keyboard strip and its dials swap on Edit (decision 31, replacing 28 and 30).
- Motion lanes of parameters Skiff doesn't record (2026-11-05).

### Out of scope

- The step panel (notes row, NOTES / FEEL, sound at this step, Lock): see `step-inspector.md`.
- The pads above it: see `pattern-pad.md`. The Timeline above it: see `timeline.md`.
- The track head and the track menu: see `track-head.md`. The scene row the tab lines up with: see `scene-row.md`.
- The fan and placed menus' looks (the picker, the tracks key, Paste's hold menu).
- The patterns drawer, the sampler, the FREE TAKE picker, the sound panel.

## 2. Design

Boards: 19–20 (the Song tab, `compose.py`), 32–34 (the three places), `steps.py` and `stepstates.py` (steps and their states), 50 (iPhone Edit), 73 (Android landscape Edit, now replaced), 75 (both phones' Edit with the piano edge and the docked panel, `phone-edit-panel.html`), and the consolidation board (`phone-consolidation.html`, row Edit).

Motion follows `DESIGN.md`. Particular to the editor:
- Opening from shut, the editor comes up from the panel's foot on the panel's own spring, rising with the tint, never uncovered by it (Scott, 2026-11-09). The sampler's sideways swap runs only between the sampler and the editor.
- The tab's carets take the track colour on its tint (Scott, 2026-11-09).
- Phone Edit with the panel docked: **8-step pages** beside a 280-wide panel, with a 16-cell minimap under the grid that shows the other page's notes and pages on a tap. Pages follow the playhead when Follow is on, by hand otherwise (Scott, 2026-11-17; options drawn in the vault's `figma-ui-kit.md`, "Edit squeeze").
- `[open]` The phone's piano edge: display only ("to show white and black keys", decision 31), or does a touch play the note as the iPad's row labels do?

### Decision log

- 2026-11-01: no paging with the playhead (Scott).
- 2026-11-06: selection bar as icon keys in the header; Follow as one toggle; Paste replaces, hold for Paste and keep (Scott).
- 2026-11-07: three divider places shared by Pads and Timeline; one finger pans; tap rules (add picked, second tap deletes) (Scott).
- 2026-11-09: pinned entry said in the header, not a panel over the steps; flick goes one place on; carets on the tab (Scott).
- 2026-11-13: decision 5, the FM-1's keys never write steps from the phone (Scott).
- 2026-11-14: decision 31, the iPhone's step grid with a piano edge on both phones (Scott).
- 2026-11-17: phone Edit with the sound panel docked shows 8 steps a page with a minimap, over a bottom panel (only 4 of 7 rows) or a slim panel (about 38 pt a step) (Scott, hybrid UI study).
- 2026-11-17: the 8-step pages follow the playhead only when Follow is on (a Follow toggle joins the phone's pattern bar); by hand otherwise. Amends 2026-11-01 for 8-step pages (Scott).
- 2026-11-17 (round 5, `build-gaps-2026-11-17/1-drum-edit-docked.png`): a kit pages by 8 beside the docked panel too, with the minimap and Follow; lane names are keys down the left, the picked lane white and squarer; hits are rounded squares in the track colour, an accent a white cap, a ratchet split into its repeats with 3 dp gaps. Lanes 7–8 on a short phone (scroll or shorter rows) stays `[open]`: built as before, all lanes sharing the height.
- 2026-11-17: **a kit's lanes on shorter rows, never a scroll** (Scott; mock `build-gaps-2026-11-17/1b-drum-edit-8-short-lanes.png`). Closes round 5's `[open]`. All eight lanes share the height six used (pitch about 32 on the Pixel); hits 41 × 23 centred in the row, accent cap and ratchet segments as before; lane keys drawn 40 × 28 with their names on one line, each key's touch area the whole row pitch with no gap between rows (under the 44 aim, over the 24 floor).
- 2026-11-17: **the smooth playhead and the hit bounce** (Scott: "the playhead running smoothly across and making all of the steps in the sequence bounce slightly as it passes them"; then only hits bounce). On Edit (melodic and kit) the playhead sweeps continuously, its place from the FM-1's clock (`PlayheadMotion`: the playing step's start and next ticks, interpolated by `ClockState`), never frame time. Cells holding a hit bounce 1 → 1.12 → 1 as their step sounds, timed by the same clock; empty steps don't move; a ratchet bounces as one. Reduce Motion: the playhead jumps and nothing bounces. That was decided by the main session on Scott's behalf, answering spec 7's open item, and Scott can override it. Values in Labs › Hit bounce.
- 2026-11-17: **the Edit redesign** (Scott: "Build it"; vault `assets/edit-redesign-2026-11-17/` 1–3). The pattern bar grows to 44 with 40-tall keys: Chord and Lane as outlined toggles, "16 steps ⌄", Follow (8-step pages only), "Step N ⌄" for the panel; the step menu moves into the step panel's header (⋯). **Note drag:** a press on a note that moves past touch slop before the hold timer lifts it (1.08, a shadow, the spatial spring); it follows by whole steps and rows over a faint drop cell, a dashed ghost stays where it was, a readout says where it lands ("G#3 · step 6"); at the grid's edge the 8-step grid pages; let go and it changes pitch in place, then moves (MOVE keeps its length, velocity and locks; a refused move leaves only the pitch changed). A still hold keeps meaning lock (decision 9a). A kit's hit drags along its lane, onto an empty cell only. The iPad's lasso stays out.
- 2026-11-17: **a swipe never edits** (Scott, bug from the Pixel: "I can't swipe between the pages without adding a step or a drum step"). The kit's cells toggled on touch-up even after the finger had swiped, and a swipe that started on a hit or note carried it. Now B24: tap only within slop, swipe past slop before 150 ms (or from an empty cell at any time), drag only after a still 150 ms press on a note or hit. Supersedes round 9's "moves past touch slop before the hold timer lifts it". Device checks 97–102.
- 2026-11-17: **resize by the right edge, and long-press then move** (Scott: "I need the ability to drag the right side of the notes… to elongate them. I also need to be able to long press and move the note"). B25. Why moving felt broken: a drag needed the finger to start moving between 150 ms (the dwell) and the long-press time (~400 ms on the Pixel). Any longer and lock took the hold, and a moving finger then did nothing. Device checks 122–127.
- 2026-11-17: **9a reversed for the grid: hold lifts a note to move it; lock lives on the step panel's Lock key and the FM-1's own step hold** (Scott, 2026-11-17: "I don't think the long press to lock on a note is really that useful in the grid").
- 2026-11-17: **hit-testing by the note's body** (Scott: "if you tap outside of the first step, it shortens it and makes another note when it should select that note"). The grid used the cell under the finger, so a later step of a long note read as empty: a tap wrote a new note there, and the FM-1 cut the long note short to make room. Now `Roll.noteAt` finds the note whose body covers the touch. Device checks 128–130.
- 2026-11-17: **Chord is the phone's own mode** (Scott: "the chord key doesn't work"). Cause: Chord was the core's `chord` flag. The demo core flipped it, but the real core always sends `chord: false` and has no `chordToggle`, so with the FM-1 linked the key never turned on and every tap replaced the note. Now it's `EditUi.chord`, kept for the session, and it never touches the FM-1's own CHRD. The tap rule and the core's add-note write (`toggleStepNote`, up to 4) were already right. Device check 131.
- 2026-11-17: **the FM-1's keys light Edit** (Scott: "if I press the piano keys on the FM1, I should get some response from the piano roll"). The core keeps the FM-1's sounding notes by track (new `keys` area, from the notes it already received and only counted). While a key is down on the track Edit shows, its piano-edge key fills with the track colour, its name in the on-colour, and presses in to 0.96. It fades back over 150 ms ease-out, and chords light every key. The grid row glows at 12 %. A held pitch out of view puts a track-coloured marker at the edge's top or bottom; a tap glides the roll there on the spring, and it never scrolls by itself. On a kit the hit lane's key lights the same way. Reduce Motion: no press. TalkBack announces nothing. **Known:** while playing, Skiff also sends its sequencer's notes on each track's channel, so the keys light with playback too; the core can't tell them apart from the keys. Device checks 132–134.
- 2026-11-17 (Scott: "when the user goes from pads to edit using the navbar, it should use the same animation as when edit is selected from the long press menu"): **the Edit tab tapped on Pads grows Edit out of the selected track's current pad** (round 11's C), fading through when that pad is scrolled out of view; **Edit → Pads shrinks back into it** (the main session's addition for symmetry; Scott can veto). Timeline or Mix ↔ Edit fade through. **The pattern bar's toggles lose their dots:** Chord, Lane and Follow are outlined pills off, white with corners squaring to 12 on (shape and fill together, as Store).

## 3. Build notes

- `.android` hybrid build (branch `hybrid-ui-android`, 2026-11-17): with the sound panel or the step panel docked, a **melodic** grid shows 8 steps a page beside it (`StepGrid` `pageSteps = Roll.PAGE_DOCKED`), the ruler and grid giving up the panel's width plus 8; under the grid the 16-cell minimap (`MiniMap`: the page's cells on `control`, the other page's on `panel`, a sliding `lifted` window, note dots, "1–8" / "9–16"). A tap on a cell turns the page (TalkBack: "Show steps 9–16"). Pages flip on the spring (Labs › Hybrid · Edit page flip). The **Follow** key (on by default, as `phone-01`) appears only while the grid pages by 8; off, the page stays where the hand put it and the minimap marks the playhead's cell. The 16-step grid (panel shut) still follows as built (batch item 9). Paging rules are pure in `RollModel.kt` (`pagesFollow`, `minimapStart`, `pageLabel`) and tested. **Not done:** a kit's lanes still scroll under the panel (decision 35, B); the panel stays 360 wide, not the spec's 280, because the sound panel's four dials need it (the spec's 2 × 2 tiles aren't built); the ruler keeps its own keys (Chord, Lane, steps, Step N, the step menu), so the spec's pattern bar (badge, two lines, Step ⌄, Velocity) isn't built and the track name truncates beside the panel.

- `PatternPane` is shared by Pads and Timeline; the grids live in UIHostingControllers (`TwoFingerScrollView`), so grid metrics are passed in, not read from the environment.
- The editor's least height is set so the step inspector's short layout fits whole without scrolling (2026-11-06).
- The selection bar is inline in the Song tab's header and floats over the grid's foot elsewhere (`inline`).
- The iPhone reuses `PianoRollContent`, `DrumGridContent`, `AuditionLabel`, `EditorPlayhead` and `VelocityLane`; it has no step numbers, no header, no motion lanes and no pattern menu (left out on purpose: device check `2026-11-10-phone-pads-edit-mix.md`, "Not covered here").
- Code issues found while writing this, not yet fixed:
  - The iPhone's Edit has no selection bar, so notes picked there can only be deleted by a second tap; Duplicate, Copy, Move and Transpose aren't reachable on the phone.
  - The iPhone's Velocity toggle has no accessibility hint.
- `[open]` Decision 9a (2026-11-12, portrait Android) made a long press on a step mean only lock mode. The iPhone grid that decision 31 keeps uses hold for carry and lasso (B8). Which does the combined phone's grid do?
- `[open]` Motion lanes on the combined phone: left out on the iPhone; decision 7 (one lane under the grid) was decided for Android portrait. Not decided for landscape.

### Decision log

- 2026-11-11: following rereads a track once per entry-and-pattern change, not twice.
- 2026-11-17: **the steps menu** is two tiles (One fewer · One more, each saying the length it makes) over the lengths as a 4 × 2 grid of pills, 4 8 12 16 / 24 32 48 64, the current one selected. Same values as before (only lengths up to the core's `patternStepsMax`). Device checks 119–121.
- 2026-11-18: **the FREE TAKE offer stops popping up** (Scott: "the constant popping up of 'you just played 15 notes'… always blocks shit I want to see"). By default the offer is a chip beside Record in the header: a track-colour dot and the note count. It scales in once on the spring and doesn't pulse; a newer offer changes the count; it goes when the offer expires or is taken. A tap is Keep that (the picker). TalkBack: "Played phrase on track 2, 15 notes. Double-tap to keep it". Settings › Offer played phrases: Chip (default), Pop-up (the strip over Edit, as before), Off. The landed strip (Kept / Undo) still shows after Keep that.
- 2026-11-18: **a drum hit's settings from the grid** (Scott: "Maybe if I long pressed, I should be able to get the step settings for that particular drum hit"). A hit held and let go without moving picks it and opens the step panel on it ("KICK · STEP 5"). If the panel is already open, it retargets. Held then moved, the hit drags along its lane; a tap still toggles. The Step key works on kits, opening on the last picked hit or the pattern's first. The first time a kit opens, once per install, the app strip says "Hold a hit to edit it"; it goes on its timer or at the next touch on the grid. With the panel open, the FM-1 goes to SEQ › NOTES with its cursor on that step (its drum grid); the LANE knob keeps its own lane, since the phone can't set it. Melodic is unchanged. Device checks 135–139.
- 2026-11-18: **undo, with long press to redo** (Scott). A 40 × 40 ↶ key at the pattern bar's left, with the elastic press. A tap undoes the last edit; a long press redoes. Dimmed with nothing to undo; a long press with nothing to redo gives only a "no" tick. Each undo or redo posts a confirmation ("Undid: note added · step 5"). TalkBack reads "Undo" plus what it undoes, with a Redo action. One edit is one undo step: a grid tap, a note or hit drag, an edge resize, a tile's slide (or a TalkBack step) in the step panel, Clear step, Paste. The screen marks the gesture (`undoMark`), and the core (StepUndo.swift) keeps the pattern's steps before and, 0.7 s after the last change, after. Undo writes the steps it touched back; redo writes them forward. If the FM-1 changed one of them since, the undo is skipped with a message. History per pattern, for the session, 50 deep; a new edit clears the redo. A pad's clear (its Undo) is undone by the same key while it stands, so there is one undo. **Not undone:** the FM-1's own knob turns (never recorded), and "Clear all" locks (locks live in the automation store, not the steps). Clearing a pad has no redo. Device checks 144–148.

## 4. Usage

- To write steps, use this editor; to change what it shows, select the track (its row number or head) or a pad on the selected row. A pad on another row launches only.
- To edit a pattern other than the one playing, pin it (Follow off) or stop; don't build a second editor.
- New editing actions on picked notes or steps go in `StepEdits` and the selection bar, so Undo and VoiceOver's pick actions cover them.
