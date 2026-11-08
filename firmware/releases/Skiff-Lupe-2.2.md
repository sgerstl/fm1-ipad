# Skiff-Lupe 2.2

Skiff 2.2 with Lupe's screen link, for the M-VAVE FM-1. Everything else is Skiff 2.2 as released.

- **Skiff** is by illuminus5 (<https://github.com/illuminus5/skiff>), a fork of **Felucca** by Leo Kuroshita, Hügelton Instruments (<https://github.com/hugelton/Felucca>). All credit for the firmware is theirs.
- **Lupe adds** the screen link only: about 130 lines in `editor.c` so Lupe and the FM-1 follow each other's screen, the step cursor, the track levels and the scope (`skiff/0001-screen-link.patch`, `skiff/README.md`).
- **Licence:** GPL-3.0-only, as Skiff. Complete corresponding source: <https://github.com/sgerstl/skiff>, tag `lupe-skiff-2.2-screen-link.6` (Skiff `v2.2` plus the patch).
- **File:** `Skiff-Lupe-2.2.fwsc`, 610,429 bytes, SHA-256 `77d4bdff4b4452b4891b4a4fcbfd918e5b1c623a79c6cb399511fdb05d1c06e6`. Identity `FM-1_722`; INFO reports `FELUCCA v2.2` with the screen link tag `56 01 06`.
- **Built** 2026-11-07 with `./build.sh --release 2.2`; Skiff's build isn't byte-for-byte reproducible, so the pin is this file's.

Lupe downloads this file from its GitHub release when you choose Skiff-Lupe, checks the SHA-256, and only then installs it. Please report problems with the screen link to Lupe (<https://github.com/sgerstl/fm1-ipad/issues>), not to Skiff.
