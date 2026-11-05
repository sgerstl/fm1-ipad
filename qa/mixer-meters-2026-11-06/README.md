# The Mixer's level lines, 2026-11-06

Scott: "it should just do what the graphic on the FM-1 does... a little level line the colour of the main one, right next to it, pulsing upward indicating level."

## What the FM-1 draws (ui_graph.c draw_tracks, MIXER)

- **Where:** a 2 px line beside each strip's LEVEL fader, the fader's height, rising from its foot.
- **What it measures:** `ts.meter[c]`. Each screen frame, the track's peak |sample| since the last frame (`peak_take(PK_SCREEN, c)`, from `trk[c].peak`, which the audio path raises) goes through `meter_px`: 8·log2, so 60 dB over the line (−54 to +6 dB). A muted track reads 0.
- **Ballistics:** instant attack. It falls at most 1 px a frame (`ts.meter[c] - 1`), about 2 dB per 16 ms frame, so the full scale in about half a second.
- **The screen link's METER** (editor.c, `56 01 03`, pushed with WATCH bit 3), from the screen-link session's work in progress: the same peak through its own `peak_take(PK_EDITOR, c)`, so the screen's meters lose nothing. It's put on 0–127 by `ed_met_lvl` (the same log scale), falls as the screen's do (127/30 per 16 ms), and is pushed as command 92, one byte per track. That's every 40 ms while anything changes and once a second otherwise, and only into an empty output queue.

## What Lupe draws

- **The line:** 3 pt, in the track's colour, just past the fader cap's right edge, over a dim rail (`meters.jpg`). It moves at the FM-1's fall (`two-frames.jpg`, 130 ms apart).
- **The source switches** (`TrackMeters`, SloopKit):
  - **Measured:** METER when the FM-1's INFO says `56 01 03`. Lupe sets WATCH bit 3 and draws the pushed levels, falling between pushes at the same rate.
  - **Estimated:** otherwise, Skiff's USB MIDI note output on each track's channel. A note-on rises to its velocity, the line holds while notes are held, then falls at the meter's rate. **This is estimated note activity, not audio level.** It doesn't know the sound's envelope or release, a quiet patch reads as loud as a loud one, and effects tails don't show.
- **Muted tracks:** the line shows the track's note activity, dimmed to 35%, so a muted track that's playing is visible. METER reads 0 for a muted track, so this comes from the notes in both modes.
- **Reduce Motion:** a steady line (three-quarters up) while the track sounds, none otherwise, no pulse.
- **Cost:** each line is its own 30 fps TimelineView, paused unless `TrackMeters.active` (a level above 0 or a note held in the last half second). The strips' own bodies never redraw for it.
  - Simulator, Mixer with METER: playing 14.2% of one core (Mixer playing was 8–10% before the lines), stopped 1.9%.
- **NoteEvent now carries velocity.** FakeSkiff answers WATCH bit 3 and pushes METER while playing (`-demo-meter`, its `56 01 03` build).

## When the firmware lands

Merging `refs/heads/skiff-screen-link` with the METER build and pinning its hash is next, once the screen-link session says it's there. Then the update offer goes to `56 01 02` units too, and Lupe switches to measured levels on its own.

## Checked / not checked

- Checked:
  - `theMeterBuildPushesLevels` (WATCH bit 3 is asked for, a push becomes measured levels);
  - `noteActivityRisesHoldsAndFalls`;
  - simulator screenshots with `-demo-meter`.
- The full suite: 224 tests. `WorkflowTests.aSectionClearsOnlyWhenStopped` (SLOOP) failed in the full run and once in two runs on its own: a timing flake in the SLOOP fake, untouched here, still to look at.
- Not checked: the estimate from real note output (the demo's fake sends no notes); the real METER (the firmware isn't merged yet); VoiceOver (the lines are hidden from it, the dB under the fader speaks).

Design pre-flight: ran. It's the FM-1's own mark, in the track's colour, over the rail's grey. There's no new type or target, motion is the meter's fall (none under Reduce Motion), and it's display-link coalesced.

## The METER firmware landed (same day)

- **Merged** `refs/heads/skiff-screen-link` (6704d65, tag `lupe-skiff-2.2-screen-link.3`). The bundled package is pinned at `0c0972ab…4679` (610,429 B, INFO `56 01 03`) and replaces `f11c90e3…f11e`. FIRMWARE.md is updated. **Not on a real FM-1 yet.**
- **The update offer** now goes to stock Skiff 2.2 and to both earlier screen-link builds (`56 01 01`, `56 01 02`), worded for what the new build adds: the cursor and the levels.
- **Lupe checked against the final format** (skiff/README.md "METER"): WATCH bit 3, push 92 with six bytes 0–127, already ballistic on the device. Lupe now draws the values **as they come and holds them between pushes**; it no longer adds its own fall. After **1.5 s** with no push, a reading is stale (watching probably lapsed) and the notes' estimate takes over until METER returns. Silence arrives as six zeros once a second.
- **Tests made deterministic:**
  - `WorkflowTests.aSectionClearsOnlyWhenStopped` now waits until "stopped" has held past an in-flight live poll before clearing. That poll could report PLAY once more, so the clear was refused.
  - `aLoopSavedToASectionComesBack` waits for `sectionPlaying` instead of racing it.
  - `FrameTests.notesOutsideSysEx` expects velocities now.
  - Two full runs both passed afterwards.
