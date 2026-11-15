# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (note entry from the phone's keyboard strip)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

This sheet covers the **core** side of decision 28 (board 73, the Edit tab in landscape): the four note-entry intents
in `android/core/Sources/PhoneCore/NoteEntry.swift`. They need P2's keyboard strip to drive them.

**Setup:**

- FM-1 on Skiff 2.5.1, on the Pixel's USB port.
- This branch merged into the combined one, with P2's landscape Edit tab.
- Real core, writes allowed (`--ez allowWrites true`).

**Back up first: no.** Scott, 2026-11-14: "nothing on the FM-1 matters now". Checks 1–6 write steps of the pattern the
track is on. They are in memory, saved only with the project.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Note track, stopped. Pick an empty step and press one key on the phone. | The FM-1's NOTES page shows that note on that step, and the track's sound plays it once. | No | ☐ pass ☐ fail: |
| 2 | Pick a step that has a note and press another key. | The step's note changes. Its length and velocity are the same as before. | – | ☐ pass ☐ fail: |
| 3 | Build a chord on a step: add a second, third and fourth note. Then try a fifth. | The FM-1 shows four notes on the step. The fifth is not added. | – | ☐ pass ☐ fail: |
| 4 | Take the chord's notes off one at a time. | Each goes from the FM-1's step. After the last, the step is empty. | – | ☐ pass ☐ fail: |
| 5 | Press PLAY, then set a step's note while it plays. | The new note plays on the next pass. The FM-1 doesn't refuse it. | – | ☐ pass ☐ fail: |
| 6 | Kit track (DRUM or DRUM-X): tap a lane on a step, then tap it again. | The hit appears on the FM-1's grid, then goes. | – | ☐ pass ☐ fail: |
| 7 | With no step picked, hold a key on the phone, then let go. | The selected track's sound plays while the key is held and stops on release. Nothing is written. | – | ☐ pass ☐ fail: |
| 8 | Make it read-only (the debug screen's **Make read-only**), then press a key and tap a step. | No sound, no change on the FM-1. The log says "read-only: … not sent". | – | ☐ pass ☐ fail: |

**Not covered here:**

- P2's keyboard strip and Edit row themselves (P2's sheet).
- Notes sent while REC is armed and playing: the FM-1 records what it's sent, as from its own keys. Not tried.
- VoiceOver and TalkBack: at the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
