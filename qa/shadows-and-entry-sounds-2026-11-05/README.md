# Panel shadows, and Skiff's entry sounds on Shape (2026-11-05)

Two things Scott found on the real FM-1 with stock Skiff 2.2.

## 1. Every element in the tempo panel had a shadow

**Cause:** the level-3 shadow was on the panel's whole stack (`.background(shape).elevationShadow(…)`). SwiftUI shades every opaque child of a view with a shadow, so each key, the number and the field cast their own. It's now on the background shape only: one shadow for the panel. The same mistake was in Jib's menu panel (the hold menu, Set sound, the add menu) and in Arrange's pattern-drop ghost; fixed there too. The shared `Elevated` modifier, the track chips and the knob rings already had theirs on a shape.

| Shot | |
|---|---|
| 01 | The tempo panel, before (left) and after |
| 02 | The hold menu, before (left) and after (rows are text, so the change is smaller: the halo around each label is gone) |

## 2. Shape kept jumping to EDIT while the song played, and the engine changed bar by bar

**Where the sounds came from (Skiff's source):** an entry gets its own sound only through the editor protocol's SOUND op (`LIST2` op 9, which is Arrange's Set sound) or through SOUND picked on the FM-1's song page, which copies the selected track's sound onto an entry (`bank.c` `song_snd`). Changing the sound while an entry plays doesn't write to the entry. Jib's Shape edits only ever set the track's parameters, never op 9 (checked: Set sound and list rewrites carrying existing sounds are the only senders). So the piano, flute and sax were put on those entries by Set sound, or by SOUND on the FM-1. Neither Jib nor Skiff records which.

**Why the engine changes:** that's Skiff's design. An entry with a sound loads it into the track each time the entry starts (`launch.c` `esnd_put`), so a song with entry sounds changes the track's sound bar by bar.

**Why Shape jumped (Jib's bug):** Jib read every CHANGED push from the FM-1 as a knob turned there, and Shape follows a turned knob to its button's pages. When an entry's sound loads with the track's engine and preset unchanged, Skiff pushes CHANGED for every value that differs, a burst, and Shape went to the page of the last one, usually EDIT. (When the engine or preset changes, Skiff sends RELOAD instead.) Now a change is a knob turn only if no burst of three or more parameters arrives within 250 ms and no RELOAD within 600 ms. Shape still updates its values in place, it just doesn't move. A real knob turn on the FM-1 is followed 150 ms later, as before.

**Saying where an edit goes:** while the selected track plays an entry's own sound, Shape says so (iPad and phone): "T5 is playing entry B's own sound, PD Strings. Changes here last until entry B starts again; to keep them, save a user preset and set it on entry B in Arrange." That's how Skiff behaves: an edit changes the sound playing now, and the entry's own sound comes back when the entry next starts.

**Arrange:** an entry with a sound shows a waveform next to its letter (on narrow blocks too), as well as the cut corner and the sound's name (03, T5's entry B).

**The screen link stays inert on stock Skiff:** without INFO's `56 01 01`, Jib never asks SCREEN, `deviceScreen` stays nil, and nothing follows a screen (pinned by `stockSkiffHasNoLink`).

## Pre-flight (design-standards)

- Depth: one shadow per elevated surface, on its shape (surface step, then the shadow, per the depth order).
- The Shape line: what's happening and what to do, with an icon and words, never colour alone; 13 pt, `Theme.control`.
- Arrange's mark: an icon beside the letter, plus the existing corner cut and name (not colour).
- **Not seen on screen:** the Shape line. The demo doesn't play an entry with a sound (its tracks stay on entry A). The logic is covered by the session tests; the line is a plain label.
- Not checked: a real FM-1, VoiceOver running, the phone's Shape.
