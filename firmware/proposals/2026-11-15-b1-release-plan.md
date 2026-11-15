# B1: what a release would take, and upstreaming it

*Prepared 2026-11-15, nothing done: no build pinned, no release made, nothing pushed, nothing sent.* B1 is in `2026-11-15-b1-steady-usb-audio.md`: every 48 kHz packet exactly 48 frames. It's on Scott's FM-1. Pixel 7 and Pixel 10 have 0 dejitter lines with FM6 playing, and the crunch is gone by Scott's ear. Before any of this: B1-1 (the Mac with sound), B1-2 (44.1 kHz) and B1-5 (the iPad) pass, and Scott says go.

## 1. The identity: keep FM-1_725, fold B1 into the 2.5.1 builds before their first release

**Recommendation:** no new version or identity. Put B1 into both Skiff-Lupe 2.5.1 builds, the screen-link one and the take one, rebuild them, and pin the new files. Why:

- **Neither 2.5.1 build has been released.** `lupe-firmware-2` (Skiff-Lupe 2.5.1) and `lupe-firmware-3` (the take build) aren't made yet (`LupeFirmware.release`, FIRMWARE.md). So no installed copy of Lupe pins the old SHAs, and no tester's FM-1 got them from Lupe. Only Scott's unit ran pre-B1 2.5.1, and it runs B1 now.
- **The identity can't carry a third digit.** `tools/build.py` makes `FM-1_7XY` from the version's first two digits only ("X.Y.Z and X.Y.Z.W keep X.Y's"). Every 2.5.x is FM-1_725.
  - The only distinct identity in Skiff's scheme is FM-1_726, which is Skiff 2.6. Upstream released 2.6 on 2026-11-12 (`skiff-releases.md`), so it's taken.
  - A family of Lupe's own (say FM-1_8XY) would touch Skiff's update path and Lupe's: `FirmwareInstaller.isResumable` accepts `ota-FM-1_[79]xx` only, and `LupeFirmware.matching`. Not worth it for a fix.
- **The version string must stay "v2.5.1".** Lupe connects only to an INFO version of exactly `FELUCCA v2.2` or `FELUCCA v2.5.1` (`Driver.swift` `FirmwareDialect.detect`, `SkiffFirmware(version:)`). A `--release 2.5.1-b1` build (`v2.5.1-b1`) would be refused by every Lupe.
- **Lupe already tells same-identity builds apart before an install by SHA**, as it does Skiff-Lupe 2.5.1 from its take build. After boot it uses INFO's tags (the take build's `56 01 07`).

**What that costs:** after boot, Lupe can't tell a B1 build from a pre-B1 2.5.1, since both are FM-1_725, "v2.5.1", screen link v6. No unit Lupe installed has the pre-B1 build, so this matters only if pre-release builds went to testers by hand. *Optional:* a Lupe-only INFO tag would let Lupe show it, and let a Lupe update offer B1 to such a unit. For example `41 01 01` ('A', audio: bit 0 = steady 48 kHz), a few bytes of flash plus one entry in `SkiffInfo.tagLength`. 0x41 isn't in Skiff's or Lupe's tag list today. Not needed for the release; Scott's call.

## 2. Pinning (the steps, when Scott says go)

1. **skiff-src:** cherry-pick B1 (72d4170) onto `lupe-skiff-2.5.1-screen-link` and onto `lupe-skiff-2.5.1-freetake` (5e10a37). Each a new commit; tag later as `lupe-skiff-2.5.1-screen-link.1` and the take's.
   - The take branch hasn't been tried with B1 yet. Expect it to apply: B1 touches `usb.c` and `uac_test.c`, and the take work is in the editor protocol. Check, don't assume.
2. **For each:** `tools/build.py --release 2.5.1` (the recipe in `skiff-2.5.1-rebase.md`). Then the whole host suite in the `skiff-tests` image, the size checks, and the SHA-256 of the package.
3. **fm1-ipad:**
   - replace `firmware/releases/Skiff-Lupe-2.5.1.fwsc` and `Skiff-Lupe-2.5.1-take.fwsc`, and update their release notes (`.md`) with the B1 change and the device results;
   - `LupeFirmware`: the new `sha256` (sizes stay 610,429 B unless the build says otherwise) and the `source` strings naming the B1 commits;
   - FIRMWARE.md's 2.5.1 paragraph;
   - SloopKit's `firmwareFilesMatchTheirPins` and the install tests run against the new files.
