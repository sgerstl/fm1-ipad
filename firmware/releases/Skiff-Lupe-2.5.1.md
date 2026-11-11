# Skiff-Lupe 2.5.1

Skiff 2.5.1 with Lupe's screen link, for the M-VAVE FM-1. Everything else is Skiff 2.5.1 as released.

- **Skiff** is by illuminus5 (<https://github.com/illuminus5/skiff>), a fork of **Felucca** by Leo Kuroshita, Hügelton Instruments (<https://github.com/hugelton/Felucca>). All credit for the firmware is theirs.
- **Lupe adds** the screen link only, rebased from 2.2 onto Skiff `v2.5.1`: SCREEN, SCREEN_GOTO, the step cursor, METER and SCOPE in `editor.c`, with `ui_scope.c` and small hooks in `ui.c` and `ui_graph.c` (about 320 lines of firmware; the rest of the diff is tests and the protocol doc). The screen link's bytes are unchanged from 2.2 (INFO tag `56 01 06`). Skiff 2.5's page table numbers its pages differently, and Lupe translates (`SkiffPageMap`).
- **Licence:** GPL-3.0-only, as Skiff. Complete corresponding source: <https://github.com/sgerstl/skiff>, branch `lupe-skiff-2.5.1-screen-link` at `737e3fb` (Skiff `v2.5.1`, `fe38723`, plus seven commits). Once Scott accepts the build it is tagged `lupe-skiff-2.5.1-screen-link.1`, following 2.2.
- **File:** `Skiff-Lupe-2.5.1.fwsc`, 610,429 bytes, SHA-256 `80b21b33d05ccaa384636261e229eb94efdac847c93cc1f534d69082ff71302c`. Identity `FM-1_725`, the same as upstream Skiff 2.5 and 2.5.1 (decided 2026-11-11, as 2.2 kept `FM-1_722`). INFO reports `FELUCCA v2.5.1` with the screen link tag `56 01 06`.
- **Built** 2026-11-11 with `FELUCCA_CDC=0 venv/bin/python tools/build.py --release 2.5.1` (Python 3.12 venv; `build.sh` loses Homebrew's libraqm under SIP). Skiff's build isn't byte-for-byte reproducible, so the pin is this file's.
- **Flash:** the release build fits with 3,204 bytes to spare (578,360 of the 581,564-byte XIP region). **A development build with the USB serial console (MENU › USB SERIAL) does not fit**: it overflows the XIP region by 92 bytes. A console build of Skiff-Lupe for debugging needs about 100 bytes taken out of the screen link or elsewhere first. Any later screen-link feature has to fit in the 3.2 KB left.
- **Tests:** Skiff's host tests all pass on this branch, the screen link's `editor_test.c` included (vault `skiff-2.5.1-rebase.md`). Nothing has run on an FM-1 yet.

What changes for Lupe on 2.5.1: FX › DELAY and FX › REVERB pages, the INSERT's FILTR type, SCL › CHORD's STRUM and DIR, GLO › DELAY's MODE, MENU › CONTROL › KEEP SENDS, FREE TAKE, an undo of 6 levels (was 8), and every FM-1 moving to CPU 2 CORES once. Projects saved on 2.2 open with the delay on MONO, as they played.

Lupe downloads this file from its GitHub release (`lupe-firmware-2`, made when the build is accepted) when you choose Skiff-Lupe 2.5.1, checks the SHA-256, and only then installs it. In a Debug build it uses this copy. Please report problems with the screen link to Lupe (<https://github.com/sgerstl/fm1-ipad/issues>), not to Skiff.
