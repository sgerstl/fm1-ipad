# Protocol

The app speaks **SLOOP's own editor protocol**: SysEx `F0 7D 46 4C <cmd> ... F7` over USB MIDI. The reference is pinned in `vendor/sloop-2.8.4/EDITOR_PROTOCOL.md`; there is no protocol of my own. The one firmware change is the screen link (`sloop/`): two commands, 90 UI and 91 UI_GOTO, which the app uses when the FM-1 answers them and does without when it doesn't.

What pass 1 uses:

| Command | Use |
|---|---|
| `INFO` (1) | Version check: must be `FELUCCA SLOOP 2.8.4`, protocol 12 |
| `TRACK` (27) | Each track's engine and preset, the selected track |
| `NAMES` (10) | Preset names per engine |
| `TRACK_STEP` (30) | Synth steps of any track |
| `DRUM_STEP` (33) | The drum track's 16 lanes per step |
| `TRACK_PARAM` (31), `GET` (2) | Knob values (level, length, pan, scale; global swing) |
| `WATCH 3` (22), `PING` (25) | Pushes: `CHANGED`, `RELOAD`, `STEP_CHANGED`, `TRACK_CHANGED` |
| `LIVE` op 0 (77) | Playing, BPM, selection, each track's step and length, polled 20+ times a second |

**With the screen link firmware** (`sloop/`: SLOOP 2.8.4 plus 47 lines), two more: `UI` (90) reports the FM-1's page, layer and menu, and is pushed whenever they change (`WATCH 7`); `UI_GOTO` (91) opens a page. The app asks `UI` at connect and uses the link only when the FM-1 answers.

The Swift package lives in `ios/SloopKit`: frame encoding and decoding, typed replies, tests against captured traffic in `ios/SloopKit/Tests/SloopKitTests/Fixtures`.

The earlier custom protocol (`F0 7D 'F' 'I' ...`) is archived on the `slice-1-link` branch.
