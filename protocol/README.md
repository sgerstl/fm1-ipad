# Protocol

The app speaks **Skiff's editor protocol**: SysEx `F0 7D 46 4C <cmd> ... F7` over USB MIDI, Felucca's framing and command numbers as Skiff keeps them. The reference is Skiff's `web/EDITOR_PROTOCOL.md` (github.com/illuminus5/skiff); there is no protocol of my own. The one firmware change is the screen link (`skiff/README.md`: SCREEN 90, SCREEN_GOTO 91, and the later builds' METER, SCOPE and TAKE), which the app uses when INFO's `56 01` tag says the FM-1 has it.

The typed requests in `ios/SloopKit/Sources/SloopKit/Messages.swift` are the commands Felucca's firmwares share (INFO, sent typed at connect to tell the firmware; the sample commands 11–15; the rest). `SkiffDriver` sends its requests with Skiff's own numbers and argument forms as raw requests (`SkiffCmd`).

**History.** Until 2026-11-15 the app also spoke SLOOP 2.8.4 (protocol 12, pinned in `vendor/sloop-2.8.4/EDITOR_PROTOCOL.md`): LIVE (77) polled for the playhead, BK_LIST / BK_GET / BK_PUT (34–36) for projects and the song order, and SLOOP's screen link (`sloop/`: UI 90, UI_GOTO 91). Lupe became Skiff-only then (decision 43); an FM-1 on SLOOP now answers INFO with `FELUCCA SLOOP 2.8.4`, is treated as unknown firmware and offered Skiff-Lupe. The last SLOOP state is the tag `sloop-archive-2026-11-15`.

The earlier custom protocol (`F0 7D 'F' 'I' ...`) is archived on the `slice-1-link` branch.
