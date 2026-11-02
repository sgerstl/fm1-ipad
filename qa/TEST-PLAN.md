# FM1 iPad: test plan

What each part of the app is checked by. **A**: automated (`cd ios/SloopKit && swift test`), runs against the demo FM-1, which mirrors SLOOP's behaviour where it matters (sections hold the tracks, song mode keeps the loop, RELOAD only for the selected track). **H**: by hand on the FM-1. **S**: in the simulator with `-demo`.

Last full pass: 2026-11-01, branch `app-pass-1`. 51 automated tests pass (8 runs in a row after the chain-test fix); build has no warnings; the static analyzer and Swift's strict concurrency checks find nothing in SloopKit.

## 1. Connection and protocol

| Check | How | Status |
|---|---|---|
| SysEx framing, a frame split across packets, notes in between | A `FrameTests` | pass |
| A frame that never ends is dropped; the next one still arrives | A `aFrameThatNeverEndsIsDropped` | pass |
| Replies matched to requests, timeouts, retries | A `SessionTests` | pass |
| Stock SLOOP vs the screen-link build told apart | A `stockFirmwareHasNoScreenLink`, `screenLinkWithTheModifiedFirmware` | pass |
| Wrong firmware refused | A `refusesOtherFirmware` | pass |
| Device values out of range (track 9, step 71, negative root, scale 99, division −1) never crash | A `pushesWithImpossibleValuesAreIgnoredOrClamped` | pass |
| Unplug and replug the FM-1 mid-session | H | **to do** |
| Settings object over 4 KB or a GET that returns nothing stops instead of looping | code review; no test | covered by guard |

## 2. Sequencer

| Check | How | Status |
|---|---|---|
| Tap a cell adds / removes a note; drum lanes the same | H (2026-11-01) | pass |
| Slide along a row: adds from an empty cell, erases from a note, never the other way | H, S | pass |
| Note length from the grip | S; H after the grip change | **re-check on H** |
| Grid never moves unless panned (rows added above, playback) | H | pass |
| Step numbers select a step | H | pass |
| Velocity dial: no jumps; last value wins | A `aFastDialSendsTheLastValue`, H | pass |
| Ratchet ×1–×4 audible | H | **to do** (listen for the hits) |
| Fast drum toggles don't lose a lane (latest-wins added in QA) | code; no test | **re-check on H** |
| Clear all, with Undo | H | pass |

## 3. Song

| Check | How | Status |
|---|---|---|
| A loop saved to a section comes back when the section is picked | A `aLoopSavedToASectionComesBack`, H | pass |
| Picking a section replaces unsaved edits (SLOOP keeps no copy), and the app asks first | A `unsavedEditsAreReplacedWhenASectionLoads`, `editsMarkTheTracksUntilStoredOrReplaced`, S | pass |
| A section load shows on **all four** tracks, not only the selected one (fixed in QA) | A | pass; **re-check on H** |
| A song plays its sections in order, loops | A `aSongPlaysItsSectionsInOrder` | pass; **H to do** |
| Song mode keeps the loop; STOP brings it back | A `songModeKeepsTheLoopAndStopBringsItBack` | pass; **H to do** |
| The order can't change while the song plays | A | pass |
| Writing the order: re-reads the settings first, one write at a time, refused write rolls back | A `aBadSettingsWriteIsRefusedAndTheOrderRollsBack` | pass; **H to do** (back up first) |
| SONG REC writes what was played; the iPad shows it | A `songRecWritesWhatWasPlayed` | pass; **H to do** |
| Chains | A (start/stop only); no longer in the app's UI (2026-11-02) | n/a |
| SONG marker; grid header says edits end at STOP while the song plays | S | pass |
| Song blocks: tap opens the menu (move ‹ ›, section, duplicate, delete) and the bars control | S (2026-11-02) | pass; **re-check on H** |
| Press and drag a block moves it; the others slide aside | S | pass; **re-check on H** |
| Swipe a block up: it goes, an empty slot stays, Undo for 6 s; the FM-1 gets the order without the slot | S | pass; **re-check on H** |
| Tap an empty slot, pick a section: it fills | S | pass |
| Drag a block's right edge: bars change, the row re-fits on release | S | pass |
| Bar pills: one per bar, played bars fill while the song plays | S | pass; **re-check on H** |
| SONG REC asks before replacing a song that has steps | code; no test | **re-check on H** |
| Blocks locked while the song plays or SONG REC records | S | pass |

## 4. Screen link and pages

| Check | How | Status |
|---|---|---|
| Tabs follow the FM-1's buttons and the other way | H | pass |
| SAVE pad: Library, again for Song; held for Song | H | pass |
| Track box mute-only on the Song page | H | pass |
| Drum track: SEL, ENV, LFO, EDIT, ARP pressed on the FM-1 open those pages greyed, with the reason | H (2026-11-01) | pass |
| Drum track: the same pads on the iPad send the FM-1 to its "DRUM TRACK" page | S | pass; **re-check on H** |
| Drum track FX: which of FILTER, SLICER, INSERT the FM-1 allows | H | **to do** (source allows all three) |

## 5. Device safety

- **Back up the FM-1** in SLOOP's web editor before any hardware run of section 3's write checks.
- Flash writes the app can cause: storing a section (SAVE + key), the song order (BK_PUT), user presets. Each is sent once; the order write re-reads the object first and changes only bytes 48–83; a commit is never retried.
- The app never sends firmware.

## 6. Accessibility (needs a person)

Automated checks don't cover these. Run once per pass:

1. VoiceOver through each tab: every control has a name; the grids read step by step.
2. Full keyboard access (iPad with a keyboard): every control reachable, focus visible.
3. Larger Text at the largest size: nothing clipped.
4. Reduce Motion on: the timeline and tab changes don't animate.

Status: **not run** this pass.

## 7. Not covered yet

- No UI tests (XCUITest). The gestures (slide, grip, two-finger pan, the knob ring) are checked by hand.
- No crash reporting from the iPad (TestFlight would give it).
- Long sessions: memory and battery over an hour of playing.
