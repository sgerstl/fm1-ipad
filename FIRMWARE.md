# The firmware Jib carries

Jib installs the FM-1 firmware it speaks, so testers don't need a computer. It carries exactly the files that were tested with the app, and refuses any file whose SHA-256 differs (`BundledFirmware` in `ios/SloopKit/Sources/SloopKit/FirmwarePackage.swift`). The files live in `ios/SloopKit/Sources/SloopKit/Resources/Firmware/`.

| | Skiff 2.2 | SLOOP 2.8.4 with the screen link |
|---|---|---|
| File | `skiff-2.2.fwsc` | `sloop-2.8.4-screen-link.fwsc` |
| Size | 610,429 bytes | 610,052 bytes |
| SHA-256 | `d0013c4f1a60bc2116178c72c60eacd3d8464cbfa40dbbb7f48ba790912d8603` | `97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110` |
| Identity it reports | `FM-1_722` (its update loader: `ota-FM-1_722`) | `FM-1_900` (loader: `ota-FM-1_900`) |
| INFO version | `FELUCCA v2.2` | `FELUCCA SLOOP 2.8.4`, protocol 12 |
| Source | [illuminus5/skiff](https://github.com/illuminus5/skiff), tag `v2.2` | [isod89/sloop-fm1](https://github.com/isod89/sloop-fm1), tag `v2.8.4`, plus `sloop/0001-screen-link.patch` |
| Built | 2026-11-05 from `~/code/skiff-src` at `db2ce89` (no firmware or tool changes since `v2.2`), `./build.sh --release 2.2` | 2026-11-01, see `sloop/README.md` |
| Licence | GPL-3.0 | GPL-3.0 |

Notes:

- The Skiff file was built here, not downloaded. Its hash hasn't been compared with the release on GitHub, and Skiff's build may not be byte-for-byte reproducible (SLOOP's differs by a build stamp). It is the file Jib was tested against.
- Stock SLOOP 2.8.4 also reports `FM-1_900`; the app tells the screen-link build apart by asking `UI` (cmd 90) after connecting.
- Both packages pass Skiff's `files_ok` and SLOOP's `package_damage`, and their flash.bin is 0x93000 bytes, the size both firmwares' update steps require.
- Building Skiff on this Mac needs Python 3.12 with Pillow, fontTools and Homebrew's libraqm: `PYTHON=<a wrapper running uv run --python 3.12 --with pillow --with fonttools python> ./build.sh --release 2.2` (the system Python 3.9 fails in the font tools).

## Licence and source

Both firmwares are GPL-3.0. Jib is private and goes to Scott and testers only (Xcode, TestFlight). Shipping the binaries inside the app counts as distributing them, so the source is offered: the picker names each source above, and this file links it. Before any public release, the App Store and GPL question in the vault's `firmware-install-from-app.md` still needs an informed read.

## How the install works

A port of Skiff's `tools/fm1_install.py` and `web/fm1ota.js` (`FirmwareInstaller.swift`):

1. **Step 1, the running firmware** (Skiff, SLOOP, Felucca or M-VAVE's) gets the UPGRADE SysEx `F0 22 24 35 7F F7`, reads the package header and its update loader with cmd 0x30 requests (512-byte chunks, 7-bit packed), stages the loader, asks 0xE0000000 ("success") and restarts into it. Nothing is written to the firmware before that "success".
2. **Step 2, the update loader** (USB name "Felucca Update") gets UPGRADE, reads the whole flash.bin once and checks its CRC, then writes the app area sector by sector (the app's header erased first and written last), asks 0xF0000000 and restarts.
3. The new firmware's identity is checked against the package's.

The device asks; Jib only answers. Only MIDI ports whose names an FM-1 uses (SLOOP's filter: `fm-1|felucca|sloop|clipper|ota|composite|sinco|usb-midi`) are opened, and a port gets nothing but the identity question until it answers with an FM-1 identity. Only Skiff's and SLOOP's loaders (`ota-FM-1_7xx`, `ota-FM-1_9xx`) are resumed.

**Cut off?** The update record stays, so the FM-1 comes back as the loader at every power-on until a write finishes, and writing again is safe. Jib waits up to two minutes for the loader to return and resumes, up to five tries; after that, running the install again finishes it.

**What survives an install** (from the sources): the loader writes only the app area 0x4000–0x93000, never the store at 0x97000–0xE0000 where projects, presets and samples live. Switching firmware keeps those bytes but not always their meaning: Skiff converts SLOOP's projects when it loads them, SLOOP doesn't read Skiff's, and the two keep the autosave and the FM6 patches in each other's sectors. So Jib backs up everything the running firmware lists before it writes (`FirmwareBackup.swift`), as `sloop-backup` or `felucca-backup` JSON that the firmware's own web editor restores.

## Tested

Offline, `swift test` in `ios/SloopKit` (FirmwareInstallTests, FirmwareBackupTests) against `FakeFM1`, which plays both steps as Skiff's `ota.c` and `ldr_core.c` do: full installs (SLOOP to Skiff, Skiff to SLOOP, stock to Skiff), the cable cut at 12 points of the write and 4 of the check, repeated cuts, a cut left unplugged then finished from the loader, a stalled loader, a loader that never appears, a tampered file, the wrong file, other gear on the MIDI setup, M-VAVE's update mode, a wrong identity after the write, cancel. What the fake doesn't do: the chip-key check and M-VAVE's official loader.

**Not tested: a real FM-1.** The first real install needs Scott with the device.
