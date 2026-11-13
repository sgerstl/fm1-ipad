# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (P5 core: Mix, Sounds, Projects write to the FM-1)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with the **Pixel 10 Pro** and the FM-1; the branch merges to `main` only after it passes. This sheet covers the **core**: each P5 intent reaching the real FM-1 through the calls the iPad uses (`android/core/Sources/PhoneCore/P5Intents.swift`). P2's screens drive them; until a screen exists for one, send it from the link debug screen's log or over adb as P2's sheet says. Each check is one write.

**Setup:** FM-1 on Skiff 2.5.1 on the Pixel's USB port · this branch (with P2's P5 screens merged) · the real core: `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --es core real`.

**Back up first: yes, before check 1.** Scott says nothing on the FM-1 matters right now, but these checks write the song's levels and sends, the sounds, the 32 user slots and the four project slots. Then allow writes:

```bash
adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true
```

While writes are off, every one of these is refused on the phone and logged ("read-only: … not sent"), and the FM-1 is untouched (tested on the Mac).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Mix › Mixer: move track 2's LEVEL. | The FM-1's T2 level follows; the row's dB matches the FM-1's MIXER page. | **Yes** (before 1) | ☐ pass ☐ fail: |
| 2 | Track 2's hold menu › PAN: move it left. | T2 pans left on the FM-1 (decision 14: PAN in the hold menu). | – | ☐ pass ☐ fail: |
| 3 | Move track 3's REVERB send. | T3's reverb send changes on the FM-1 (its FX page, knob 4). The other rows' sends update within 3 s of a change made on the FM-1. | – | ☐ pass ☐ fail: |
| 4 | **Solo** track 4. | The other five tracks mute on the FM-1 (Lupe's solo, through PERFORM's mutes, as on the iPad). Solo again to undo. | – | ☐ pass ☐ fail: |
| 5 | Pick **Delay** in the selector. | The FM-1 shows GLO › DELAY (the screen link). Turn one of the card's knobs: the FM-1's delay value follows. | – | ☐ pass ☐ fail: |
| 6 | On Delay, change **DELAY MODE** (2.5.1's setting). | The FM-1's delay mode changes. | – | ☐ pass ☐ fail: |
| 7 | Open Sounds for the selected track, browse another engine, pick a preset. | The track takes that sound on the FM-1. (An engine a light track (T5–T6) can't play: the phone says why, and the FM-1 keeps the old sound.) | – | ☐ pass ☐ fail: |
| 8 | On a drum track, pick another kit. | The track's kit changes on the FM-1 (decision 15: a kit per track). | – | ☐ pass ☐ fail: |
| 9 | Hold a pad › Select sound, pick a preset. | That pad plays the chosen sound (marked: the cut corner), the rest of the track keeps its own. Then clear it: the pad plays the track's sound again. | – | ☐ pass ☐ fail: |
| 10 | **SAVE** the track's sound into an empty user slot with a name. | The slot shows it, on the FM-1 too (SAVE › USER). | – | ☐ pass ☐ fail: |
| 11 | SAVE into that slot again. | The screen confirms in place, naming what's there; only the confirm replaces it. | – | ☐ pass ☐ fail: |
| 12 | Pick that user slot for a track. | The track takes the saved sound. | – | ☐ pass ☐ fail: |
| 13 | Erase that user slot (confirm). | The slot is empty on the FM-1. | – | ☐ pass ☐ fail: |
| 14 | Projects › **Save as** into an empty slot, with a name. | The slot holds the music under that name; it's marked as the music's slot. (The FM-1 stops the transport to save, as its own save does.) | – | ☐ pass ☐ fail: |
| 15 | Change something, then **Load** another slot. | The screen confirms in place, saying the unsaved changes go; the confirm loads it (transport stopped). | – | ☐ pass ☐ fail: |
| 16 | **Save** (over the music's own slot). | Confirms in place (it replaces what the slot held), then saves. | – | ☐ pass ☐ fail: |
| 17 | **Rename** a used slot. | The new name shows, on the FM-1's SAVE › PROJECT too. | – | ☐ pass ☐ fail: |
| 18 | Make it read-only again: the debug screen's **Make read-only**. | "read-only: writes are blocked". | – | ☐ pass ☐ fail: |

**Not covered here:** firmware installs, sample import and SLOOP (out of scope); user samples (USR slots) in the Sounds list (sample import is out, so the phone shows the 32 sound slots only); the Projects sheet's iPad-side files (the phone has only the FM-1's four slots).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
