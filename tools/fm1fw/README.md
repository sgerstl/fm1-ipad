# fm1fw

Backs up an FM-1 and installs a firmware file from the Mac, using SloopKit's own code, the code the iPad app uses:
- `FirmwareDetector` for INFO;
- `BackupCapture` for the backup taken before an install, in Skiff's `felucca-backup` file;
- `FirmwareInstaller` for both update steps and the resume.

It exists to test a build Lupe doesn't pin (`firmware/proposals/EXPERIMENTAL-Skiff-Lupe-2.5.1-b1.fwsc`). Nothing protocol-level is new.

```bash
cd tools/fm1fw && swift build -c release
```

```bash
.build/release/fm1fw info
```

```bash
.build/release/fm1fw backup ~/Documents/FM1-backups
```

```bash
.build/release/fm1fw install ../../firmware/proposals/EXPERIMENTAL-Skiff-Lupe-2.5.1-b1.fwsc --backup-dir ~/Documents/FM1-backups --experimental
```

The last one is a dry run: it checks everything and exits 3. Add `--yes` to install.

**What `install` checks before it sends anything beyond INFO and the update handshake** (any of these exits 2):
- **The file:** the installer's own package checks (FM-1 identity, Felucca loader, every file's CRC), and its SHA-256, printed. An unpinned file needs `--experimental`.
- **The backup:**
  - The newest in `<dir>/Skiff/Backups` must be under an hour old, or named with `--backup-taken`.
  - Every object must decode to its size and CRC-32.
  - It must come from the firmware the FM-1 runs now (INFO's version). The file can't name its unit, so plug in one FM-1 at a time.
- **The take build:** Skiff-Lupe 2.5.1 and its take build share the identity FM-1_725. An unpinned file over a take build (screen link v7) needs `--accept-older-link`; the B1 file is built without the take link.

**If the install stops** with the FM-1 in update mode, the message says so. Run the same command again with `--backup-taken <the backup>`: the installer finds the loader and finishes the write.

**Tests** (`swift test`) run against SloopKit's FakeSkiff and FakeFM1 only:
- the backup, the refusals and the dry run;
- a full install of the B1 file;
- a cut during the write, resumed;
- the FM-1 left in update mode, then finished.
