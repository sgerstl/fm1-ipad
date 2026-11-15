# Device check: claude/android-p1-core-link-faf639, 2026-11-15 (installing Skiff-Lupe from the phone: the core's side)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

The phone can now offer and install the firmware it needs (Skiff-Lupe 2.5.1), using the same installer code as the
iPad. This has only run against a fake FM-1. **No install has been run on a real FM-1 from Android, and none
from Lupe at all yet** (`FIRMWARE.md`, "Tested"). P2 draws the offer and the install screen.

**Do checks 1–3 first. They write nothing to the FM-1.** Checks 4–6 install firmware: run them only when Scott
has decided to, with the FM-1 on a cable that won't be knocked, and the phone above 30 % or charging.

**Setup:** Pixel on this branch merged into the combined one. Internet on the phone for check 4.

**Back up first: yes, before check 4.** An install rewrites the FM-1's firmware. Lupe takes its own backup first
when the FM-1 is connected (check 4 looks for the file), but for the first real install also back up with Skiff's
own web editor.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Plug in the FM-1 as it is now and open the link debug screen. | A line `open: "…" (the editor's)` with the FM-1's USB name, and Lupe connects as before. No USB permission question. | – | ☐ pass ☐ fail: |
| 2 | Read the `firmware` area on the debug screen. | `running` names the firmware on the FM-1. On Skiff-Lupe 2.5.1 there is no `offer`; on Skiff 2.2 the offer is `update` for Skiff-Lupe 2.5.1. `state` is idle. | – | ☐ pass ☐ fail: |
| 3 | Plug in any other USB MIDI device (a keyboard). | Lupe doesn't connect to it as an FM-1. If its name matches the filter, the log shows it opened as "not an editor firmware", and nothing is offered. | – | ☐ pass ☐ fail: |
| 4 | **Installs firmware.** With an offer showing, start the install and confirm. | Download (a few seconds), "Backing up", "Checking the firmware file", then the FM-1's screen goes to its update mode, "Writing" runs to 100 %, the FM-1 restarts, and the phone says Skiff-Lupe 2.5.1 is installed. No USB permission question when it comes back as "Felucca Update". Lupe reconnects by itself. | Yes | ☐ pass ☐ fail: |
| 5 | After check 4, look in the app's storage (or the share action P2 gives the backup). | A backup file from before the install, named with the date and the old version. | – | ☐ pass ☐ fail: |
| 6 | **Installs firmware; only if Scott wants to test a cut.** Start an install and pull the cable during "Writing", then plug it back within two minutes. | The phone says it is waiting for the FM-1, then writes again and finishes. If left unplugged longer, it fails with "install again to finish it", and the next plug-in offers "Finish the firmware install". | Yes | ☐ pass ☐ fail: |

**Not covered here:**

- Skiff-Lupe 2.5.1 isn't published yet as the `lupe-firmware-2` release the phone downloads from (the iPhone
  session, 2026-11-15). Until it is, check 4 fails at the download with GitHub's error and nothing reaches the
  FM-1. To run check 4 before then, copy `firmware/releases/Skiff-Lupe-2.5.1.fwsc` into the app's files as
  `DebugFirmware/Skiff-Lupe-2.5.1.fwsc`; the app still refuses it unless it is exactly the pinned file.
- A stock FM-1 (M-VAVE's firmware): Scott's unit runs Skiff, so the stock offer is tested only against the fake. The
  stock firmware's USB name on Android isn't known.
- Stock V15 from the phone: not offered.
- Keeping the screen on and the app in front during the write: P2's side. If Android stops the app mid-write, the
  FM-1 waits in update mode and the next start offers to finish.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
