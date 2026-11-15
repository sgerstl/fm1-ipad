# SLOOP in Lupe: the archive

Lupe began on [SLOOP](https://github.com/isod89/sloop-fm1) 2.8.4 and spoke it beside Skiff until **2026-11-15**, when Scott made it Skiff-only (**decision 43**). Nothing is lost: the trunk's last SLOOP state is the tag **`sloop-archive-2026-11-15`** (commit `77d4d6a`). Check it out to read, build or run any of what's listed here.

The removal was branch `claude/iphone-consolidation-6090a2`, in four commits: SloopKit, the app, the firmware offer, these docs.

## What an FM-1 on SLOOP gets now

- It no longer connects. Its INFO (`FELUCCA SLOOP 2.8.4`, protocol 12) is firmware Lupe doesn't speak (`.wrongFirmware`), but `FirmwareDialect.isSLOOP` recognises it.
- The phone offers the fork (`ForkFrom.sloop`); the iPad's card (`.unsupported`) offers Skiff-Lupe. Both say what happens to SLOOP's projects (below) and that Lupe can't back SLOOP up, so the backup is SLOOP's own web editor's.
- `ios/SloopKit/Tests/SloopKitTests/Fixtures/snapshot-0.jsonl`, the SLOOP capture of 2026-10-31, stays for that INFO (`SloopRefusalTests`). `firmware/releases/SLOOP-Lupe-2.8.4.fwsc` stays as a test fixture: installs over a SLOOP FM-1 are still tested.

## Files removed

SloopKit (`ios/SloopKit/Sources/SloopKit/`):

| File | What it did |
|---|---|
| `SloopDriver.swift` | The `FirmwareDriver` for SLOOP 2.8.4: every request through `SloopClient`, four tracks of 64 steps with a fixed drum track, capabilities LIVE playhead, song, projects, samples, master level. |
| `FakeSloop.swift` | The pretend SLOOP FM-1 for the demo and the tests: sections A–D as snapshots of the tracks, the song order in the settings object, LIVE, the backup objects, four sample slots, MASTER, random edits for the demo. |
| `Project.swift` | SLOOP's project format: `Fun6` (firmware `project_t`, format 6 "FUN6", 3816 bytes), `ProjectData` (the loop, sections A–D, the song order) and `SloopSong` (the web editor's `.sloopsong` file, encode and decode). |
| `Song.swift` | Split: `Pack7` and `CRC32` stay as `Pack7.swift`; `SongOrder` (settings object bytes 48–83, `arr_config_t`), `SongState` and LIVE's song fields went. |

App (`ios/FM1/`):

| File | What it did |
|---|---|
| `SloopSong.swift` | SLOOP's Song tab in the Skiff look (the 2026-11-10 design pass): pads for the loop and sections A–D, the song order as a timeline, the editor under the divider, Loop · Song keys, SLOOP's tools and strip. |
| `SongPage.swift` | The older Arrange page: section keys over the song order as blocks (tap for the menu, drag to move, flick up to delete, drag an edge for bars). |
| `SongSectionsPanel.swift` | Loop / Song mode, the sections panel, and a held section's menu (replace with the sequence, clear). |
| `SongBars.swift` | A block's bar pills and the bars control. |

Tests (`ios/SloopKit/Tests/SloopKitTests/`):

| File | What it covered |
|---|---|
| `SessionTests.swift` | The session on FakeSloop: reading, pushes, edits, the library and kits, the screen link on stock and patched SLOOP, the LIVE playhead. (`waitFor` moved to `TestSupport.swift`.) |
| `WorkflowTests.swift` | Sections, song mode, SONG REC, the order write and its rollback, the speaker going quiet with USB AUDIO FULL, a fast dial. (`BadInputTests` ported to FakeSkiff.) |
| `SongTests.swift` | The song order in the settings object, LIVE's song fields, sections on the demo. (Pack7 and CRC32 tests kept as `Pack7Tests.swift`.) |
| `ProjectTests.swift` | FUN6, `.sloopsong` round trips, the fingerprint, reading and writing projects on the demo. |
| `RecTests.swift` | REC as a LIVE op while polling. |
| `FixtureTests.swift` | Decoding SLOOP's captured traffic. Now `SloopRefusalTests.swift`: the `Capture` helper and SLOOP's INFO only. |
| `Fixtures/live-1.jsonl` | 60 s of SLOOP pushes, captured 2026-10-31. |

