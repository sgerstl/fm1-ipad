# Device check: claude/android-p1-core-link-faf639, 2026-11-15 (managing patterns, board 79: the core's side)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

The core now gives the phone what the Patterns sheet needs: every kept pattern with its length, where it is used,
whether saved projects hold it too, its picture, and three actions (clear chosen patterns, recycle an unused one
onto a pad, copy one). P2 draws the sheet, so every check needs P2's screen.

**Setup:** FM-1 on Skiff 2.5.1 with LUPE TEST loaded. Pixel on this branch merged into the combined one, with P2's
Patterns sheet. Writes allowed for checks 4–7.

**Back up first: yes, by the rule, before checks 5 and 6.** Clearing erases patterns from the FM-1's flash and
recycling empties one; neither can be undone. Scott, 2026-11-14: "nothing on the FM-1 matters now", so he may skip
it for LUPE TEST.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Stopped. Open the Patterns sheet. Compare three cards with the FM-1's SAVE › PATTERNS. | The same numbers kept, the same lengths, and "used here" naming the pads that show that number. Unused ones are the ones the FM-1's CLEAR UNUSED counts. | – | ☐ pass ☐ fail: |
| 2 | Keep the sheet open, stopped, and wait about five seconds. | Pictures appear on the cards. The FM-1 doesn't start or stop anything. Close and reopen: they are there at once. | – | ☐ pass ☐ fail: |
| 3 | Press Play, then open the sheet. | Playback keeps going (it must not stop). Cards on a playing track show their picture; the others show length bars and "Stop to load pictures". | – | ☐ pass ☐ fail: |
| 4 | Playing, pick an unused card and Clear. | A strip: stop playback to clear patterns. Nothing is cleared. | – | ☐ pass ☐ fail: |
| 5 | Stopped. Pick two unused cards, Clear, confirm. | A strip: "Cleared patterns 07 and 12. N pattern numbers are free." Both cards go, and on the FM-1 those numbers are empty. | Yes | ☐ pass ☐ fail: |
| 6 | Stopped, with an unused pattern left. Hold an empty pad, Recycle an unused pattern. | The pad shows the number the menu named, empty of notes, and a strip says it was emptied and put there. On the FM-1 the pad plays an empty pattern. | Yes | ☐ pass ☐ fail: |
| 7 | With a free number, copy a pattern onto an empty pad (if P2 offers it). | The pad gets a new number with the same notes; a strip names both numbers. | – | ☐ pass ☐ fail: |

**Not covered here:**

- Which saved project holds a pattern: not built (the board shows a dot only). The dot can be on for the loaded
  music's own saved copy.
- How long the pictures take over the Pixel's USB: not measured. If check 2 takes much longer than five seconds,
  note the time.
- The sheet's look, TalkBack: P2's check and the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
