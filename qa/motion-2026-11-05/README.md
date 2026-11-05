# Skiff's motion: shown, warned about, cleared (2026-11-05)

Scott had been recording knob moves by accident. **Skiff's rule** (EDITOR_PROTOCOL.md "Motion"): while the selected track is armed and playing, every move of a recordable parameter is recorded into the step playing. That covers the FM-1's knobs and an editor's SET / TRACK_PARAM alike, so Jib's knobs record too. Motion isn't pushed: an editor polls MOTION (64), as Skiff's web editor does.

**Checked on skiff-sim** (Skiff's real code): with T1 armed and playing, three TRACK_PARAM edits of CHO from the editor were recorded at steps 3, 4 and 5, as automation. MOTION op 7 read them with their kinds, and op 2 cleared them.

What Jib does now:

- **Reads motion:** the selected track every 2 s (every second while it's recording), every track every 6 s.
- **Shows it:** a step with recorded knob moves has a bar along its foot in the track rows (shot 01: T1's step 1). The bar is dark on a filled step and light on an empty one, so it doesn't rely on colour.
- **Warns:** while the selected track is armed and playing, a bar at the foot of the screen says "Recording knob moves on T1: every change, here or on the FM-1, goes into its steps", with **Stop recording**. It floats, so nothing moves when it comes and goes (iPad and iPhone).
- **Clears:** the track menu (long press a track) has **Clear motion (n steps)** when the track has any. On the FM-1, SAVE held undoes it.

Tests: MOTION decoded, recorded, flagged and cleared through the fake; the same against skiff-sim.

Not done: per-parameter detail (which parameter moves on which step) and a step's locks shown apart from recorded motion. Clear motion drops both, as Skiff's op 2 does.

## "I don't see the motion changes" (Scott, real FM-1, on ec594dd)

What was checked:
- **The protocol, on Skiff's own firmware code:** skiff-sim recorded CHORUS moves on T1 (steps 3–14) and T2, and Jib's
  MOTION op 7 read them back (`leavesMotionForTheApp`, `SKIFF_SIM=1 SKIFF_KEEP_MOTION=1`, which leaves them there).
- **The poll:** it runs for any Skiff connection (the ping loop: the selected track every 2 s, all of them every 6 s).
  No INFO capability gates it.
- **What not checked:** the app talking to skiff-sim end to end. The iOS simulator doesn't see the host's virtual MIDI
  port, so that leg can only be checked on the iPad with the FM-1.

Cause: the only sign of motion was a 2 pt bar along the foot of each step in the timeline at the top (16 pt cells with
six tracks), dark on a lit step. Nothing in the Sequence grid and nothing on the track. Next to invisible.

Fix (screenshot 02):
- A **MOTION** tag after the track's name, while it has recorded motion.
- A **bar under the step number** over the Sequence grid for each step with motion (synth and drum grids).
- The timeline's foot bar 3 pt and wider.
- The demo (`-demo-skiff`) starts with motion recorded on T1, steps 3–14, so this can be seen without the FM-1.

If the tag still doesn't appear on the FM-1, the track's motion is empty there (cleared, or never kept) or the read
fails quietly. The next step would be a Developer readout of the last MOTION reply.
