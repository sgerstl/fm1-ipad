# Skiff's SAVE pages in Jib (2026-11-06)

Scott approved the mapping "as proposed": PRESETS and USER on the Sounds tab, PATTERNS in the Song tab's drawer,
PROJECT in the Projects sheet. The SAVE pad steps PRESETS → USER → PATTERNS → PROJECT, as the FM-1's SAVE does.
When the screen link is on, the FM-1's own SAVE page sends Jib to the same place. iPad Song-tab layout only; the iPhone and SLOOP are unchanged.

## What's there
- **USER (Sounds tab):**
  - All 32 slots. A saved sound loads with a tap. Its ⋯ menu replaces it with the track's sound (name asked) or erases it (confirm, destructive).
  - An empty slot is a dashed key ("U03 · Empty") that saves the track's sound there.
  - Opening the tab no longer resets it to the engine list, so SAVE > USER sticks.
- **Save sound (sound panel header, Skiff):**
  - Opens a Jib menu: "Save to U03…" (the next empty slot), or "Replace a saved sound ›" with the used slots listed.
  - One name prompt is shared app-wide. A used slot gets a destructive "Replace" and says what it overwrites.
  - Names are upper case and at most 12 characters, as Skiff stores them.
- **PATTERNS (Song tab drawer):**
  - Each pattern row has a ⋯ with "Empty its steps…" and "Clear pattern…", each confirmed.
  - Clear is disabled while anything uses the pattern; the menu says how many entries and tracks use it.
  - Both are disabled while playing, with "Stop to change patterns".
  - Clear unused, "used by" and the lengths were already there.
- **PROJECT (Projects sheet; the top bar's folder key on Skiff):**
  - "On the FM-1" shows P1–P4 with names, "Playing now", and whether the music changed since.
  - Load asks first, and is destructive when there are unsaved changes.
  - Save here or Save over asks for a name. Save over takes a whole-FM-1 backup to Files first and leaves the slot alone if the backup fails.
  - On Skiff the iPad-projects section explains that those open on SLOOP; New project and Save as stay SLOOP-only.

## Protocol and tests
- **Driver:**
  - UP_STORE 19, UP_ERASE 21, POOL 78 ops 1 and 2 (rc 2 maps to "in use"), PROJ_NAME 77 (read, SAVE AS), PROJECT 9 load.
  - FakeSkiff answers all of them with state. The fake's pool now answers "nothing there" before refusing because it's playing, as skiff-sim does.
- **SkiffSaveTests (fake), 3 tests, pass:**
  - store and erase round trip;
  - Clear refused while in use, Empty keeps the pattern;
  - project read, save as and load, plus an empty slot loading nothing.
- **SkiffSaveSimTests (skiff-sim), 4 tests, pass:**
  - slot U32 stored ("SIM TEST") and erased again;
  - a pattern made, Clear refused while in use, Empty done, cleared after its entry went, Empty refused while playing;
  - backup capture (29 objects);
  - project slots read, and an empty slot loads nothing.
  - Nothing was saved to the sim's project slots, because no command erases one.
- **Full package suite:** 238 tests, 1 failure. SongSessionTests.sectionsChainsOrderAndSongRec is a SLOOP timing flake under load; it passes on its own.

## Pre-flight (design-standards)
- **Grayscale:**
  - Saved slots are raised keys with a name and a detail line; empty ones are dashed outlines with secondary text, so they read apart without colour.
  - The playing slot carries the existing LED and a bold name.
- **Spacing, type and tokens:** the existing key, menu and sheet components; Theme tokens only. One new value: the 4/3 dash.
- **States:**
  - Empty: dashed keys, and "Reading the FM-1's projects…".
  - Busy: progress rows in the sheet.
  - Errors: inline, saying what happened and what to do ("The backup didn't finish, so P2 was left as it is"; "Sound not saved… Stop the transport and try again").
  - Disabled: drums, playing, in use.
- **Destructive friction by severity:**
  - Loading a sound needs no confirm (it can be reloaded).
  - Replace and Erase a slot, and Empty and Clear a pattern, get a destructive alert.
  - Save over a project gets a backup first, then the alert.
  - Load project is destructive only when unsaved changes would be lost.
- **Targets:** every ⋯ is 44 × 40–56 pt, the panel key is 44 × 44 pt, the sheet buttons are system bordered.
- **VoiceOver:**
  - Slots read "U03, empty", with a hint.
  - Pattern rows have "Empty pattern" and "Clear pattern" actions; the ⋯ keys are labelled.
  - Not run with VoiceOver itself.
- **Taste anchor:** data-dense tool. No new colour; the accent stays on state.
- **Tells check:** check-tells.sh scans no Swift. It ran but found nothing to scan, which is not a pass.
- **Not checked:**
  - Light mode; Dynamic Type at large sizes; keyboard traversal of the new menus; the real FM-1.
  - The backup → save path end to end: the fake has no BACKUP_LIST, so in the demo it stops at "backup didn't finish", which is the safe path working. Backup capture itself passes on skiff-sim.

## Screens
- panel-save-key.png: the sound panel with its Save sound key (beside Pin).
- panel-save-menu.png: its menu, "Save to U03…" and "Replace a saved sound ›".
