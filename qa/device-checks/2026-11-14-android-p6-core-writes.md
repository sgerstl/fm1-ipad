# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (P6 core: the timeline and automation write to the FM-1)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

This sheet covers the **core**: each P6 intent reaching the real FM-1 (`android/core/Sources/PhoneCore/P6Intents.swift`):

- **Block edits** port the iPad's ArrangeEdits and go through the song store's rewrite.
- **Automation** draws through MotionPaint and `paintMotion`, the same calls as the iPad's lanes.

P2's P6 screens drive these. Until a screen exists for one, send it as P2's sheet says. Each check is one write.

**Setup:**

- FM-1 on Skiff 2.5.1, on the Pixel's USB port.
- This branch, with P2's P6 screens merged.
- The real core:

```bash
adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --es core real
```

**Backup: no.** Scott, 2026-11-14: "nothing on the FM-1 matters now, no backup needed". These checks rewrite the song's lists and MOTION's records. Allow writes:

```bash
adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true
```

While writes are off, the phone refuses every one of these and logs "read-only: … not sent". The FM-1 is untouched. That was tested on the Mac, not yet on the device. Picking which lane to show writes nothing, so it works either way.

Stop the transport before you start. The FM-1 refuses some list and MOTION writes while the song plays, and the phone logs why.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Timeline: compare track 1's blocks with the FM-1's SONG page. | The same patterns, in the same order, with the same REPS. Each block's length matches the bars it plays. | No | ☐ pass ☐ fail: |
| 2 | **Stretch** track 1's first block to 5 passes. | The FM-1's T1 entry 1 shows REPS 5. The block on the phone grows. | – | ☐ pass ☐ fail: |
| 3 | **Move** that block one place later. | On the FM-1, T1's first two entries swap. | – | ☐ pass ☐ fail: |
| 4 | **Duplicate** a block. | A copy of the same pattern appears right after it, on the FM-1 too. | – | ☐ pass ☐ fail: |
| 5 | **Insert** a kept pattern at the start of track 2. | T2's entry 1 is that pattern. The rest move one place later. | – | ☐ pass ☐ fail: |
| 6 | **Chain** track 2's first block into the next. | The FM-1 shows them chained, and the phone shows one block with two parts. | – | ☐ pass ☐ fail: |
| 7 | **Split** it again. | Two blocks again, and on the FM-1 the CHAIN flag is gone. | – | ☐ pass ☐ fail: |
| 8 | **New** on track 3. | A new empty pattern after T3's last entry (the FM-1's LIST NEW). | – | ☐ pass ☐ fail: |
| 9 | **Set pattern** on a block: pick another kept pattern. | The FM-1's entry names the new pattern. An empty pattern number is refused on the phone with "holds nothing". | – | ☐ pass ☐ fail: |
| 10 | **Delete** the block that check 8 made. Its pattern is used nowhere else. | The screen first confirms in place, saying the pattern is erased. Only the confirm removes it from the FM-1. | – | ☐ pass ☐ fail: |
| 11 | Playback mode: **Once**, then **Loop**. | The FM-1's SONG setting follows: ONCE, then OFF (each track loops its block). | – | ☐ pass ☐ fail: |
| 12 | Automation: pick a lane with nothing recorded and draw a stroke over 4 steps. | The FM-1 plays those changes, and its MOTION count rises. The value goes back to the sound's own after the stroke. | – | ☐ pass ☐ fail: |
| 13 | Draw over those recorded steps. | The screen confirms in place first (decision 16). Only the confirm replaces them. | – | ☐ pass ☐ fail: |
| 14 | Draw a **lock** on one step. | That step alone plays the locked value on the FM-1. The lane marks it as a lock. If the step sits after a recorded change, the screen confirms first. | – | ☐ pass ☐ fail: |
| 15 | **Clear** the lane. | The screen confirms in place first. Then the lane's records are gone, on the FM-1 too. | – | ☐ pass ☐ fail: |
| 16 | Make it read-only again: tap **Make read-only** on the debug screen. Then try a Stretch. | "read-only: writes are blocked". The Stretch is logged as not sent. | – | ☐ pass ☐ fail: |

**Not covered here:**

- Dragging blocks across tracks (the iPad moves within a track only).
- Live launches from the timeline (P3's launch intents, already checked).
- Firmware installs, sample import and SLOOP: out of scope.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the device".

## Run on build 40c8629, real FM-1 (TESTBED, 18 bars), writes allowed, over adb by Claude, 2026-11-13 evening

| # | Result |
|---|---|
| 1 | phone shows T1 06 · 30 · 31; compare with SONG: Scott |
| 2 | ✓ via the hold menu's PASSES: 1 → 5, the block grew, the blocks below moved. The grip drag couldn't be driven over adb (slow events read as a hold): Scott |
| 3 | ☐ Move by drag: Scott (adb can't drag fast enough) |
| 4 | ✓ Duplicate: a second 06 (5 passes) right after |
| 5–8 | ✗ no control on screen for Insert, Chain, Split or New on the Timeline (intents exist in `P6State.kt`) |
| 9 | ✓ Pattern ⌄ → 07. The list offers all 58 patterns as kept, so the "holds nothing" refusal can't happen |
| 10 | ✓ "Delete pattern 07 (5.00000 bars) from track 1? It is used nowhere else, so it's erased." → gone |
| 11 | ✓ readout › Playback Once → `mode once`, Loop → `mode loop`. FM-1 SONG: Scott |
| 12–15 | ☐ no pattern has a lane; making one needs a step held while an FM-1 knob turns: Scott |
| 16 | deferred (writes stay on for Scott) |
