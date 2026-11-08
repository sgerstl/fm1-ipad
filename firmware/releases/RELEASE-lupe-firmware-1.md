Firmware for Lupe, the iPad editor for the M-VAVE FM-1. Lupe downloads these when you choose one in Install firmware, checks the SHA-256 below, and only then installs. Each is the original firmware plus Lupe's screen link and nothing else; all credit for the firmware goes to its authors.

## Skiff-Lupe 2.2

Skiff 2.2 with Lupe's screen link, for the M-VAVE FM-1. Everything else is Skiff 2.2 as released.

- **Skiff** is by illuminus5 (<https://github.com/illuminus5/skiff>), a fork of **Felucca** by Leo Kuroshita, Hügelton Instruments (<https://github.com/hugelton/Felucca>). All credit for the firmware is theirs.
- **Lupe adds** the screen link only: about 130 lines in `editor.c` so Lupe and the FM-1 follow each other's screen, the step cursor, the track levels and the scope (`skiff/0001-screen-link.patch`, `skiff/README.md`).
- **Licence:** GPL-3.0-only, as Skiff. Complete corresponding source: <https://github.com/sgerstl/skiff>, tag `lupe-skiff-2.2-screen-link.6` (Skiff `v2.2` plus the patch).
- **File:** `Skiff-Lupe-2.2.fwsc`, 610,429 bytes, SHA-256 `77d4bdff4b4452b4891b4a4fcbfd918e5b1c623a79c6cb399511fdb05d1c06e6`. Identity `FM-1_722`; INFO reports `FELUCCA v2.2` with the screen link tag `56 01 06`.
- **Built** 2026-11-07 with `./build.sh --release 2.2`; Skiff's build isn't byte-for-byte reproducible, so the pin is this file's.

Lupe downloads this file from its GitHub release when you choose Skiff-Lupe, checks the SHA-256, and only then installs it. Please report problems with the screen link to Lupe (<https://github.com/sgerstl/fm1-ipad/issues>), not to Skiff.

## SLOOP-Lupe 2.8.4

SLOOP 2.8.4 with Lupe's screen link, for the M-VAVE FM-1. Everything else is SLOOP 2.8.4 as released.

- **SLOOP** is by isod89 (<https://github.com/isod89/sloop-fm1>), a fork of Felucca; Felucca is by Leo Kuroshita, Hügelton Instruments (<https://github.com/hugelton/Felucca>). All credit for the firmware is theirs.
- **Lupe adds** the screen link only: 47 lines in `firmware/src/editor.c` so Lupe and the FM-1 follow each other's screen (`sloop/0001-screen-link.patch`, `sloop/README.md`).
- **Licence:** GPL-3.0, as SLOOP. Complete corresponding source: SLOOP tag `v2.8.4` plus `sloop/0001-screen-link.patch` in this repository, also as the branch `fm1-ipad-screen-link` of <https://github.com/sgerstl/sloop-fm1>.
- **File:** `SLOOP-Lupe-2.8.4.fwsc`, 610,052 bytes, SHA-256 `97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110`. Identity `FM-1_900`; INFO reports `FELUCCA SLOOP 2.8.4`, protocol 12.
- **Not for FM-1s that run stock V16:** SLOOP 2.8.4's update loader doesn't know their newer flash chip. Lupe offers Skiff-Lupe there instead.

Lupe downloads this file from its GitHub release when you choose SLOOP-Lupe, checks the SHA-256, and only then installs it. Please report problems with the screen link to Lupe (<https://github.com/sgerstl/fm1-ipad/issues>), not to SLOOP.