Also gone from files that stay: in `Session`, the LIVE loop and `applyLive`, sections and song mode, the song order and the settings writer, MASTER, SLOOP project read / write / fingerprint, the screen link's UI query; in `Messages` and `Client`, LIVE, BK_LIST / BK_GET / BK_PUT, UI / UI_GOTO and `LiveState` (`TrackPosition` replaces its track positions); in `Driver`, `FirmwareDialect.sloop`, `DeviceShape.sloop` and `sloopColours`, `ParamIDs.sloop` and SLOOP's drum and MIDI globals, the capabilities `livePlayhead`, `sloopSong`, `projects`, `masterLevel`; `DeviceDisplay.trackDesc`; `Music.keyPitch`, `chordNotes`, `chordModifier`, `chordNames`, `levelNames`; the `sloop-backup` capture; `LupeFirmware.sloop` and the SLOOP-on-V16 refusal; in the app, the SLOOP demo and `ui.demoSkiff`, `ui.sloopShell` and `-sloop-classic`, the SLOOP top-bar row and project key, the section menu, SLOOP projects and their export, and every `dialect == .sloop` branch.

Kept although SLOOP brought them (they're shared or harmless): `SloopKit` and `SloopClient` by name; `DeviceShape.drumTrack`, `DrumStep` and the drum-step requests (always nil / unused on Skiff); `ProjectFirmware.sloop` and `DeviceBackup.folder(format:)` for the files already in Files › Lupe › SLOOP; `FakeLoader`'s SLOOP 2.8.4 loader (an FM-1 can still be in it); the four-tab layout (`SequencerPage`), which a Skiff without song lists still gets.

## Design boards (kept)

- `design/boards/sloop.py`: boards S1–S5 (the structure map says S1 to S6; the script draws five), SLOOP in the Skiff look, the 2026-11-10 design pass. Its record: `qa/sloop-design-pass-2026-11-10/README.md`, `qa/device-checks/2026-11-10-sloop-design-pass.md`.
- `design/structure-map.md`, section "SLOOP: the same tabs, its own song", now marked history.
- `design/boards/phone-consolidation.html` mentions the SLOOP demo in the iPhone's menu (as it was).

## Firmware facts worth keeping

`FIRMWARE.md` keeps SLOOP-Lupe's column and the SLOOP notes as history. In short:

- **SLOOP-Lupe 2.8.4**: `firmware/releases/SLOOP-Lupe-2.8.4.fwsc`, 610,052 bytes, SHA-256 `97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110`, identity `FM-1_900` (loader `ota-FM-1_900`), INFO `FELUCCA SLOOP 2.8.4`, protocol 12. SLOOP 2.8.4 plus `sloop/0001-screen-link.patch` (47 lines). Source: isod89/sloop-fm1 tag `v2.8.4`. Stock SLOOP 2.8.4 reports `FM-1_900` too.
- **The chip.** SLOOP 2.8.4's loader knows only the Puya P25Q80 (0x856014) and drops the update after three reads on the UC25HQ80 (0xB36014) that newer FM-1s have (SLOOP #239, #228). SLOOP 2.8.5 and Skiff 2.2 know both.
- **SLOOP's projects after Skiff goes on.** Checked 2026-11-15 in Skiff's sources (`~/code/skiff-src`, `b5a0686`): Skiff 2.x does *not* convert them when it loads them. A slot of an earlier format (FUN1–FUN9, so SLOOP's FUN6) keeps its bytes and shows OLD FORMAT (`project.c` `proj_old`); Skiff's web converter (`web/conv`, the Skiff Editor's Restore, Skiff's installer page) converts them. `FIRMWARE.md` and `FirmwareBackup.swift` said "Skiff converts SLOOP's projects when it loads them", which held for Skiff 1.x; corrected.
- **The store.** Both firmwares' loaders write only 0x4000–0x93000; projects, presets and samples (0x97000–0xE0000) stay. They keep the autosave and FM6 patches in each other's sectors and use 0xE7000–0xFBFFF differently (Skiff's pattern bank, SLOOP's 80 KiB sample slot).
- **SLOOP's protocol, as Lupe used it.** LIVE (77) op 0 the state (50 bytes: transport, BPM, section, mutes, each track's step and length, the song's position), op 1 PLAY / STOP, op 2 a layer's key (SAVE is layer 7: keys 1–4 play a section, 5–8 store one, 13 song mode, 14 SONG REC), op 4 REC (sent padded to two bytes), op 11 the master level. Backup objects (BK_LIST 34, BK_GET 35, BK_PUT 36): 0 the working loop, 1 the settings ("PER3": the song order at bytes 48–83, USB AUDIO FULL at byte 85 bit 3), 2–5 sections A–D. The backup file: `sloop-backup`. The screen link: UI 90, UI_GOTO 91; SLOOP's pages HOME 37, PRESETS 28, SONG 30, NOTES 34, PATTERN 35, the SEL layer 5.
- **SLOOP's look.** Track colours `#287CFF #1ECC70 #FFC618 #FF621A` (tops `#4A93FF #4ADB8C #FFD54D #FF8247`); four tracks, the fourth a 16-lane drum track with four hit levels (Normal, Ghost, Soft, Hard), GM lanes from `drums.c` LANE_NOTE; the keyboard on channel 16, which SLOOP routes to the selected track (GLO › MIDI › OTHER = SEL).
