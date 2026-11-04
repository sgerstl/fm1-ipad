# skiff-sim

Skiff's firmware running on the Mac behind a virtual USB-MIDI port, so Jib (or `tools/skiffprobe`) can talk to Skiff without an FM-1. Built 2026-11-04 against Skiff 2.2 (`db2ce89`).

It runs Skiff's own code, not a fake: the engines, sequencer, UI and storage as Skiff's browser emulator builds them (`web/emu/felucca_web.c`), plus the parts that build leaves out: the editor protocol (`editor.c`, unchanged), USB MIDI in, and MIDI OUT (clock, Start / Stop, the tracks' notes). The port is called **Felucca (Skiff sim)**, so Jib's "Felucca" match finds it when Jib runs as *My Mac (Designed for iPad)*.

## Build

```sh
git clone https://github.com/illuminus5/skiff.git ~/code/skiff-src   # once
brew install libraqm                                                 # once: Skiff's font generator needs it
skiff-sim/build.sh
```

The first build generates Skiff's headers (`build/gen` in the Skiff checkout) with Python 3.12 through `uv`. No JieLi toolchain or Docker. Set `SKIFF_SRC` for a checkout elsewhere.

`build.sh` copies `felucca_web.c` into the Skiff checkout's `build/sim/felucca_sim.c` with two changes (the editor switched on, `sim_hooks.h` and `editor.c` included after the pattern bank) and stops if Skiff has changed that file's shape.

## Run

```sh
skiff-sim/build/skiff-sim [--flash FILE] [--name NAME] [--truth]
```

The flash (projects, settings, user sounds, samples) is kept in `skiff-sim-flash.bin` in the current folder, loaded at start and saved on `quit` or ^C. Delete it for a new unit.

`--truth` (test-only, not the unit's): while playing, every time a track's step changes, the sim sends a SysEx of its own, `F0 7D 53 4D s0..s5 F7`, each track's playing step (`seq_idx`), after that millisecond's clock and notes. It's the ground truth for `skiffprobe playhead`. It reads the sequencer, changes nothing, and touches none of Skiff's sources (`sim_track_step` in `sim_core.c`, `truth_send` in `sim_main.c`). The sequencer runs about 6 ms (one audio block) ahead of its MIDI OUT, so a report can arrive just before the tick its step starts on.

Console commands: `status`, `screen FILE.ppm` (the 240 × 240 screen; `sips -s format png` converts it), `press PLAY` (any printed button: FX SCL ENV LFO EDIT GLO HOME SAVE ARP SEQ PLAY REC OCT- OCT+), `trace` (print each editor reply), `save`, `quit`.

## What it is and isn't

- **Time is the Mac's.** The device runs a millisecond at a time against the wall clock, on one thread. The sequencer, clock and notes keep musical time, but jitter and USB latency are not the FM-1's. Logic tested here still needs checking on the unit.
- **One core.** Skiff's second core (MENU › CPU 2 CORES) isn't simulated, as in the browser emulator.
- **No sound yet.** Audio is rendered but not played.
- **No firmware updates or M-UPGRADE.** Those go to the unit.

## Files

- `sim_core.c`: the device, one translation unit with the firmware, and its small C interface (MIDI bytes in, whole messages out, a millisecond step, the screen).
- `sim_hooks.h`: what the unit's `ota.c`, `ota_hw.c` and flash driver give `editor.c` and `main.c`, over the simulated NOR.
- `sim_main.c`: CoreMIDI, the device thread, the console.

GPL-3.0, as Skiff and Felucca.
