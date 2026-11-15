# Device check: claude/iphone-consolidation-6090a2, 2026-11-15 (SLOOP removed, decision 43)

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; the branch merges to `main` only after it passes.

**Setup:** FM-1 on Skiff-Lupe 2.2 or 2.5.1 · Lupe from this branch (its last commit) on the iPad and the iPhone · USB-C straight in.
**Back up first?** Only for check 6, which puts SLOOP on the FM-1 (outside Lupe) and Skiff-Lupe back on. Back up in Lupe first (FM-1 menu › Projects…, Save as…), and skip check 6 unless you want to see the SLOOP offer on the device.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Plug the FM-1 into the iPad and open Lupe | It connects as before: Song · Mix, six tracks, the screen link following the FM-1's buttons | – | ☐ pass ☐ fail: |
| 2 | Tap the FM-1 key (top left) | The source group reads "FM-1 over USB" and "Demo" (no "Skiff demo" / "SLOOP demo"); pick Demo, then FM-1 over USB again | – | ☐ pass ☐ fail: |
| 3 | FM-1 menu › Projects…; open a row's ⋯ | Rows show "Saved … · n patterns"; the menu has Rename, Duplicate, Delete (no Export…); the footer talks about the pool and the FM-1 stopping | – | ☐ pass ☐ fail: |
| 4 | Select a DRUM track, open the keyboard drawer, play the white keys | The lanes sound; the black keys are silent; no "GLO > MIDI > OTHER" warning | – | ☐ pass ☐ fail: |
| 5 | Install firmware… (iPad) / FM-1 firmware… (iPhone) | The choices are the Skiff-Lupe builds and, under Back to stock, Stock V15. No SLOOP-Lupe | – | ☐ pass ☐ fail: |
| 6 | (Optional) Put SLOOP 2.8.4 on with SLOOP's own installer, then plug the FM-1 into Lupe | It doesn't connect. iPad: the card "Lupe needs Skiff-Lupe" naming SLOOP 2.8.4, with the line about OLD FORMAT and SLOOP's own backup. iPhone: the fork offer for SLOOP 2.8.4. Then install Skiff-Lupe from the card and restore your project | Yes | ☐ pass ☐ fail: |

**Not covered here:** VoiceOver on the changed cards (release pass); the simulator-only firmware demos (`-demo -demo-firmware fork-sloop` shows check 6's phone card without a device).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
