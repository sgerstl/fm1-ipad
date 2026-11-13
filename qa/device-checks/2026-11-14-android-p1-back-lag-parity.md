# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (back to the pattern, the sound key's lag, page parity)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

Part B is for the **iPad**. It covers the shared SloopKit changes: Skiff's number rules, FM6's names, and the EDIT
knobs after a preset of another engine.

**Setup:**

- FM-1 on Skiff 2.5.1.
- Pixel: this branch merged into the combined one, with P2's back gesture wired to `GoHome`. Real core, writes
  allowed (`--ez allowWrites true`).
- iPad: Lupe built from this branch's SloopKit.

**Back up first: no.** Scott, 2026-11-14: "nothing on the FM-1 matters now". Checks 3, 7, 8 and 14 load a preset
on track 1. Nothing writes the FM-1's flash.

## A. The phone

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open a sound page from the phone (ENV), then use Android's **back gesture**. | The FM-1 goes to HOME, and the phone's bottom half is the steps again, at once. | No | ☐ pass ☐ fail: |
| 2 | Press a family key on the phone (FX, then LFO, then ENV), stopped and then playing. | The phone's page changes with the FM-1, with no moment between. If there is one, send the `lag` lines: `adb logcat -s LupeLog \| grep " lag "` (see android/notes/page-lag.md). | – | ☐ pass ☐ fail: |
| 3 | Sounds: load **PHASE › PD BRASS** on track 1, then open EDIT. | EDIT 1 reads WAVE, WAVE2, DCW, ENV (PHASE's own), not ANALOG's WAVE, DETUNE, MIX, NOISE. | – | ☐ pass ☐ fail: |
| 4 | LFO page: turn RATE to its lowest. | ".05 Hz" on both the FM-1 and the phone. | – | ☐ pass ☐ fail: |
| 5 | FX › DELAY: FEEDBACK at the middle of its travel. | The same percentage on both (for example 47%, not 50%). | – | ☐ pass ☐ fail: |
| 6 | FX › INSERT: TYPE SOFT, then turn C (LEVEL) a little up from the bottom. | The phone's knobs read DRIVE, TONE, LEVEL, and LEVEL shows a tenth, as on the FM-1 ("-55.5 dB"). | – | ☐ pass ☐ fail: |
| 7 | Load an FM6 preset, open EDIT. | ALGO reads "PAT" at 0 and numbers after; on EDIT 2, PATCH reads F1…F8, OWN, as on the FM-1. | – | ☐ pass ☐ fail: |
| 8 | Load **SAMPLE**, open EDIT 2. | Knobs 2 and 4 are blank on the phone, as they are on the FM-1. | – | ☐ pass ☐ fail: |

## B. The iPad (shared SloopKit)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 9 | Sound tab, LFO: RATE at its lowest. | ".05 Hz", as on the FM-1 (it read "0.05 Hz" before). | – | ☐ pass ☐ fail: |
| 10 | Library: load a preset of another engine on the selected track, then open its EDIT page. | The new engine's knob names and values at once. Before, the old engine's stayed until the track was selected again. | – | ☐ pass ☐ fail: |

## C. HOME's four knobs (decision 21, board 70; needs P2's screen for them)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 11 | FM-1 on HOME, track 1 on an ANALOG sound. Look at the phone's four knobs. | CUTOFF, RES, ATTACK, RELEASE with the FM-1's own numbers. | – | ☐ pass ☐ fail: |
| 12 | Turn the FM-1's KNOB 1. | The phone's CUTOFF follows, and its card lights as the FM-1's does, a beat later. | – | ☐ pass ☐ fail: |
| 13 | Slide the phone's RES. | The FM-1's RES follows (HOME's knob 2 shows it). | – | ☐ pass ☐ fail: |
| 14 | Load a PHASE sound on the track. | The phone's four become DCW, ENV, DETUNE, RELEASE, as the FM-1's HOME shows. | – | ☐ pass ☐ fail: |

**Not covered here:**

- Pictures, sheets and MOD's layout: see android/notes/page-parity.md, "Open, for Scott" and "What the test can't
  decide".
- The ♯ or # question.
- VoiceOver: at the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
