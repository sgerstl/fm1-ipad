# The firmware Lupe carries

Lupe installs the FM-1 firmware it speaks, so testers don't need a computer, and puts M-VAVE's stock firmware back. It carries exactly the files that were tested with the app, and refuses any file whose SHA-256 differs (`BundledFirmware` in `ios/SloopKit/Sources/SloopKit/FirmwarePackage.swift`). The files live in `ios/SloopKit/Sources/SloopKit/Resources/Firmware/`.

| | Skiff 2.2 with the screen link | SLOOP 2.8.4 with the screen link | Stock V15 |
|---|---|---|---|
| File | `skiff-2.2-screen-link.fwsc` | `sloop-2.8.4-screen-link.fwsc` | `FM-1_015.fwsc` |
| Size | 610,429 bytes | 610,052 bytes | 699,956 bytes |
| SHA-256 | `f11c90e342bc67045f67eccf0291fd44a25918442c022d126ed3eb6f1890f11e` | `97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110` | `db1642b2b6fa5c2cccb11ffd13878068bb28601678d3644049f99dc40e7edb8a` |
| Identity it reports | `FM-1_722` (its update loader: `ota-FM-1_722`) | `FM-1_900` (loader: `ota-FM-1_900`) | `FM-1_015` (M-VAVE's loader: `ota-FM-1_015`) |
| INFO version | `FELUCCA v2.2`, and `56 01 02` at the end of INFO (the screen link with the page's cursor) | `FELUCCA SLOOP 2.8.4`, protocol 12 | (none: Lupe doesn't speak to it) |
| Update loader in the package | Skiff's (`FELUCCA-LOADER-1`) | SLOOP's (`FELUCCA-LOADER-1`) | M-VAVE's `usb_hid_ota.bin` (header CRC 0xEBAA, body CRC 0x5881, 0x4DE1 bytes) |
| Source | [illuminus5/skiff](https://github.com/illuminus5/skiff), tag `v2.2`, plus `skiff/0001-screen-link.patch` | [isod89/sloop-fm1](https://github.com/isod89/sloop-fm1), tag `v2.8.4`, plus `sloop/0001-screen-link.patch` | [m-vave/fm1_open](https://github.com/m-vave/fm1_open) `sdk/firmware/FM-1_015.fwsc`, commit `4c7496d` (added in `3be7fbd`) |
| Built | 2026-11-05 from `~/code/skiff-src` branch `screen-link` (`2ebba0f` on `v2.2`), see `skiff/README.md` | 2026-11-01, see `sloop/README.md` | Not built: M-VAVE's binary, unchanged, downloaded 2026-11-05 |
| Licence | GPL-3.0 | GPL-3.0 | Apache-2.0 (see below) |

Notes:

- The Skiff file was built here from Skiff v2.2 plus Lupe's screen link patch (`skiff/README.md`: 131 lines in `editor.c`, SCREEN 90 with the page's cursor, SCREEN_GOTO 91, WATCH bit 2). Skiff's build isn't byte-for-byte reproducible, so the pin is this file's. Until 2026-11-05 Lupe carried stock 2.2 (`d0013c4f…8603`). An FM-1 on stock Skiff 2.2, or on the link's first build (`9d8eb232…acb71`, `56 01 01`, no cursor; it never left this Mac), is offered this one as an update (same identity, `FM-1_722`; Lupe tells them apart by INFO's `56 01` tag). **Not installed on a real FM-1 yet.**
- The V15 file's hash is the one Skiff pins for its own "return to official V15" (`STOCK_V15_SHA256` in Skiff's `tools/fm1_install.py` and `web/fm1pkg.js`). That is the same file the FM-1 Firmware Hub serves for "Back to official V15".
- Stock SLOOP 2.8.4 also reports `FM-1_900`; the app tells the screen-link build apart by asking `UI` (cmd 90) after connecting.
- All three packages' flash.bin is 0x93000 bytes. Skiff's and SLOOP's pass Skiff's `files_ok` and SLOOP's `package_damage`. V15's extra entries (types 50, 52, 161, 251) store CRCs of something else, so for it only flash.bin and the loader are CRC-checked, as Skiff's `files_ok` does. Only the pinned V15 file is ever installed with M-VAVE's loader: any other package without a Felucca loader is refused.
- M-VAVE's current download is V16 (`FM-1_016`, 718,196 bytes, sha256 `d017fb65…61d5`). Lupe doesn't carry it: Scott's FM-1 shipped with V15 and never ran V16, and V16's flash.bin (0xA9000) runs over the custom firmwares' project store.
- Building Skiff on this Mac needs Python 3.12 with Pillow, fontTools and Homebrew's libraqm: `PYTHON=<a wrapper running uv run --python 3.12 --with pillow --with fonttools python> ./build.sh --release 2.2` (the system Python 3.9 fails in the font tools).

## Licence and source

Skiff and SLOOP are GPL-3.0. Lupe is private and goes to Scott and testers only (Xcode, TestFlight). Shipping the binaries inside the app counts as distributing them, so the source is offered: the picker names each source above, and this file links it. Before any public release, the App Store and GPL question in the vault's `firmware-install-from-app.md` still needs an informed read.

V15 is **not** GPL, and the fm1_open repository as a whole isn't Apache-2.0 either. Its own code is GPL-3.0 with an SDK linking exception, and its engine is a proprietary binary SDK. `THIRD_PARTY.md` there says the recovery image `sdk/firmware/FM-1_015.fwsc` (with `uboot.boot`, `ota.bin`, `cfg_tool.bin`, `boot-config.bin`) is distributed by M-VAVE under the Apache License 2.0, binary redistribution included. Apache-2.0 asks for the licence text and the notices to travel with the file. `FM-1_015.LICENSE.txt` sits beside it in the bundle, with the copyright line, the source commit and the full licence. The picker says "Apache-2.0, unchanged" and names the source. There is no source code to offer for it.

## How the install works

A port of Skiff's `tools/fm1_install.py` and `web/fm1ota.js` (`FirmwareInstaller.swift`):

1. **Step 1, the running firmware** (Skiff, SLOOP, Felucca or M-VAVE's) gets the UPGRADE SysEx `F0 22 24 35 7F F7`, reads the package header and its update loader with cmd 0x30 requests (512-byte chunks, 7-bit packed), stages the loader, asks 0xE0000000 ("success") and restarts into it. Nothing is written to the firmware before that "success".
2. **Step 2, the update loader** (USB name "Felucca Update") gets UPGRADE, reads the whole flash.bin once and checks its CRC, then writes the app area sector by sector (the app's header erased first and written last), asks 0xF0000000 and restarts.
3. The new firmware's identity is checked against the package's.

The device asks; Lupe only answers. Only MIDI ports whose names an FM-1 uses (SLOOP's filter: `fm-1|felucca|sloop|clipper|ota|composite|sinco|usb-midi`) are opened, and a port gets nothing but the identity question until it answers with an FM-1 identity. A write is only finished by the loader that belongs to the package: Skiff's or SLOOP's (`ota-FM-1_7xx`, `ota-FM-1_9xx`) for those, M-VAVE's (`ota-FM-1_015`) for V15 and nothing else.

**Stock V15 takes the same two steps**, through M-VAVE's own loader. From the sources:

- Skiff's and SLOOP's step 1 (`firmware/src/ota.c`, `ota_stage`) recognise M-VAVE's loader by its CRCs and length. That loader rewrites the whole flash.bin, the 16 KiB boot head included, so they first read the package's head (32 reads) and compare it with the unit's. If it differs, they stop (`-5`): nothing is staged and nothing written. Otherwise they stage M-VAVE's loader at 0xE0000 and write an update record naming `ota-FM-1_015`, which becomes that loader's identity.
- M-VAVE's loader reads flash.bin once, from the top down (Skiff's installer tests and its `WriteMeter`), and asks 0xF0000000. A cut leaves the record, so it comes back as `ota-FM-1_015` at power-on, and Lupe finishes the write with V15.
- **A unit that shipped with V16, or ever ran it, has V16's head**, so V15 is refused in step 1 (Skiff issue #64: "failed -5"). Lupe names that, and refuses before anything is sent if the FM-1 already runs stock V16 or later. Scott's unit shipped with V15 (M-UPGRADE read "Version:15" on 2026-10-31) and never ran V16.
- **Not known publicly, and not tested here:**
  - the USB name M-VAVE's loader shows. The fake calls it "FM-1", and the port filter's generic names are there for it.
  - whether that loader checks flash.bin's CRC, and when.
  - whether it also writes V15's type-50 resource entry (0x11E20 bytes, aimed at the stock USR region 0xEA000). If it does, it writes over Skiff's pattern bank sectors and SLOOP's sample slot.
- One more gap: if M-VAVE's own updater was installing V16 and was cut off, the FM-1 may sit in an M-VAVE update mode that Lupe can't tell apart. Lupe's offer says to finish that one with M-UPGRADE.

**Cut off?** The update record stays, so the FM-1 comes back as the loader at every power-on until a write finishes, and writing again is safe. Lupe waits up to two minutes for the loader to return and resumes, up to five tries; after that, running the install again finishes it.

**What survives an install** (from the sources): Skiff's and SLOOP's loaders write only the app area 0x4000–0x93000, never the store at 0x97000–0xE0000 where projects, presets and samples live. Switching firmware keeps those bytes but not always their meaning. Skiff converts SLOOP's projects when it loads them, and SLOOP doesn't read Skiff's. The two also keep the autosave and the FM6 patches in each other's sectors, and use 0xE7000–0xFBFFF differently (Skiff's pattern bank, SLOOP's 80 KiB sample slot). So Lupe backs up everything the running firmware lists before it writes (`FirmwareBackup.swift`), as `sloop-backup` or `felucca-backup` JSON that the firmware's own web editor restores.

## Going through stock V15 between custom firmwares: not offered

Scott had read that every firmware installs cleanly from V15, but that one custom firmware over another can cause trouble, so maybe always go custom → V15 → custom. Checked 2026-11-05 against the Skiff, SLOOP, Felucca and fm1_open sources and issues, and the Firmware Hub. Full notes: `v15-switch-evidence.md` in the session notes folder. Labels: **established** (code or official docs), **emerging** (user reports), **speculative** (inference).

- **A stop at V15 doesn't clean the store.** *Established:* Skiff's and SLOOP's loaders never touch it, and as far as V15's file list shows, none of its entries aims at 0x97000–0xE0000. *Emerging:* after SLOOP → V15 → SLOOP, the old settings and sequences all came back (SLOOP #188), and V15 showed "corrupted UI elements and configs" in between. SLOOP's own guide says the same: V15 reads what SLOOP left, and a factory reset in M-VAVE's firmware clears it.
- **It costs data both ways.** *Established:* when V15 installs the next firmware, it stages its own loader at 0xE6000 with its record at 0xE7F00 (a V15 dump, Skiff `SMK37.md` and `tools/build.py`). That is Skiff's autosave B and first pattern-bank sector, and SLOOP's FM6 bank and the start of its sample slot (Skiff `storage.c`: "a later Felucca finds no valid copy"). *Speculative:* V15's resource entry for 0xEA000 may land on the same store on the way in.
- **Direct custom → custom has no refusal and no brick path in the code.** *Established:* neither firmware's step 1 refuses the other's package. Both loaders write the app area only. Each firmware drops records it doesn't recognise by magic, size and checksum. *Emerging:* switching back and forth kept saves (Skiff #96, SLOOP #8). One custom → custom brick was reported (gr!mm → SLOOP, SLOOP #199), cause unknown.
- **Nobody recommends the detour.** *Established:* the Firmware Hub says to try firmwares freely, with a backup. V15 first is advised only for particular targets, such as M-VAVE's Open V14 from Felucca 1.6.1 (Felucca #296) and Baud Girl's installer (SLOOP #8).
- **On V16 units the detour is impossible** through Skiff or SLOOP: V15 is refused at the head check (Skiff #64).
- **Where "it installs cleanly from V15" likely comes from** (*speculative*): installers for stock-based firmwares that accept only V15 as a starting point. Also older Felucca-family builds on the newer flash chip (0xB36014), which refuse every update until reflashed (Skiff #96, #102; Felucca #320; Skiff 2.2 knows both chips).

So Lupe doesn't offer "install through stock V15". It switches directly, after a backup on the running firmware, which is how anything the next firmware can't read comes back. "Restore stock V15" is its own picker item.

## New FM-1s on stock V16 (checked 2026-11-05)

M-VAVE released V16 on 2026-10-21, and new units likely ship with it. Can Lupe's first run take one to Skiff or SLOOP? Labels as above.

- **V16 still takes a custom firmware's loader in step 1.**
  - *Emerging:* an FM-1 that shipped with V16 got Skiff, then went Skiff → V16 → Skiff 2.0.2 "smoothly" (Skiff #64, the maintainer confirming). SLOOP #203 says people install over V16. On a stock V16 unit, SLOOP's loader did appear before failing (SLOOP #239).
  - *Established:* V16's own package carries the same M-VAVE loader as V15's (same CRCs and length).
  - *Established:* V16's release note (m-vave.com, FM-1.txt) lists only features: voices, the sequencer, FX, menus. It says nothing about the update path, signing or boot files.
  - *Not checked:* nothing of V16's update code is public.
- **What fails on new units is SLOOP 2.8.4's loader, not V16.**
  - *Established:* SLOOP 2.8.4's loader (`ldr_core.c`, `ldr_flash_known`) accepts only the Puya P25Q80 flash (0x856014). Newer FM-1s have the UC25HQ80 (0xB36014). On those, the loader drops the update record after the header and the app's 32-byte head, three reads in all, before any erase. The FM-1 then restarts on the firmware it had.
  - *Emerging:* SLOOP #239 is exactly that: stock V16, "the loader was disconnected after 3 requests", then back on V16. SLOOP #228 is the chip itself.
  - *Established:* SLOOP 2.8.5 (2026-11-04) and Skiff 2.2 know both chips.
  - *Speculative:* that a V16 unit has the new chip. They arrived about the same time ("sold from late 2026"), but nothing ties the two.
- **Routes from V16:**
  - Skiff 2.2 directly. That's what Lupe offers.
  - SLOOP via Skiff: Skiff first, then SLOOP 2.8.5 or later, which Lupe doesn't carry yet. Lupe's screen-link SLOOP is built on 2.8.4.
  - Stock V15: none. A V16 unit's head isn't V15's (above).
  - Its way back to stock is V16, with M-VAVE's M-UPGRADE, or Skiff's own installer since 2.0.2.
- **What Lupe does.** When the update ports say the FM-1 runs stock V16 or later:
  - the offer says Lupe can install Skiff 2.2
  - the picker shows SLOOP and Stock V15 as unavailable, each with its reason
  - `FirmwareInstaller.refusal(for:running:)` refuses SLOOP (`.flashChip`) and V15 (`.otherStock`) before anything but the handshake is sent

  The chip can't be read over USB-MIDI, so a new unit already running Skiff isn't caught up front. There, SLOOP's loader turning it down is caught when the FM-1 comes back on its old firmware after at most three reads. Lupe says nothing was written and why, instead of waiting two minutes for a loader that won't return.
- **Follow-up:** rebuild the screen-link SLOOP on 2.8.5 so new units can run SLOOP too. Then the V16 refusal for SLOOP can go.

## Tested

Offline, `swift test` in `ios/SloopKit` (FirmwareInstallTests, FirmwareStockTests, FirmwareBackupTests) against `FakeFM1`. The fake plays both steps as Skiff's `ota.c` and `ldr_core.c` do, plus ota.c's official branch and M-VAVE's loader as Skiff's tests play it. Covered:

- Full installs: SLOOP to Skiff, Skiff to SLOOP, stock to Skiff, Skiff and SLOOP to V15, and V15 → Skiff → V15 → SLOOP.
- Cable cuts: at 12 points of the custom write and 10 of the V15 write, and at 4 points of each check.
- Repeated cuts, and a cut left unplugged, then finished from Skiff's or M-VAVE's loader.
- Stalled loaders, and a loader that never appears.
- A tampered file and the wrong file. The V15 file unpinned, or offered as another firmware, is refused.
- Other gear on the MIDI setup.
- Mismatched update modes: Skiff's update mode refuses V15, and M-VAVE's refuses Skiff.
- A unit with V16's head refuses V15, and so does a unit running stock V16.
- A new unit on stock V16 with the newer chip takes Skiff, and refuses SLOOP and V15 up front. On such a unit running Skiff, SLOOP 2.8.4's loader turns it down after 3 reads, and Lupe says so at once.
- A wrong identity after the write, and cancel.

What the fake doesn't do: the chip-key check (it does play SLOOP 2.8.4's flash-chip refusal), and anything M-VAVE's loader may do beyond flash.bin.

**Not tested: a real FM-1.** The first real install, and the first real restore of V15, need Scott with the device.
