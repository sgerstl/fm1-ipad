# Lupe's firmware releases

The builds Lupe installs, kept here so each release is reproducible. They're **not in the app** (since 2026-11-08): Lupe downloads the chosen one from the GitHub release `lupe-firmware-1` and checks its SHA-256 (`LupeFirmware` and `FirmwareStore` in `ios/SloopKit`). M-VAVE's stock V15 stays in the app (`ios/SloopKit/Sources/SloopKit/Resources/Firmware/`, Apache-2.0).

| File | What | Notes |
|---|---|---|
| `Skiff-Lupe-2.5.1.fwsc` | Skiff 2.5.1 + Lupe's screen link (staged 2026-11-11, not on a device yet; release `lupe-firmware-2` not made) | `Skiff-Lupe-2.5.1.md` |
| `Skiff-Lupe-2.2.fwsc` | Skiff 2.2 + Lupe's screen link | `Skiff-Lupe-2.2.md` |
| `SLOOP-Lupe-2.8.4.fwsc` | SLOOP 2.8.4 + Lupe's screen link | `SLOOP-Lupe-2.8.4.md` |

A new build: new file, new pin in `LupeFirmware`, new release tag (`LupeFirmware.releaseTag`), then an app build. Never replace an asset on an existing release: installed copies of Lupe pin the old hash.

**Debug builds on a device carry these files** (since 2026-11-11): the app target's "Bundle release firmware (Debug)" phase copies them into the app as `DebugFirmware/`, and `FirmwareStore(localReleases:)` installs them, still checked against the pins. The GitHub releases were never made and the repo is private, so the download path 404s on a device; it only matters for a Release build.

In a Debug build the app and the tests use these copies directly (`LupeFirmware.localCopy`), so the simulator's firmware demos and the tests need no network.
