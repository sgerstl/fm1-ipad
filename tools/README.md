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
- `skiffprobe playhead [secs] [scenario ...]`: can a playhead counted from MIDI clock follow Skiff's sequencer? For each scenario (default all, 8 s each: `a90 a150 b90 b137 swing nudge rand len div launch tempo slower`) it sets BPM, SWING+ and each track's LENGTH / DIV / DIR / SWING with `TRACK_PARAM` (31; ids from 128 by the wide-id rule), reads them back, writes a distinct note on every step of every track (36 + step, `TRACK_STEP` 30) and turns DRUM / DRUM-X tracks into ANALOG so their notes are the steps'. Then PLAY, count ticks from Start, and check each note-on against two predictions: *naive* (`floor(ticks / T)` folded by DIR) and *model* (the steps walked as `seq.c` walks them: swing by position, LEN / DIV changes at the next step, a LIST launch at the next bar, the BPM-change shift). Prints per track the match rate of both, the worst drift in ticks, and, when skiff-sim runs with `--truth`, how the sequencer's own step agrees. Overwrites the tracks' steps, LENGTH, DIV, DIR and SWING (and T1's list in `launch`), so use the sim or a scratch project. `PLAYHEAD_DEBUG=1` prints T1's notes and truth around a mid-run change. Results: the vault's `Projects/Dev/fm1-ipad/skiff-plan.md`, "Phase 1 result".

## midilisten.swift

`midilisten <secs>`: prints every incoming MIDI message as UMP words and counts clock ticks. Used to see what stock V15 and FM1 Open send.

## sloopcapture.swift

`sloopcapture <out.jsonl> [watchSecs]`: records SLOOP traffic as test fixtures for `ios/SloopKit`. Sends every read pass 1 makes (INFO, TRACK, NAMES for all engines, all 256 steps, the knob parameters, DESC of the scale, LIVE), then `WATCH 3` for `watchSecs` while you play, with PING once a second and LIVE 20 times a second. One JSON object per frame: `{"t", "dir": "tx" | "rx", "hex"}`. Close SLOOP's web editor first unless you want its traffic in the capture (`live-1.jsonl` has some, on purpose).
