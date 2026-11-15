# Skiff-Lupe 2.5.1

Skiff 2.5.1 with Lupe's screen link and steady USB audio, for the M-VAVE FM-1. Everything else is Skiff 2.5.1 as released.

- **Skiff** is by illuminus5 (<https://github.com/illuminus5/skiff>), a fork of **Felucca** by Leo Kuroshita, Hügelton Instruments (<https://github.com/hugelton/Felucca>). All credit for the firmware is theirs.
- **Lupe adds** the screen link only, rebased from 2.2 onto Skiff `v2.5.1`: SCREEN, SCREEN_GOTO, the step cursor, METER and SCOPE in `editor.c`, with `ui_scope.c` and small hooks in `ui.c` and `ui_graph.c` (about 320 lines of firmware; the rest of the diff is tests and the protocol doc). The screen link's bytes are unchanged from 2.2 (INFO tag `56 01 06`). Skiff 2.5's page table numbers its pages differently, and Lupe translates (`SkiffPageMap`).
- **Steady USB audio (B1, 2026-11-15):** at 48 kHz every USB audio packet carries exactly 48 frames. The ring takes up the I2S clock's offset (about +420 ppm), held by a slip in `uac_tap48`'s own resampler (the phase steps 148 instead of 147 for 148 outputs: one frame fewer, nothing interpolated). Hosts that take a fixed 48 frames a millisecond had nothing to absorb the old ±1 packets with: Android's USB capture on Pixels filled the gaps with silence (a crackle, worst with FM6). 44.1 kHz is unchanged. `usb.c` behind `FELUCCA_UAC_STEADY` (1), 72 bytes of flash, 16 of RAM. Details: `firmware/proposals/2026-11-15-b1-steady-usb-audio.md`.
- **Licence:** GPL-3.0-only, as Skiff. Complete corresponding source: <https://github.com/sgerstl/skiff>, branch `lupe-skiff-2.5.1-screen-link` at `72d4170` (Skiff `v2.5.1`, `fe38723`, plus seven screen-link commits and B1). **Not pushed yet**: it goes up before this build is distributed. Once Scott accepts the build it is tagged `lupe-skiff-2.5.1-screen-link.1`, following 2.2.
- **File:** `Skiff-Lupe-2.5.1.fwsc`, 610,429 bytes, SHA-256 `2cb940c71557049ba3c46f11d35311b1e69e81d1f9348d9e0b906ec82847383b` (with B1; the build before it, `80b21b33…f71302c`, was never released). Identity `FM-1_725`, the same as upstream Skiff 2.5 and 2.5.1 (decided 2026-11-11, as 2.2 kept `FM-1_722`). INFO reports `FELUCCA v2.5.1` with the screen link tag `56 01 06`.
- **Built** 2026-11-15 with `venv/bin/python tools/build.py --release 2.5.1` from the B1 tree (Python 3.12 venv; `build.sh` loses Homebrew's libraqm under SIP). Skiff's build isn't byte-for-byte reproducible, so the pin is this file's: the one that was tested on the FM-1.
- **Flash:** the release build fits with 3,132 bytes to spare (578,432 of the 581,564-byte XIP region; B1 added 72). **A development build with the USB serial console (MENU › USB SERIAL) does not fit**: it overflows the XIP region by 92 bytes. A console build of Skiff-Lupe for debugging needs about 100 bytes taken out of the screen link or elsewhere first. Any later screen-link feature has to fit in the 3.2 KB left.
- **Tests:** Skiff's host tests pass on this branch, the screen link's `editor_test.c` included, and `uac_test` three ways (steady with and without CDC, the band rule). The exceptions are known: two `web/test_web.mjs` checks need Node 20+ and the image has Node 18, and ThreadSanitizer won't start under amd64 emulation on Apple silicon.
- **On the FM-1 (2026-11-15), this exact file:**
  - installed with `tools/fm1fw` after a backup;
  - Pixel 7 and Pixel 10: 0 USB dejitter underruns and 0 gaps with FM6 playing, 16–17 ms through Lupe;
  - the Mac: the FM-1's rate −26 ppm;
  - Scott: the crunch is "Gone", "Clean".
  - Still to check: the Mac with sound, 44.1 kHz, and the iPad (screen link, MIDI, projects).

What changes for Lupe on 2.5.1: FX › DELAY and FX › REVERB pages, the INSERT's FILTR type, SCL › CHORD's STRUM and DIR, GLO › DELAY's MODE, MENU › CONTROL › KEEP SENDS, FREE TAKE, an undo of 6 levels (was 8), and every FM-1 moving to CPU 2 CORES once. Projects saved on 2.2 open with the delay on MONO, as they played.

Lupe downloads this file from its GitHub release (`lupe-firmware-2`, made when the build is accepted) when you choose Skiff-Lupe 2.5.1, checks the SHA-256, and only then installs it. In a Debug build it uses this copy. Please report problems with the screen link to Lupe (<https://github.com/sgerstl/fm1-ipad/issues>), not to Skiff.
