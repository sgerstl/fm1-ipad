# tools

Small Swift command-line probes for talking to the FM-1 over USB MIDI from a Mac. Written 2026-10-31.

Build: `swiftc -O <file>.swift -o <name>` (deprecation warnings from the legacy CoreMIDI calls are expected).

## sloopprobe.swift

Speaks SLOOP's editor protocol (SysEx `F0 7D 46 4C <cmd> ... F7`, see SLOOP's `web/EDITOR_PROTOCOL.md`). Uses the first MIDI source and destination, so plug in only the FM-1.

- `sloopprobe info`: version, tracks, preset names, the first 16 steps of each synth track, the drum grid, the live state.
- `sloopprobe watch <secs>`: turns on pushes (`WATCH 3`) and prints them, polling `LIVE` four times a second.
- `sloopprobe steps <secs> [pollHz]`: snapshots all 256 steps, prints pushes while you edit, then diffs. With `pollHz` it also polls the playhead and counts skipped steps.
- `sloopprobe misc`: names two parameters with `DESC` and times 50 `LIVE` round trips.

## skiffprobe.swift

Speaks Skiff's editor protocol (Felucca's command numbers, not SLOOP's; Skiff's `web/EDITOR_PROTOCOL.md`), on an FM-1 running Skiff or on `skiff-sim`. Finds the port by name: skiff-sim's first, then any "Felucca".

- `skiffprobe info`: INFO with its capability tags, TRACK, a few DESC names, TRANSPORT, and 50 TRANSPORT round trips timed.
- `skiffprobe desc`: every track and global parameter's DESC (label, range or enum names). The knob map for a Skiff driver.
- `skiffprobe seed`: writes a test pattern on T1 (C4 every fourth step).
- `skiffprobe clock <secs>`: PLAY, counts clock ticks, Start / Stop and note-ons per channel, then STOP.

## midilisten.swift

`midilisten <secs>`: prints every incoming MIDI message as UMP words and counts clock ticks. Used to see what stock V15 and FM1 Open send.

## sloopcapture.swift

`sloopcapture <out.jsonl> [watchSecs]`: records SLOOP traffic as test fixtures for `ios/SloopKit`. Sends every read pass 1 makes (INFO, TRACK, NAMES for all engines, all 256 steps, the knob parameters, DESC of the scale, LIVE), then `WATCH 3` for `watchSecs` while you play, with PING once a second and LIVE 20 times a second. One JSON object per frame: `{"t", "dir": "tx" | "rx", "hex"}`. Close SLOOP's web editor first unless you want its traffic in the capture (`live-1.jsonl` has some, on purpose).
