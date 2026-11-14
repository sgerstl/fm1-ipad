# Device check: Edit's step grid and the docked sound panel (claude/android-p4-sound-pages-7e2a23), 2026-11-14

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel 10 Pro with the FM-1; the branch merges only after it passes. Decisions 31, 32 and 35; board 75 (`design/boards/phone-edit-panel.html`, B: overlay).

**None of this has been seen on a screen.** It compiles, 128 Kotlin unit tests pass and the APK builds, but the emulator would not run beside another session's, so every check below is a first look. Expect layout faults; note them with the check number.

**Setup:** the combined build with this branch · FM-1 on Skiff 2.5.1 · writes allowed for checks 3, 4 and 9 (`adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true`). Without the FM-1, the fake core (`--es core fake`, scenario `drums`) runs checks 1 to 8.
**Back up first?** Yes for checks 3 and 4: they write notes into a pattern (Lupe on the iPad › Projects, or SLOOP's editor › Song & sections › Save a backup).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Edit tab, a melodic track. Compare with board 75.1. | The ruler (track, entry, pattern, scale), then the step grid across the whole width: twelve pitch rows, sixteen steps, the first step of each beat a shade lighter, black keys' rows a shade darker. A piano down the left edge: white keys, black keys about 62 % of its width, C named. Notes are blocks in the track's colour as long as they hold, stronger the harder they play. No keyboard strip, no dials under the grid. | – | ☐ pass ☐ fail: |
| 2 | Drag one finger up and down on the grid. Touch a piano key. | The pitches scroll (a dot at the top or foot of a step says it has a note out of view). The key plays its note while held (not while REC is armed and playing). | – | ☐ pass ☐ fail: |
| 3 | Tap an empty cell. Tap the note you made. Tap it again. Turn Chord on (ruler) and tap two more cells in that step. | The cell's note is written to the step and plays, and the step is picked (its column lifted, its notes ringed white). A tap on a note of a step that isn't picked only picks it; on the picked step's note it takes the note off. With Chord on a tap adds a note, up to four; a fifth is refused with a different tick. The FM-1's step matches. Works while playing. | Yes | ☐ pass ☐ fail: |
| 4 | Hold a cell and turn a knob on the FM-1; let go. | Lock mode while the finger is down, as before (the step's column outlined in the track's colour, the lock banner in the ruler); the note shows ◆. | Yes | ☐ pass ☐ fail: |
| 5 | Tap Step N (ruler). Try NOTES, FEEL, SOUND, ‹ ›, Lock, then its ✕. Tap Step ⋯. | The step panel slides in from the right over the grid, about two fifths of the width: Step N ✕, ‹ ›, Lock on one row, NOTES · FEEL · SOUND on the next, then the four dials. The grid keeps its step width and scrolls so the picked step is clear of the panel; a thin bar along the grid's foot shows what is in view; one finger sideways scrolls the steps. ✕ (or Step N again) slides it out and the grid returns. Step ⋯ is still Copy, Paste, Clear. | – | ☐ pass ☐ fail: |
| 6 | A kit track. Tap cells; hold one; tap Step N. | Lanes by steps as before; the lane's name plays it. Hold picks a hit; Step N then opens the panel with the hit's values in two rows of three boxes. The steps scroll under the panel, the lane names stay. | – | ☐ pass ☐ fail: |
| 7 | Lane (ruler) on a melodic track. | The one-lane view shows under the grid (96 dp); the grid gets shorter. Lane again hides it. | – | ☐ pass ☐ fail: |
| 8 | On each tab, press a sound key on the FM-1 (ENV, FX…); press it again; turn a knob; wait a minute; press HOME. Open it again and tap its ✕; open it again and change tab. | The sound panel slides in from the right (the same width), tinted with the track's muted colour: "FX 2/7 DELAY", ✕, four dials, tiles if the page has them, the picture under them (Settings › Show graphics). The same key again steps its pages. **It stays**: no timeout. HOME, ✕, a swipe right on it, or another tab shuts it. On Edit the grid scrolls under it (board 75.3); on Pads and the Timeline it covers their right side and they stay live. | – | ☐ pass ☐ fail: |
| 9 | Settings › Sound keys on (P2 adds the switch; until then it is `soundKeys` in the app's preferences). Tap FX on the rail, tap it again, tap ENV. | A 48 dp rail down the right edge on every tab: FX SEL ENV LFO EDIT ARP. A key sends the FM-1 to that family and the panel opens beside the rail, the key lit; the same key again steps its pages; another key switches family. Read-only, nothing happens (the write is dropped). | – | ☐ pass ☐ fail: |
| 10 | TalkBack on Edit: swipe across the grid; open a step's actions. | Each step is one item: "Step 5, C4 E4, length 2, velocity 100". Actions: Take C4 off, Set (or Add) a note for each pitch in view, Lock knob turns to this step, Copy step. The piano edge says it plays notes. The panels are panes with Close. | – | ☐ pass ☐ fail: |

**Calls I made (provisional):**
1. The docked panels are **360 dp** wide, not a third (305): four of the app's 84 dp dials don't fit in less. About 9 of 16 steps show beside it, not 10.
2. **The HOME knobs strip left Edit** with the dials area (decision 31 retires the track controls box; the FM-1's HOME knobs are still on the FM-1). Say if it should live somewhere on the phone.
3. Tap rules: empty cell writes; a note's first tap picks its step, its second takes it off. Chord off replaces the step's note, Chord on adds.
4. The step panel is the Step key's (latched), docked like the sound panel; the sound panel stands in front of it when both are open.
5. The sound panel's ✕ shuts it on the phone only; the FM-1 stays on its page and its next knob turn or page change opens the panel again. Back is still HOME on the FM-1 (decision 19).
6. With the rail on, every tab is 52 dp narrower.
7. The "Sound panel stays · seconds" row in Settings now does nothing (the timeout is gone); P2 owns the sheet.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
