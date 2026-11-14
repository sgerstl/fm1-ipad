# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (picture data back; the outline timer's data)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

Two things from Scott's device session on d0d929a:

- **Pictures as a setting (decision 30).** The core publishes each page's picture data again (`graph`), and the same
  for Mix's bus cards. P2 draws them, so checks 1–3 need P2's pictures.
- **The outline timer didn't show.** On the fake FM-1 the core publishes the right data. On the device the areas
  can't be seen from logcat, so this build logs each wait. Checks 4–6 read that log.

**Setup:** FM-1 on Skiff 2.5.1 on the Pixel's USB port · this branch merged into the combined one · real core, writes
allowed (`--ez allowWrites true`) · for checks 4–6, a terminal running:

```bash
adb logcat -s LupeLog | grep "wait"
```

**Back up first: no.** These checks open pages, launch pads and mute a track.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Turn pictures on in Settings. Open ENV, then turn ATTACK on the FM-1. | The envelope picture under the dials changes shape with the knob. | No | ☐ pass ☐ fail: |
| 2 | FM6 track, EDIT › OPERATOR. Press SELECT on the FM-1. | The operator picture stays, and the four dials change to the next row. | – | ☐ pass ☐ fail: |
| 3 | Mix › Delay. Turn FEEDBACK on the phone. | The delay card's picture follows the value. | – | ☐ pass ☐ fail: |
| 4 | Press PLAY on the phone (not on the FM-1). LAUNCH on LOOP. Tap another pad on track 1. | The log shows `wait: T1 pad N lands at <tick> (clock running, …)`, then `wait over: …` when the FM-1 switches. Note whether the outline drew. | – | ☐ pass ☐ fail: |
| 5 | While playing, press a Mute key. | The log shows `wait: T… mute lands at <tick> (clock running, …)`, then `wait over`. Note whether the outline drew. | – | ☐ pass ☐ fail: |
| 6 | Read the lines from 4 and 5. | Each has a tick and "clock running". If one says "no tick" or "no clock", it's a core fault: send the lines. If they're right and no outline drew, it's the drawing. | – | ☐ pass ☐ fail: |

## The FX family's pictures (added after P2's e546ff3)

The core now sends DELAY, REVERB, INSERT, SLICER and DUCK as pictures, with the three values P2 had to assume.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 7 | Pictures on. FX › DELAY on a track with some send. Then Mix › Delay: turn MIX down. Go back to FX › DELAY. | The track's echoes in the picture are smaller than before. | – | ☐ pass ☐ fail: |
| 8 | FX › INSERT, TYPE SOFT. Turn INSERT's MIX down on the FM-1 (its PRESETS encoder). | The picture's curve moves toward the straight dry line. | – | ☐ pass ☐ fail: |
| 9 | FX › DUCK: set BY to a track that has a few steps on. | The picture shows a dip at each of that track's hits across the bar. With BY off, the box is empty. | – | ☐ pass ☐ fail: |

## CHORD and FOLLOW's pictures (need P2's drawing)

The core sends the chord a key plays as its notes, and FOLLOW's track and how it follows.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 10 | Pictures on, a synth track. SEL › CHORD: set CHORD to MAJ, then turn VOICING. | The chord's name and its keys lit, the root marked, the same notes the FM-1's CHORD picture shows before a key is played. With CHORD off: "CHORD KEYS OFF". | – | ☐ pass ☐ fail: |
| 11 | Same page: turn STRUM up to about 30, then DIR to UP. | The picture changes to the notes in time, captioned "UP 30 ms", as on the FM-1. | – | ☐ pass ☐ fail: |
| 12 | SEL › FOLLOW: set FOLLOW to another synth track, then to a drum track, then OFF. | "FOLLOWS T3 · KEY BY ITS ROOT" in that track's colour; then "T… PLAYS A KIT"; then "FOLLOW OFF". | – | ☐ pass ☐ fail: |

**Not covered here:**

- FOLLOW's live chord: the FM-1 doesn't send it to an editor, so the phone names the track and leaves the chord to
  the FM-1's screen, as the iPad does.

- LAUNCH on NOW or BEAT: the launch lands at once or within a beat, so there is little or nothing to draw.
- Connecting while the FM-1 already plays: no clock until the next Stop and Play, so the outlines are dashed.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
