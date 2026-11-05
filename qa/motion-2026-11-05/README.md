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
