# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (morning after the overnight run)

## Start here

**This branch (`claude/android-p1-core-link-faf639`) has everything for this morning:** P1's core, P2's shell, P3's Pads and editor (`0dea0a6`), and P4's sound pages (`f6dd305`). One build covers all four checks. It is **already installed on the Pixel** (overnight, read-only) with Lupe open, so skip the install steps in the P2, P3 and P4 checks. If you need to reinstall: `cd android && ./gradlew :app:assembleDebug`, then `adb install -r android/app/build/outputs/apk/debug/app-debug.apk`.

The build starts on the **real core** (the FM-1) and read-only. P3's and P4's checks are written for the **fake core**, so the order switches once:

1. **P1 morning (this file):** checks 1–5 below, FM-1 plugged in, real core. Check 4 is the only one that writes (back up first).
2. Switch to the fake core (the app restarts): `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --es core fake`
3. **P2 shell:** `android-p2-shell.md` checks 11–13.
4. **P3:** `android-p3-pads-editor.md`, all checks.
5. **P4:** `android-p4-sound-pages.md` checks 1–11. Skip 12: it needs the real core's `page` area, which isn't built yet (`android/notes/p1-page-area-brief.md`).
6. Back to the real core: `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --es core real`

Tests behind this build: Kotlin 15/15 (FixturesTest 3, FakeLupeCoreTest 6, FakePagesTest 6), core 14/14.


Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the **Pixel 10 Pro** and the FM-1. It covers what the overnight run couldn't do without a hand, and spot-checks what it did. The branch merges to `main` only after it passes. It replaces checks 1–5 of `2026-11-13-android-p1-core-link.md`; those were run overnight (results below).

**Setup:** FM-1 on its USB port (it reports **Skiff 2.5.1**, "FELUCCA v2.5.1", not 2.2) · Lupe for Android, this branch, already installed on the Pixel overnight · adb over Wi‑Fi (192.168.2.56, port may change) or USB before plugging the FM-1 in.
**Back up first?** **Yes, before check 4 only.** Checks 1–3 are reads. Check 4 lets writes through, and Play/Stop are the only writes the app makes today. They don't touch flash, but back up anyway as for any first write from new code (Lupe on the iPad › Projects, or Skiff's web editor).

The app starts **read-only**: only commands Skiff's protocol calls queries reach the FM-1, and anything else is dropped and logged. No button turns writes on; check 4 uses an adb command.

Open the link debug screen:

```bash
adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity
```

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open the debug screen with the FM-1 plugged in and on. | "FM-1: open"; "Mode: Session (the real app) · read-only: writes are blocked"; `link: {"phase":"ready"}`; `top` with the FM-1's tempo; a `diag` line with `"firmware":"FELUCCA v2.5.1"`, `"screenLinked":true`. | – | ☑ pass (2026-11-13 09:26, Scott + screenshot) |
| 2 | **Unplug the FM-1**, count two, **plug it back in**. Watch `link`. | `link` goes to `{"phase":"lost","reason":"unplugged"}`, then `connecting`, `reading`, `ready` again, **ready within about 2 s of plugging in** (BRIDGE gate 4). The log shows "removed", "lost: unplugged", then "added", "opening", "open". | – | ☑ pass: ready in about 2 s (Scott's eye; app log lines lost in logcat noise) |
| 3 | Open the normal Lupe app (home screen icon) with the FM-1 plugged in. Look at the top bar and the Pads tab. | P2's shell on the **real** FM-1: the project name, tempo and position readout from the FM-1; Pads rows named after the FM-1's tracks, with the entry each track is on lit. Tapping a pad only selects it for the editor; launches aren't wired yet. | – | ☑ pass: Pads and tempo match the FM-1 |
| 4 | Back up. Then allow writes: `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true` (the app restarts; the screen says WRITES ALLOWED). Open Lupe, press **Play** in the top bar, wait a bar, press **Stop**. | The FM-1 plays and stops. While it plays, `top` shows `"playing":true` and the bar·beat readout counting (MIDI clock), and the pads' progress bars move. | **Yes** | ☑ pass: played and stopped (backup taken first) |
| 5 | Make it read-only again: tap **Make read-only** on the debug screen. | "read-only: writes are blocked". | – | ☑ pass, by adb (`--ez allowWrites false`). **Fail on the button:** Make read-only sits below the state readout and the screen doesn't scroll, so it can't be reached once `pads` is filled. Put the write switch above the readout, or make the column scroll. |

**Already verified overnight on this Pixel and FM-1 (read-only):**
- Gate 3: the FM-1 was found by its real strings (manufacturer "Hügelton Instruments", product "Felucca", USB 0x1209:0001) and opened; raw mode's INFO came back decoded ("FELUCCA v2.5.1", 6 tracks, 15 engines, supported).
- Gate 4 (except unplug/replug): Session reached ready (searching → connecting → reading → ready), tempo 72 read, the screen link live (home page, track 3 selected), nothing blocked by the guard.
- Soak: 11 minutes on the debug screen (02:27–02:38) with the link staying `ready`, nothing lost, nothing blocked.
- P2/P3's shell on the real FM-1 (02:39): the Pads tab showed the FM-1's own patterns (track 2 A 57 · B 58, track 5 A 53 · B 56, track 6 A 32 · B 33 · C 48 · D 52), 72 BPM, and the editor on track 3 "Phase · Pd Organ". Check 3 asks you to confirm those match what the FM-1 itself shows.
- The project name came back empty: the FM-1 reported no saved slot for the music playing (PROJ_NAME). If your project is saved in a slot, that's a bug: note it in check 3.

**Not covered here:** pad launches, step edits, locks and automation (P3 intents not wired in the core yet); MOTION reads; TalkBack (release pass); background behaviour with the FM-1 plugged in for a long time.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
