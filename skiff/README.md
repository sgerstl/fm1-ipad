# Skiff 2.2 + screen link

A small addition to [Skiff](https://github.com/illuminus5/skiff) 2.2 (GPL-3.0, a Felucca fork) so Jib and the FM-1 can follow each other's screen, as `sloop/` does for SLOOP. Everything else is stock 2.2.

| File | What |
|---|---|
| `0001-screen-link.patch` | The change: two commits as one mbox, `git format-patch v2.2..screen-link` from `~/code/skiff-src` (`2ebba0f` the screen, `b0cf6fa` the page's cursor). Firmware: 131 lines added, 6 changed, all in `firmware/src/editor.c`. Also Skiff's `tests/editor_test.c` (35 new checks) and a "Screen link" section in `web/EDITOR_PROTOCOL.md` |
| `skiff-2.2-screen-link.fwsc` | The built package, 610,429 bytes, SHA-256 `f11c90e342bc67045f67eccf0291fd44a25918442c022d126ed3eb6f1890f11e` (INFO tag `56 01 02`). Built 2026-11-05. **Not installed on a real FM-1 yet.** Replaces the first build, `9d8eb232…acb71` (`56 01 01`, no cursor), which never shipped |
| `screenprobe.swift` | The check against skiff-sim (below) |

## What it adds to the editor protocol

Same command numbers, same WATCH bit and the same first four state bytes as SLOOP's screen link, so one decoder serves both. The page and layer numbers are each firmware's own.

| cmd | Request | Reply |
|---|---|---|
| 90 SCREEN | none | 8 bytes: **home** (0/1), **page** (index into Skiff's `PAGES`, table below), **layer** (0 none, 1 FX, 2 GLO, 3 SCL, 4 EDIT, 5 SEQ, 6 REC, 7 PERF), **menu** (0 off, 1 the list, 2 ABOUT), **track** (selected, 0..5), **flags** (bit 0 HOME shows the scope, bit 1 the layer is locked open, bit 2 HOME held: SHIFT's map), **cursor**, **cursor 2** (the page's picks, 127 none; table below) |
| 91 SCREEN_GOTO | page, or 127 for HOME; optionally a cursor | the same 8 bytes, after the change. **Always answered**: refused requests (page past the table, a page the track's engine doesn't show, a dialog open, a cursor for a page or HOME that has none) answer the state unchanged. (SLOOP's UI_GOTO doesn't answer a refused page.) A request with no page byte gets no reply |

- **Detect it from INFO, no probing:** the INFO reply ends with `56 01 02`, after Skiff's `58 01 caps`. Stock Skiff ends at `58 01 caps`. (`56 01 01` was the first build, 6 bytes and no cursor; it never left this Mac. Decode SCREEN by its length anyway: a later version only appends.) INFO's version string is unchanged (`FELUCCA v2.2`), so the firmware identity is the same as stock 2.2; the tag tells the two apart.
- **Pushes:** `WATCH 7` (bits 0, 1, 2) or `WATCH 5`. The reply has bit 2 set when the firmware knows it. While watching, the FM-1 pushes `90` whenever any of the six bytes changes: every page and family button, SELECT walking a family, a layer button held open and let go, a locked layer, HOME held (flags bit 2, then menu 1 after a longer hold), the menu closing, another track selected. Newly asking for bit 2 pushes the state at once. Re-sending `WATCH 7` while already watching does not push again.
- **No echo:** the state in a `90` or `91` reply is not pushed back.
- **Keep-alive:** as for all of Skiff's pushes, watching ends 3 s after the last request. Send `PING` (25) about every second. A request sent before the previous reply arrived is dropped whole (Skiff #64), so wait for each reply.
- **SCREEN_GOTO** lands as the family button would: closes the menu (its settings kept), closes a locked layer, remembers the page as the family's last, starts the page as on the device. 127 is a HOME tap. A layer button physically held stays held.
- **Opt-in:** an editor that never sends bit 2, 90 or 91 sees no difference. Skiff's own web editor reads INFO only up to `58 01`.
- **The selected track** is in the state so one push is complete. `24 RELOAD` still carries it as before.
- **The page's cursor** is what KNOB 1 picks on a page instead of setting a value (on NOTES and FEEL, the step keys), the highlight the FM-1 shows and no editor could see. Counted from 0; the screen counts MOD's routes, samples and slots from 1 (route 9 shows as 10/11). It's pushed when it moves. SCREEN_GOTO's second byte sets the first cursor, clamped to its range. The second cursor is read-only.

| Page | Cursor | Cursor 2 |
|---|---|---|
| MOD | route 0..10 (0..6 the fixed routings, 7..10 the matrix slots) | — |
| LANES, LANE MIX | lane 0..7 | — |
| SOUND (DRUM-X) | sound 0..7 (BD..CB) | sheet window 0..3 |
| OPERATOR (FM6) | operator 0..5 | sheet window 0..4 |
| ALL OPS (FM6) | — | sheet window 0..4 |
| SLICES | marker, 0..slice count | — |
| SAMPLES | sample 0..15 | — |
| USER | slot 0..31 | — |
| PATTERNS | pattern 0..63 | ACTION: 0 CLEAR, 1 EMPTY, 2 UNUSED |
| NOTES, FEEL | selection's first step 0..63 (GOTO: sets the cursor, drops the selection) | selection's last step |
| AUTOMATION | row: 0 the page's own (PLAY, CLEAR), 1.. the list's | — |
| SONG | entry 0..15 (A..P) | — |

Every other page reports 127, 127. PRESETS has no cursor: its KNOB 1 loads the sound, which `24 RELOAD` already reports.

Skiff 2.2's `PAGES` (they can change between releases; the map belongs with the firmware version):

| Family button | Pages (index name) |
|---|---|
| ENV | 0 ENV, 1 ENV 2 |
| LFO | 2 LFO, 3 LFO 2, 4 MOD |
| FX | 5 FX, 6 DRIVE, 7 INSERT, 8 INSERT 2, 9 SLICER, 10 DUCK |
| SCL | 11 SCALE, 12 CHORD, 13 FOLLOW |
| EDIT | 14 EDIT 1, 15 EDIT 2, 16 OPERATOR, 17 ALL OPS, 18 LANES, 19 SOUND, 20 LANE MIX, 21 SLICES, 22 SAMPLES, 23–26 OP1–OP4 ENV, 27 OP LEVEL, 28 VOICE, 29 VOICE 2 (only those the track's engine shows) |
| GLO | 30 MIXER, 31 DELAY, 32 REVERB, 33 CHORUS, 34 GLOBAL |
| SAVE | 35 PRESETS, 36 USER, 37 PATTERNS, 38 PROJECT |
| ARP | 39 ARP, 40 ARP 2 |
| SEQ | 41 NOTES, 42 FEEL, 43 PATTERN, 44 AUTOMATION, 45 SONG |

`page` keeps its value while `home` is 1 (the page HOME was opened from). Full text in Skiff's `web/EDITOR_PROTOCOL.md`, section "Screen link".

## Building it (Blue Lion)

```
git clone --branch v2.2 https://github.com/illuminus5/skiff.git skiff-src
cd skiff-src && git am ../fm1-ipad/skiff/0001-screen-link.patch
PYTHON=<wrapper> ./build.sh --release 2.2       # build/skiff-2.2.fwsc
```

The wrapper runs Python 3.12 with Pillow and fontTools and finds Homebrew's libraqm:

```
#!/bin/sh
export DYLD_LIBRARY_PATH=/opt/homebrew/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}
exec uv run --quiet --python 3.12 --with pillow --with fonttools python "$@"
```

No JieLi toolchain or Docker: Skiff's build is self-contained (`brew install libraqm` once).

Sizes, against stock v2.2 built the same day on the same Mac:

| | Stock 2.2 | Screen link | Limit |
|---|---|---|---|
| App image | 559,128 B | 560,360 B (+1,232; the first build without the cursor: +456) | 581,564 B (`APP_SLOT`), 21,204 B left |
| RAM .data + .bss | 81,128 B | 81,144 B (+16) | 98,304 B |
| Pool, RAM code | unchanged | unchanged | |
| Package | 610,429 B | 610,429 B | |
| flash.bin | 0x93000 | 0x93000 | |

Both packages pass Skiff's `files_ok` (`tools/fm1_install.py`). Skiff's build isn't byte-reproducible: stock v2.2 rebuilt today hashes `74fb70fa…12d8`, not the `d0013c4f…8603` built this morning, so compare sizes, not hashes.

## Tested

- **Skiff's own tests**, all passing: `editor_test` (the console, release and no-SLICE builds, 35 new checks: the state, every flag, pushes on and off, no echo, every refusal, the menu and a locked layer closing; the cursor on MOD, PATTERNS, USER, NOTES with a selection, SONG and AUTOMATION, clamping, and a cursor refused on FX and HOME), `backup_test`, `robust_test`, `persistence_test`, `ratchet_test`, `ui_test`, `drum_test`, `editor_test` and `ui_test` under ASan/UBSan, and `fuzz_ed` for 200,000 iterations under ASan/UBSan. `tests/run_tests.sh` as a whole stops on macOS at `midi_uart_test` (a Linux-only section attribute in `usb.c`, which the patch doesn't touch), so those were run one by one.
- **skiff-sim**, the real firmware behind a virtual CoreMIDI port, with `screenprobe.swift`: INFO ends `56 01 01`. Under `WATCH 3` nothing new arrives while every function button is pressed. Under `WATCH 7` each of FX, SCL, ENV, LFO, EDIT, GLO, SAVE, ARP, SEQ, HOME pushes exactly one state, a second FX or SEQ press pushes the next page, holding FX pushes layer 1 then 0, and holding HOME pushes the SHIFT flag, then the menu. SCREEN_GOTO DELAY, PATTERN, FX, PATTERNS and HOME change the screen (dumped with `screen`), reply with the new state and push no echo. LANES on an ANALOG track is refused. KNOB 1 turned on MOD pushes the route each detent (1, 2, back to 1). SCREEN_GOTO MOD with route 9 moves the screen's highlight to route 10/11, FX with a cursor is refused, PATTERNS with 40 sets the pattern. After `WATCH 1` nothing new arrives.
- The probe needs two console commands skiff-sim doesn't have yet: `hold BUTTON MS` (the console's `press` is an 80 ms tap, too short to open a layer) and `turn ROLE N` (a knob, role 3..6 KNOB 1..4, through the emulator's `web_enc`). About 15 lines in `sim_main.c` and `sim_core.c`, added only to a scratch copy.

```
swiftc -O -o screenprobe skiff/screenprobe.swift
mkfifo con.fifo; (sleep 120 > con.fifo &)
skiff-sim --flash test.bin --name "Skiff screen test" < con.fifo &
./screenprobe "Skiff screen test" con.fifo /tmp/shots
```

**Not tested: a real FM-1.**

## Licence

The patch and the package are GPL-3.0, as Skiff is. Jib's code only speaks the protocol, but carrying or downloading this package distributes the binary, so its source goes with it: this patch on `v2.2` now, and the public fork (`sgerstl/skiff`, Scott's call) once there is one.
