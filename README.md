# Lupe (fm1-ipad)

An iPad and iPhone app for the M-VAVE FM-1 running [SLOOP](https://github.com/isod89/sloop-fm1). The two work as one instrument. The FM-1 makes the sound, stores the patterns and plays them. The iPad is a bigger window onto it: it shows all four tracks, edits them, shapes sounds, records samples, and arranges sections into songs. On an iPhone (landscape) the same jobs come one at a time.

**To try it, start with [TESTING.md](TESTING.md).**

## Layout

| Path | What |
|---|---|
| `ios/` | The app for iPad and iPhone (SwiftUI, CoreMIDI) and `SloopKit`, the Swift package that speaks to the FM-1. See `ios/README.md` |
| `sloop/` | SLOOP 2.8.4 with the screen-link patch: the patch, the built firmware package, and how to build it |
| `vendor/sloop-2.8.4/` | Stock SLOOP 2.8.4, pinned: firmware, web editor, and the editor protocol the app is written from |
| `protocol/` | Which of SLOOP's editor commands the app uses |
| `tokens/` | `tokens.json`: SLOOP's track and knob colours, and the app's surfaces |
| `qa/` | The test plan and the last pass |
| `tools/` | Small Mac command-line probes for the FM-1's MIDI |
| `design/` | The app icon |

An earlier plan replaced the FM-1's firmware with my own fork of M-VAVE's FM1 Open. It's archived at the tag `archive/fm1-open-firmware` and the `slice-1-link` branch.

## Licence

GPL-3.0 (see `LICENSE`), the same as SLOOP. The app contains no SLOOP code: it's written from SLOOP's published editor protocol. The SLOOP patch and the firmware package in `sloop/` are GPL-3.0 as SLOOP's derivatives. The files in `vendor/sloop-2.8.4/` are SLOOP's, under its own `LICENSE` and `LICENSING.md`.
