# Device check: bluetooth-poc, 2026-11-10

Written by the overnight session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; nothing here merges anywhere until it passes. Notes: `~/vaults/Panopticon/Projects/Dev/fm1-ipad/bluetooth-poc.md`.

**Setup:**
- Firmware: **Skiff-Lupe Bluetooth test build**, `~/code/skiff-bluetooth-poc/build/skiff-lupe-bluetooth-poc.fwsc` (branch `bluetooth-poc` of skiff-src; SHA-256 in the vault note). It's Skiff 2.2 + the screen link + Bluetooth, with **every theme on the pixel faces** (Barlow is gone to make room). Identity FM-1_700, version v2.2, as the screen-link build.
- Install it over USB from the Mac (Lupe's installer only takes its pinned releases): `python3 tools/fm1_install.py build/skiff-lupe-bluetooth-poc.fwsc` from `~/code/skiff-bluetooth-poc` (needs mido + python-rtmidi).
- Lupe: branch `bluetooth-poc` (worktree `~/code/fm1-ipad-bluetooth-poc`), a Debug build on the iPad. The first time it opens the Bluetooth list, iOS asks for Bluetooth permission: allow it.
- USB-C cable for the install and check 9; headphones for check 8.
- On the FM-1: MENU › SYSTEM › CPU at **1 CORE** and CPU CLOCK at **360 MHZ** (the radio refuses to start otherwise in this build, on purpose).

**Back up first?** **Yes, before the install.** The install writes the app area. The new firmware reads the settings and projects the same way, but it also saves the Bluetooth address and pairing into the settings record. Back up with Lupe › Projects (or Skiff's editor backup) over USB, with the screen-link firmware still on.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Back up (above), then install the test build over USB. Let the FM-1 restart. | It boots to HOME. Text everywhere is the pixel face. Lupe still connects over USB as before. | yes, first | ☐ pass ☐ fail: |
| 2 | On the FM-1: MENU › SYSTEM › BLUETOOTH, turn it ON. Read the row. | **ON** (the radio started). **ON: NO CAL** means the FM-1's stock radio calibration is gone (Skiff's pattern bank may have written over it at 0xE8000): stop here, the rest can't run; note it. **ON: 1 CORE** / **ON: 360 MHZ**: fix the CPU settings, restart. Optional, over USB serial: type `ble` and copy the lines (vm_area, vm_have, rf_src, crumb). | – | ☐ pass ☐ fail: |
| 3 | Unplug USB. In Lupe tap the top-left FM-1 dot › **Connect over Bluetooth…**. | Apple's list finds **FM1-xxxx**. Tap it: it says Connected. If iOS asks to pair, accept (no code: Just Works). Tap Done. | – | ☐ pass ☐ fail: |
| 4 | Wait for Lupe to connect. Time it from Done. | The dot goes live; the menu says "FM-1 on Bluetooth" and the note "Some features need USB: …". The song and tracks read correctly. Expect it slow: about 15–30 s (Lupe reads ~545 things at connect). Write the time down. | – | ☐ pass ☐ fail: s |
| 5 | Turn KNOB 1 on the FM-1 on a page whose values Lupe shows (a track's EDIT page). | The value moves on the iPad. Note how far behind it feels. | – | ☐ pass ☐ fail: |
| 6 | Tap a pad in Lupe's Pads view (stopped, then playing). | The FM-1 switches to that entry, as over USB. | – | ☐ pass ☐ fail: |
| 7 | On the FM-1 change page (press a page button, then another). | Lupe follows the page and cursor (screen link). No scope or levels are shown, by design. How laggy, 0–3 (0 = like USB). | – | ☐ pass ☐ fail: lag |
| 8 | Play a busy song for a minute with headphones on, Bluetooth connected, Lupe open; tap through tabs. | No dropouts, clicks or stuck notes. Play a few keys on Lupe's keyboard: they sound. | – | ☐ pass ☐ fail: |
| 9 | Plug USB back in, Bluetooth still connected. | Lupe switches to USB within a few seconds (the menu says "FM-1 over USB"; levels come back on the mixer). | – | ☐ pass ☐ fail: |
| 10 | Turn the FM-1 off and on (BLUETOOTH stays ON). Unplug USB; in Lupe open Connect over Bluetooth… and connect FM1-xxxx again. | Same name; it reconnects without asking to pair again (the bond was kept). | – | ☐ pass ☐ fail: |
| 11 | MENU › SYSTEM › BLUETOOTH OFF. | Lupe loses the FM-1 within a few seconds (when its next ping goes unanswered); nothing keeps sounding. | – | ☐ pass ☐ fail: |

**Going back:** install the screen-link Skiff-Lupe from Lupe's Install firmware over USB, as usual. Firmware installs never go over Bluetooth (Lupe refuses them there).

**Not covered here:** VoiceOver on the new menu row and sheet (release pass); the iPhone; Bluetooth with CPU 2 CORES or 320 MHz (deliberately refused in this build); a sample upload attempted over Bluetooth (Lupe refuses it with "SAMPLES GO OVER USB"); long-session stability beyond a minute; the radio's range.

**After the run:** failures go on the batch list (item 7) with the check number. If check 2 says NO CAL, that's the main finding: the calibration has to come from somewhere (a flash backup taken on stock firmware, or a way to recalibrate) before Bluetooth can work on this unit.
