# Jib (FM1 iPad): test plan

What each part of the app is checked by. **A**: automated (`cd ios/SloopKit && swift test`), runs against the pretend FM-1s (`FakeSkiff`, `FakeLoader`) and skiff-sim. **H**: by hand on the FM-1. **S**: in the simulator with `-demo` (the demo is a pretend Skiff).

**Lupe is Skiff-only since 2026-11-15 (decision 43).** This plan was written for SLOOP (the hardware pass of 2026-11-02 ran on SLOOP 2.8.4); the SLOOP-only checks are retired below and kept as history at the tag `sloop-archive-2026-11-15`. Skiff's features are checked per batch in `qa/device-checks/`. 299 automated tests pass (2026-11-15). Accessibility (section 6) still not run.

## 1. Connection and protocol

| Check | How | Status |
|---|---|---|
| SysEx framing, a frame split across packets, notes in between | A `FrameTests` | pass |
| A frame that never ends is dropped; the next one still arrives | A `aFrameThatNeverEndsIsDropped` | pass |
| Replies matched to requests, timeouts, retries | A `SkiffTests`, `SkiffSimTests` | pass |
| Stock Skiff vs the screen-link builds told apart (INFO's `56 01` tag) | A `SkiffTests`, `SkiffButtonMapTests` | pass |
| Wrong firmware refused; SLOOP's INFO lands as unknown firmware and is recognised for the Skiff-Lupe offer | A `SloopRefusalTests` | pass |
| Device values out of range (track 9, step 71, negative root, scale 99, division −1) never crash | A `pushesWithImpossibleValuesAreIgnoredOrClamped` | pass |
| Unplug and replug the FM-1 mid-session (iPad audio on) | H (2026-11-02) | pass |
| Settings object over 4 KB or a GET that returns nothing stops instead of looping | code review; no test | covered by guard |

## 2. Sequencer

| Check | How | Status |
|---|---|---|
| Tap a cell adds / removes a note; drum lanes the same | H (2026-11-01) | pass |
| Slide along a row: adds from an empty cell, erases from a note, never the other way | H, S | pass |
| Note length from the grip | H (2026-11-02) | pass |
| Grid never moves unless panned (rows added above, playback) | H | pass |
| Step numbers select a step | H | pass |
| Velocity dial: no jumps; last value wins | H (its automated test was SLOOP's, retired 2026-11-15) | owed on Skiff |
| Ratchet ×1–×4 audible | H (2026-11-02) | pass |
| Fast drum toggles don't lose a lane (latest-wins added in QA) | H (2026-11-02) | pass |
| Clear all, with Undo | H | pass |

## 3. Song

SLOOP's sections A–D, song order, song mode and SONG REC: retired with SLOOP (decision 43, 2026-11-15). Skiff's Song tab (the lists, the pool, the pads and the Timeline) is checked by `SkiffSongTests`, `SkiffSongSimTests`, `PlayFromStartSimTests` and the device checks in `qa/device-checks/`.

## 4. Screen link and pages

| Check | How | Status |
|---|---|---|
| Tabs follow the FM-1's buttons and the other way | H | pass |
| SAVE pad: Library, again for Song; held for Song | H | pass |
| Track box mute-only on the Song page | H | pass |
| (SLOOP's fixed drum track rows retired 2026-11-15: Skiff's kits are tracks on DRUM or DRUM-X) | | n/a |

## 4a. Sampler

| Check | How | Status |
|---|---|---|
| Slots read on connect; a slot's name and size shown | A `skiffTakesSamplesInItsThreeSlots` | pass |
| Upload: 256-byte writes in order, progress moves, the header's CRC checked; too long or empty refused | A `SampleTests` | pass |
| Short sample forms refused without a reply, as Skiff does | A `skiffRefusesShortSampleFormsWithoutAReply` | pass |
| An upload or erase isn't a project edit; putting a slot on a track is | A | pass |
| Record with the iPad mic, trim, upload, play it on a track | H (2026-11-03, Scott) | pass |

## 5. Device safety

- **Back up the FM-1** before any hardware run of a write check (Lupe's backup, or Skiff's web editor).
- Flash writes the app can cause: uploading or erasing a sample slot, projects (saved into a slot, or put on the FM-1 from the iPad), patterns in the pool, user presets, MENU settings (USB LEVEL), and firmware installs (each after a backup when Lupe can take one; never over SLOOP, which Lupe can't read).

## 6. Accessibility (needs a person)

Automated checks don't cover these. Run once per pass:

1. VoiceOver through each tab: every control has a name; the grids read step by step.
2. Full keyboard access (iPad with a keyboard): every control reachable, focus visible.
3. Larger Text at the largest size: nothing clipped.
4. Reduce Motion on: the timeline and tab changes don't animate.

Status: **not run** this pass. 2026-11-10: an automated audit and a code review ran (`qa/accessibility-2026-11-10/README.md`), and the walk-through above is written as a device check (`qa/device-checks/2026-11-10-accessibility.md`); the human pass itself is still owed.

## 7. Not covered yet

- One UI test target (2026-11-10): `FM1UITests`, the accessibility audit on each main screen (simulator, the Skiff demo). No UI tests of behaviour: the gestures (slide, grip, two-finger pan, the knob ring) are checked by hand.
- No crash reporting from the iPad (TestFlight would give it).
- Long sessions: memory and battery over an hour of playing.