4. **A device check** for the pinned files: install each from Lupe (iPad), back up first, B1-1..5 again in short. The B1 build on Scott's FM-1 now is the experimental file, not the pinned one, and Skiff's builds aren't reproducible byte for byte.
5. **Delete** `firmware/proposals/EXPERIMENTAL-Skiff-Lupe-2.5.1-b1.fwsc`, or keep it as the record of what was tested. Either way, nothing ever pins it.

## 3. The GitHub release (made as a draft, unpublished, as Scott wants)

```bash
gh release create lupe-firmware-2 --repo sgerstl/fm1-ipad --draft --title "Skiff-Lupe 2.5.1" --notes-file firmware/releases/Skiff-Lupe-2.5.1.md firmware/releases/Skiff-Lupe-2.5.1.fwsc
```

```bash
gh release create lupe-firmware-3 --repo sgerstl/fm1-ipad --draft --title "Skiff-Lupe 2.5.1 take" --notes-file firmware/releases/Skiff-Lupe-2.5.1-take.md firmware/releases/Skiff-Lupe-2.5.1-take.fwsc
```

- **A draft's assets aren't served** at `/releases/download/<tag>/<file>`, which is where Lupe downloads from (`LupeFirmware.downloadURL`). Until a release is published, Lupe can't install that build; it says the download failed. Testing in the meantime: the file's `localCopy` (the simulator, the tests) or `tools/fm1fw` from the Mac.
- **The GPL source offer** goes with publishing: the B1 branches pushed to `github.com/sgerstl/skiff`, as the release notes link them. Pushing is an outward step of its own, with Scott's go-ahead.
- **Never add an asset to a release** installed copies already pin (`LupeFirmware.release`'s note). A later fix is a new tag.

## 4. Upstreaming B1 to illuminus5/skiff

**Checked:**
- B1 applies cleanly to upstream's `main` (Skiff 2.6, 0ea3682): `usb.c`, `uac_test.c` and `uac_fir.h` are unchanged between 2.5.1 and 2.6.
- With it applied, the three `uac_test` builds pass there: steady with and without CDC, and the band rule. Done in a throwaway worktree, since removed.

**Skiff's CONTRIBUTING.md asks for** a PR that is:
- small and on one thing;
- understood and explainable;
- per DESIGN.md;
- tested on a real FM-1 (done: Scott's);
- passing every host test;
- carrying SPDX headers and Skiff's change marks;
- GPL-3.0-only.

Feature ideas and questions go to Issues, "say in the title which it is".

**What would change for the PR:**
- The comments say "(Lupe, B1)". Skiff marks its changes with its version ("(2.5)", "(2.2)"), so they'd read "(2.6.x)" or whatever illuminus5 prefers.
- The comment naming "Android's USB audio on Pixels" stays as the reason.
- The test-only hook `UAC_TRACE_OUT` and the third `uac_test` build come along.
- `FELUCCA_UAC_STEADY` defaults to 1. Upstream may prefer that, or 0 until they've heard it.
- DESIGN.md: nothing on screen changes, so probably no rule to change. Check.
- The whole suite's two `fm1pkg.js` failures (stock files) and the TSan run fail on untouched code on this Mac; say so in the PR rather than leave them unexplained.

**Order, Scott's decision:**
- Scott's first note to illuminus5, introducing Lupe and offering the screen link (`firmware-authors-note.md`, drafted, not sent), is step 1 of the launch plan. Its rule is that the authors hear about Lupe from Scott first.
- **The B1 issue doesn't need Lupe.** The draft below names no app, so it could go before the note, after it, or as a reply to it.
- Posting either is outward-facing and needs Scott's go-ahead at the time.

**The draft** (Scott's voice, checked against the voice guide, passes `vale`): `2026-11-15-b1-upstream-issue-draft.md`. It's an issue offering the PR, as CONTRIBUTING suggests for a change in behaviour; the details list doubles as the PR description.
