# SLOOP-Lupe 2.8.4

SLOOP 2.8.4 with Lupe's screen link, for the M-VAVE FM-1. Everything else is SLOOP 2.8.4 as released.

- **SLOOP** (<https://github.com/isod89/sloop-fm1>) is a Felucca fork; Felucca is by Leo Kuroshita, Hügelton Instruments (<https://github.com/hugelton/Felucca>). All credit for the firmware is theirs.
- **Lupe adds** the screen link only: 47 lines in `firmware/src/editor.c` so Lupe and the FM-1 follow each other's screen (`sloop/0001-screen-link.patch`, `sloop/README.md`).
- **Licence:** GPL-3.0, as SLOOP. Complete corresponding source: SLOOP tag `v2.8.4` plus `sloop/0001-screen-link.patch` in this repository.
- **File:** `SLOOP-Lupe-2.8.4.fwsc`, 610,052 bytes, SHA-256 `97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110`. Identity `FM-1_900`; INFO reports `FELUCCA SLOOP 2.8.4`, protocol 12.
- **Not for FM-1s that run stock V16:** SLOOP 2.8.4's update loader doesn't know their newer flash chip. Lupe offers Skiff-Lupe there instead.

Lupe downloads this file from its GitHub release when you choose SLOOP-Lupe, checks the SHA-256, and only then installs it. Please report problems with the screen link to Lupe (<https://github.com/sgerstl/fm1-ipad/issues>), not to SLOOP.
