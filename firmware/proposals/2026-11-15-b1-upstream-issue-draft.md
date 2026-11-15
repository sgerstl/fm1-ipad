---
title: "Draft for Scott: B1 as an issue on illuminus5/skiff"
status: "draft, not sent"
---

*For Scott to send, or not. It's public once posted. The plan, the order relative to the Lupe note, and what changes for the PR are in `2026-11-15-b1-release-plan.md` §4. Fill in the branch link once a branch is pushed. Add your contact line if you want one; it's left out here.*

**Title:** Feature idea: exactly 48 frames in every 48 kHz USB audio packet (fixes crackle on Android)

Skiff's USB audio crackles on the two Android phones I tried, a Pixel 7 and a Pixel 10. The same stream records clean on a Mac. It's worst with FM6 pads, which took me a while to connect to anything.

It comes down to packet sizes. At 48 kHz, `uac_packet` sends 48 frames, one more or one fewer while `fill_min` sits outside 87..139. When renders run late, the band rule sends runs of 47s and 49s. In `tests/uac_test.c` with random render times, that's 336 short and 530 long packets in 10 seconds. As far as I can tell from its log, a Pixel's USB capture takes a fixed 48 frames every millisecond and keeps only 16 in hand. A run of short packets empties that, and the phone fills the hole with silence. The log line is `USB RX Dejitter underrun`, about 14 a second on the Pixel 7.

I changed it so every 48 kHz packet carries exactly 48 frames. The ring takes up the I2S clock's offset of about +420 ppm. When its filtered fill drifts, `uac_tap48` steps its phase by 148 instead of 147 for 148 outputs, which makes one frame fewer (146 makes one more). Every output is still the FIR at an exact phase, so nothing is interpolated. 44.1 kHz is unchanged.

On my FM-1, with FM6 pads playing for a minute, the dejitter lines dropped to zero on both phones.

Happy to open a PR against `main`, or send it over however you'd prefer.

Thanks for Skiff.

**Details**

- About 20 slips a second at +420 ppm, spaced evenly by an accumulator, never in runs
- `FELUCCA_UAC_STEADY`, default 1. Setting it to 0 keeps the band rule, and `run_tests.sh` builds `uac_test` both ways
- `uac_test` traces each output's phase and checks every frame against the double-precision resampler at that phase. It also checks that every packet is 48 and that slips match the clock. Renders alternating 7 % and 85 % of a half cause no underrun or overrun
- Release build: 72 bytes more flash, 16 bytes more RAM
- Applies cleanly to `main` (2.6), where the `uac_test` builds pass
- Branch: (link)
