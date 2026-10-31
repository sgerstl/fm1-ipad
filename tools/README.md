# tools

Small Swift command-line probes for talking to the FM-1 over USB MIDI from a Mac. Written 2026-10-31.

Build: `swiftc -O <file>.swift -o <name>` (deprecation warnings from the legacy CoreMIDI calls are expected).

## sloopprobe.swift

Speaks SLOOP's editor protocol (SysEx `F0 7D 46 4C <cmd> ... F7`, see SLOOP's `web/EDITOR_PROTOCOL.md`). Uses the first MIDI source and destination, so plug in only the FM-1.

- `sloopprobe info`: version, tracks, preset names, the first 16 steps of each synth track, the drum grid, the live state.
- `sloopprobe watch <secs>`: turns on pushes (`WATCH 3`) and prints them, polling `LIVE` four times a second.
- `sloopprobe steps <secs> [pollHz]`: snapshots all 256 steps, prints pushes while you edit, then diffs. With `pollHz` it also polls the playhead and counts skipped steps.
- `sloopprobe misc`: names two parameters with `DESC` and times 50 `LIVE` round trips.

## midilisten.swift

`midilisten <secs>`: prints every incoming MIDI message as UMP words and counts clock ticks. Used to see what stock V15 and FM1 Open send.
