# fm1-ipad

My own firmware for the M-VAVE FM-1 plus an iPad app, built to work as one instrument. The FM-1 makes the sound, stores the blocks (patterns) and plays them. The iPad is a bigger window onto it: it shows and edits what the FM-1 is doing, and arranges blocks into songs.

Design notes, decisions and the interaction spec live in my vault (`Projects/Dev/fm1-ipad/`), not here.

## Layout

| Folder | What | Built on |
|---|---|---|
| `firmware/` | Fork of M-VAVE's [FM1 Open](https://github.com/m-vave/fm1_open) at `4c7496d` (tag `upstream/fm1-open-4c7496d`). Stays byte-identical to upstream until the stock build is verified | Red Lion (Windows) |
| `ios/` | The iPad app (SwiftUI, CoreMIDI) | Blue Lion (Mac) |
| `tokens/` | `tokens.json`: the one source for colours, labels and sizes on both devices | both |
| `protocol/` | The SysEx protocol between the FM-1 and the iPad | both |

**One rule:** a change to `tokens/` or `protocol/` lands in the same commit as the code on both sides that depends on it.

## Building

- **Firmware (Red Lion):** see `firmware/README.md`. It needs Windows x64, PowerShell, and JieLi toolchain 2.5.3.
- **Browser simulator (Red Lion):** `firmware/tools/Build-Web.ps1 -LocalPreview`.
- **iPad app (Blue Lion):** not started yet.

## Licence

`firmware/` is GPLv3 with M-VAVE's SDK linking exception, and the engine is M-VAVE's binary under its own terms (see `firmware/LICENSE.md` and `firmware/THIRD_PARTY.md`). This repo is private. Sharing a firmware build means sharing its source.
