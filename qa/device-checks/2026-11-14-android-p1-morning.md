# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (morning after the overnight run)

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
| 1 | Open the debug screen with the FM-1 plugged in and on. | "FM-1: open"; "Mode: Session (the real app) · read-only: writes are blocked"; `link: {"phase":"ready"}`; `top` with the FM-1's tempo; a `diag` line with `"firmware":"FELUCCA v2.5.1"`, `"screenLinked":true`. | – | ☐ pass ☐ fail: |
| 2 | **Unplug the FM-1**, count two, **plug it back in**. Watch `link`. | `link` goes to `{"phase":"lost","reason":"unplugged"}`, then `connecting`, `reading`, `ready` again, **ready within about 2 s of plugging in** (BRIDGE gate 4). The log shows "removed", "lost: unplugged", then "added", "opening", "open". | – | ☐ pass ☐ fail: seconds to ready: |
| 3 | Open the normal Lupe app (home screen icon) with the FM-1 plugged in. Look at the top bar and the Pads tab. | P2's shell on the **real** FM-1: the project name, tempo and position readout from the FM-1; Pads rows named after the FM-1's tracks, with the entry each track is on lit. Tapping a pad only selects it for the editor; launches aren't wired yet. | – | ☐ pass ☐ fail: |
| 4 | Back up. Then allow writes: `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true` (the app restarts; the screen says WRITES ALLOWED). Open Lupe, press **Play** in the top bar, wait a bar, press **Stop**. | The FM-1 plays and stops. While it plays, `top` shows `"playing":true` and the bar·beat readout counting (MIDI clock), and the pads' progress bars move. | **Yes** | ☐ pass ☐ fail: |
| 5 | Make it read-only again: tap **Make read-only** on the debug screen. | "read-only: writes are blocked". | – | ☐ pass ☐ fail: |

**Already verified overnight on this Pixel and FM-1 (read-only):**
- Gate 3: the FM-1 was found by its real strings (manufacturer "Hügelton Instruments", product "Felucca", USB 0x1209:0001) and opened; raw mode's INFO came back decoded ("FELUCCA v2.5.1", 6 tracks, 15 engines, supported).
- Gate 4 (except unplug/replug): Session reached ready (searching → connecting → reading → ready), tempo 72 read, the screen link live (home page, track 3 selected), nothing blocked by the guard.
- Soak: see the commit and the hand-over note for the 10-minute result.

**Not covered here:** pad launches, step edits, locks and automation (P3 intents not wired in the core yet); MOTION reads; TalkBack (release pass); background behaviour with the FM-1 plugged in for a long time.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
