# Skiff projects on the iPad, and SLOOP and Skiff kept apart (2026-11-06)

Two items from Scott's list:

1. Connected to Skiff, nothing mentions SLOOP or shows SLOOP's files, and the reverse. Each firmware gets its own folder on the iPad.
2. Save a Skiff project on the iPad and open it later.

## Research: can Lupe move one Skiff project out and back in?

**Yes, with the protocol Skiff 2.2 already has. No firmware patch is needed and nothing needs flashing.**

Sources read: `~/code/skiff-src` at `5a50b4b` (Skiff 2.2 plus Scott's screen-link commits): `firmware/src/editor_backup.c`, `project.c`, `bank.c`, `editor_project.c`, `web/fm1backup.js`.

### What a Skiff project is

A Skiff 2.x project (`SKF4`, 2560 bytes, `project.c` `proj_pack4`) holds no steps. It holds each track's sound (engine, preset, every parameter, the FM6 patches, the DRUM-X kit), the globals, the name, and each track's list of 16 entries. Each entry names a pattern in the **pattern pool**: 64 patterns that every project on the FM-1 shares (`bank.c`). The pool keeps the steps, the timing (LEN DIV SWING GATE DIR) and the automation (888 bytes a pattern, in 16 chunks of 4 patterns).

So one project on its own is only half of the music. Moving a project out means taking its record and the patterns its entries name. Moving it back in means putting those patterns somewhere in the pool without writing over anyone else's.

### What the protocol already gives

Skiff's backup commands (Felucca's "archive", `editor_backup.c`) are the ones Lupe already uses for the whole-FM-1 backup:

| Command | What it does here |
|---|---|
| `BACKUP_LIST` (65) | Stops the transport, writes the tracks' waiting patterns to the pool (`keep_all`, the same thing a slot save does), and snapshots **the music now as an SKF4 record: object 0**. Lists every object with its size and CRC. |
| `BACKUP_GET` (66) | Reads any part of an object (offset and count): object 0, the slots 2…5, the pool chunks 16…31 (each 4 patterns). |
| `BACKUP_PUT` (67) | Begin, write, commit. For **object 0**, the commit checks the record and loads it as the music (`project_restore_runtime`). **It writes no project slot and no flash.** For a pool chunk, it checks every pattern and writes the chunk the way a save does (commit record last, so a torn write leaves the old copy). |

That is "send the current project" and "receive a project" already. Lupe does the pattern bookkeeping itself:

- **Save to the iPad:** `LIST`, then `GET` object 0, then `GET` only the chunks that hold the patterns its entries name. Lupe keeps the record and those patterns, by their ids.
- **Open from the iPad:** `LIST` (it stops the FM-1), then for each pattern the project needs:
  - If the pool holds the same bytes under the same id (the usual case when the project came from this FM-1 and nothing changed), it is used as it is. Nothing is written.
  - Otherwise the pattern goes into a **free** id. Free means empty in the pool and named by no entry of the music now or of the four slots. The entries are renumbered to match and the record's FNV-1a checksum is made right again.
  - Only the chunks that receive a pattern are written. Each one is read first and written back with its other three patterns byte for byte.
  - Last, `PUT` object 0 loads the project as the music, with the iPad's name on it (upper case, 12 letters, as Skiff names projects).
- **The pool is full:** Lupe opens nothing and says how many patterns the project needs and how many are free.

### What stays on the FM-1 (not in an iPad project)

These belong to the FM-1, not to a song, the same rule as SLOOP's iPad projects:

