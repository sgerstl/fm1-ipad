# Device check: claude/android-p1-core-link-faf639, 2026-11-15 (move a pad; clear a pattern's notes)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

The core's side of two things for the pads. P2 draws the drag and the menu items, so each check needs P2's screen.

- **Move a pad** (batch item 2): drag a pad to another place on its own track, as on the iPad.
- **Clear steps:** wipe a pattern's notes while the pad and the pattern stay, also while playing, with the
  ten-second Undo.

**Setup:** FM-1 on Skiff 2.5.1. Pixel on this branch merged into the combined one, writes allowed.

**Back up first: yes, by the rule** (moving pads rewrites a track's list and clearing notes rewrites a pattern; the
FM-1 saves both). Scott, 2026-11-14: "nothing on the FM-1 matters now", so he may skip it.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Stopped. Drag a pad onto another filled pad on the same track. | The two swap, on the phone and on the FM-1's SEQ › SONG. | Yes | ☐ pass ☐ fail: |
| 2 | Drag a pad onto an empty pad far to the right on the same track. | It lands on the first empty place after the track's last pad, and its old place is left empty. | Yes | ☐ pass ☐ fail: |
| 3 | Drag a pad onto another track. | It doesn't move. A strip says a pad moves only within its own track, and to share or copy. | – | ☐ pass ☐ fail: |
| 4 | Press Play and drag a pad to another place. | A strip: stop to rearrange. Nothing moves. | – | ☐ pass ☐ fail: |
| 5 | Playing, on the pad a track is playing: Clear steps. | The pattern goes silent within a bar, the pad stays lit with its number, and an Undo strip shows. | Yes | ☐ pass ☐ fail: |
| 6 | Tap Undo within ten seconds. | The notes are back and it plays as before. | Yes | ☐ pass ☐ fail: |
| 7 | Playing: Clear steps on a pad the track is not playing. | A strip says only the playing pattern can be cleared while playing. Nothing changes. | – | ☐ pass ☐ fail: |
| 8 | Stopped: Clear steps on a pad the track is not on. | The track goes to that pad, its notes are gone, and Undo brings them back. | Yes | ☐ pass ☐ fail: |

**Not covered here:**

- Whether the gap a move leaves should close (pattern-pad.md B18, still open): this build keeps it, as the iPad does.
- Locks and automation on the steps: Clear steps leaves a pattern's automation alone.
- TalkBack and a non-drag way to move a pad: P2's side and the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
