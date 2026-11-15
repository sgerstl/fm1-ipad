# Lupe (fm1-ipad)

An iPad and iPhone app for the M-VAVE FM-1 running [Skiff](https://github.com/illuminus5/skiff) (Skiff-Lupe: Skiff with Lupe's screen link, which the app installs). The two work as one instrument. The FM-1 makes the sound, stores the patterns and plays them. The iPad is a bigger window onto it: it shows all six tracks, edits them, shapes sounds, records samples, and arranges each track's patterns into a song. On an iPhone the same jobs come one at a time.

Lupe began on [SLOOP](https://github.com/isod89/sloop-fm1) and spoke both firmwares until 2026-11-15, when it became Skiff-only (decision 43). The last SLOOP state is the tag `sloop-archive-2026-11-15`; `design/archive/sloop.md` lists what went.

**To try it, start with [TESTING.md](TESTING.md).**

## Layout

| Path | What |
|---|---|
| `ios/` | The app for iPad and iPhone (SwiftUI, CoreMIDI) and `SloopKit`, the Swift package that speaks to the FM-1. See `ios/README.md` |
| `skiff/` | Skiff's screen-link patch and how the Skiff-Lupe packages are built |
| `firmware/releases/` | The Skiff-Lupe packages Lupe downloads, with their notes (`FIRMWARE.md`) |
| `sloop/` | History: SLOOP 2.8.4's screen-link patch (Lupe no longer speaks SLOOP) |
| `vendor/sloop-2.8.4/` | History: stock SLOOP 2.8.4 and its editor protocol, where the app's framing and shared commands come from |
| `protocol/` | The editor commands the app uses |
| `tokens/` | `tokens.json`: the track and knob colours, and the app's surfaces |
| `qa/` | The test plan and the last pass |
| `tools/` | Small Mac command-line probes for the FM-1's MIDI |
| `design/` | The app icon |

An earlier plan replaced the FM-1's firmware with my own fork of M-VAVE's FM1 Open. It's archived at the tag `archive/fm1-open-firmware` and the `slice-1-link` branch.

## Licence

GPL-3.0 (see `LICENSE`), the same as Skiff and SLOOP. The app contains no firmware code: it's written from the firmwares' published editor protocols. The screen-link patches in `skiff/` and `sloop/` and the firmware packages are GPL-3.0 as derivatives. The files in `vendor/sloop-2.8.4/` are SLOOP's, under its own `LICENSE` and `LICENSING.md`.