- **User sounds and samples.** A track whose sound came from a user slot keeps its own engine, preset and every parameter in the record, so it plays the same. Only the "came from U05" label points at the slot. An entry with its own sound set to a user slot (#30) plays whatever that slot holds when the project opens.
- **Settings:** MIDI, clock, the unit's tune.

### What a firmware patch would have added

A patch would let the FM-1 send a project with its patterns inside, and take one back with the FM-1 choosing the ids. That moves the bookkeeping above into C and costs a flash for Scott. It would buy one thing: saving to the iPad could read the music without stopping the transport. `BACKUP_LIST` stops it, as a slot save does. Not worth a flash on its own, so not built.

### Risks and how the build handles them

- **Saving to the iPad stops the FM-1.** `BACKUP_LIST` stops the transport, as Skiff's own save does. Lupe says so in the Save prompt.
- **Opening writes to the pool's flash** only when a pattern isn't already there. Opening asks first (save first, or open without saving), and Lupe keeps a safety copy of unsaved work on the iPad either way. A chunk write keeps that chunk's other patterns as they were.
- **A failed open part way:** the patterns written so far sit in ids nothing named before, so nothing is lost. The music stays as it was until the last step loads the project. They show on the FM-1's PATTERNS page and can be cleared there.
- **Edits are harder to spot than on SLOOP.** On SLOOP, Lupe compares a fingerprint of the FM-1 with the saved project once things go quiet. On Skiff, reading the music stops the transport, so Lupe can't check quietly. It counts any change from the app or the FM-1 as an edit after an open or a save, so it errs on the side of asking.

## Item 1: each firmware its own folder and its own words

The folders under Files › On My iPad › Lupe:

- `SLOOP/Projects`, `SLOOP/Projects/Safety copies`, `SLOOP/Backups`
- `Skiff/Projects`, `Skiff/Projects/Safety copies`, `Skiff/Backups`

Existing files move on first launch:

- `Projects/` goes to `SLOOP/Projects/`. Every iPad project made before today is a SLOOP project.
- `Backups/` is split by each file's own format: `sloop-backup` goes to `SLOOP/Backups`, `felucca-backup` to `Skiff/Backups`.
- A file is moved, never deleted. If the new folder already has a file of that name, the old one stays where it was. An old folder is removed only once it is empty.

## What was built

### Item 1: apart

- **Folders.** `ProjectFolders.migrate` (SloopKit `ProjectFolders.swift`) runs when the project store starts. Backups go to the running firmware's own folder (`DeviceBackup.save`, `FirmwareBackup.swift`), and the install screen names that folder.
- **One store, one firmware at a time.** The Projects sheet shows the connected firmware's projects, or the last connected firmware's when the FM-1 is unplugged. A file of the other firmware's put in the wrong folder by hand doesn't show. Each firmware remembers its own current project.
- **Wording on Skiff.** The Projects sheet no longer says "Projects saved on this iPad open on SLOOP". Skiff's rows show "N patterns" instead of SLOOP's BPM and A–D section marks. There's no Export on Skiff: SLOOP's export is SLOOP's song file. Opening says patterns go to free places in the pool. The Now Playing artist is the running firmware. The Arrange placeholder on Skiff no longer compares with SLOOP's sections.
- **Swept and left alone:** the firmware installer's text names both firmwares on purpose (you pick one there). The SLOOP section menu's hint shows only on SLOOP. The top bar's "needs SLOOP 2.8.4" shows only with nothing connected. That last one is a candidate for "needs Skiff 2.2 or SLOOP 2.8.4", but `TopBar.swift` belongs to another session.

### Item 2: Skiff projects on the iPad

The same project UX as SLOOP's: New project, Save as, Save, open with the save-first question, rename, duplicate, delete, safety copies (the last 5). They sit under "On this iPad", below the FM-1's own four slots.

- `SkiffProject.swift` (SloopKit): `SKF4` (the record: entries, name, checksum), `SkiffProjectData` (the record and its patterns, a content fingerprint that survives renumbering, `blank`), `SkiffProjectTransfer` (read and write over `BACKUP_LIST`, `GET` and `PUT`).
- **New project** puts a new unit's music on (each track's power-on sound, no patterns). It was captured from a fresh skiff-sim unit, the way SLOOP's blank was captured from SLOOP's host build. The pool keeps its patterns.
- The FM-1 shows the project's name after an open (12 letters, upper case).
- **Reconnecting:** if the music still has the name Lupe gave it and comes from no slot, Lupe takes it as that project and marks it edited, so opening something else asks first. Anything else counts as unknown, which also asks.

### Small edits to shared files

- `Session.swift`: `readSkiffProject` and `writeSkiffProject` (about 25 lines, beside `backUpDevice`). Also: METER pushes no longer count as project edits. Skiff's level meters push all the time while playing.
- `MIDITransport.swift`: a `FELUCCA_PORT` environment variable picks a port other than "felucca". Tests only, so a second skiff-sim can run beside another session's.
- `AppView.swift` (one string), `AudioThrough.swift` (one line), `FirmwareInstall.swift` (three backup-path strings).

## Tests

- `swift test`: 243 tests. Everything passes except one firmware-install timing test (`cutAndLeftThenFinishedFromTheLoader`), which failed once under the machine's load and passes when run again. It doesn't touch code changed here.
- New: `SkiffProjectTests` (a pretend archive: saved with its patterns; reopened with no pool writes; a changed pattern placed in a free id with its neighbours kept; ids a slot names avoided; a full pool opens nothing). `ProjectFoldersTests` (the move: nothing lost, nothing overwritten, old folders removed only when empty, a second run changes nothing).
- **Against Skiff's real firmware**, in skiff-sim (`SKIFF_SIM=1 FELUCCA_PORT="…" swift test --filter SkiffProjectSimTests`), passing:
  1. Two tracks get a pattern and a note each. Saving to the iPad gives patterns [0, 1], the ones the entries name.
  2. Opening it again unchanged writes **no** pool chunk, only the project. Skiff then names the music "ROUND TRIP".
  3. T1's note is changed on the FM-1, then the saved project opens. Exactly **one** chunk is written, T1 plays the saved note again under a new pattern id, and the changed pattern is still in the pool under its own id, byte for byte. The fingerprint matches the saved project's.

## Not verified

- **No screenshots.** Every simulator launch on this Mac hung (`simctl launch` stuck for every session at once), so the sheet hasn't been seen running. The app builds for the iPad simulator and for My Mac. The coordinating session was asked about restarting CoreSimulatorService.
- **Not tried on Scott's FM-1.** Nothing here needs a flash, and nothing was flashed. On the real unit, check that save stops the transport cleanly, that open's progress isn't too slow (GETs of 256 bytes over USB MIDI), and the PATTERNS page after an open that brought new patterns.
- **The app against skiff-sim from the iPad UI.** Only the transfer layer was run end to end (above), not through the sheet.
