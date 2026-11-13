# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (the phone writes to the FM-1)

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the **Pixel 10 Pro** and the FM-1; the branch merges to `main` only after it passes. This is the first time the phone changes the FM-1: P3's Pads and editor intents now go to the real FM-1 through the calls the iPad uses (`android/core/Sources/PhoneCore/PadsEditorIntents.swift`).

**Setup:** FM-1 on Skiff 2.5.1 on the Pixel's USB port · this branch installed (after R1–R7 are done: `cd android && ./gradlew :app:installDebug`, or ask P1) · the **real core**: `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --es core real`.

**Back up first: yes, before check 1.** Every check here writes to the FM-1: the song lists, the patterns, the scenes, the steps and the locks. Back up with Lupe on the iPad (Projects) or Skiff's web editor. Then allow writes (the app restarts; the debug screen says WRITES ALLOWED):

```bash
adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true
```

Then open Lupe (home screen icon). While writes are off, every one of these is refused on the phone and logged ("read-only: … not sent"), and the FM-1 is untouched; that's tested on the Mac. Each check is one write. If one fails, note it and carry on.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | FM-1 stopped. Tap a pad holding a pattern on a track that's on another entry. | The pad lights as the one the track is on; the FM-1's own SONG view agrees (LIST PLAY). | **Yes** (before 1) | ☐ pass ☐ fail: |
| 2 | Press Play on the FM-1. Tap another pad on that track; before the launch point, tap the same (waiting) pad again. | First tap: it waits (dashed, "bar N"), then lands at the launch point. Tapping it while it waits takes the launch back: the entry playing is relaunched instead. | – | ☐ pass ☐ fail: |
| 3 | Stop. Tap a track's **M**. | The track mutes on the FM-1 (PERFORM). Tap again to unmute. | – | ☐ pass ☐ fail: |
| 4 | Tap **Store**, then an **empty** scene (say 2). Then Store again and scene 2 again (now kept). | The empty one stores at once on the FM-1. Over the kept one the screen asks in place (red-outlined row naming scene 2, Cancel under it, a tap in the first 0.4 s ignored); only the confirmed tap replaces it (Scott, 2026-11-14). *If the row isn't there yet, the phone refuses the replace and logs "must confirm": the row is P2/P3's.* | – | ☐ pass ☐ fail: |
| 5 | Tap scene **2** (not in Store mode). | The FM-1 recalls it (stopped: at once). | – | ☐ pass ☐ fail: |
| 6 | Hold an empty pad › **New pattern**. | A new pattern number appears there, on the FM-1 too; the editor shows it. | – | ☐ pass ☐ fail: |
| 7 | Hold that pad › **Set pattern…**, pick another number, Set. | The entry holds the other pattern on the FM-1. | – | ☐ pass ☐ fail: |
| 8 | Hold that pad › **Clear** (confirm). | The entry is empty on the FM-1. (Playing, the FM-1 refuses unless it's a REST; the phone logs "FM-1 refused: …".) | – | ☐ pass ☐ fail: |
| 9 | Tap a track's number (left of the pads). | The FM-1 selects that track. | – | ☐ pass ☐ fail: |
| 10 | In the editor, select a step with a note. NOTES: change **VELOCITY** once. | The cell's velocity changes, and the FM-1 plays the step softer or louder. | – | ☐ pass ☐ fail: |
| 11 | Change **PITCH** up once. | The note goes up a semitone on the FM-1 (a chord moves together). | – | ☐ pass ☐ fail: |
| 12 | Change **MOVE** once. | The step swaps with its neighbour on the FM-1; the selection follows. | – | ☐ pass ☐ fail: |
| 13 | Change **LENGTH** up once. | The note holds one step longer (a TIE after it) on the FM-1. | – | ☐ pass ☐ fail: |
| 14 | FEEL: change **CHANCE** down once. | The step's chance drops by 5 on the FM-1 (it starts skipping now and then). | – | ☐ pass ☐ fail: |
| 15 | Step ⋯ › Copy, select another step, Step ⋯ › Paste. | The second step becomes a copy, on the FM-1. | – | ☐ pass ☐ fail: |
| 16 | Step ⋯ › Clear step (confirm). | The step is empty on the FM-1, its locks gone too. | – | ☐ pass ☐ fail: |
| 17 | On the **FM-1** hold a step and turn a knob (a lock, made on the FM-1). On the phone, open that step's SOUND tab within a few seconds, then ✕ on the lock. | The lock shows up (◆, read from the FM-1's MOTION every 3 s); ✕ removes it from the FM-1. | – | ☐ pass ☐ fail: |
| 18 | Make two locks on a step that way, then SOUND › Clear all (confirm). | Both locks go from the FM-1. | – | ☐ pass ☐ fail: |
| 19 | FM-1 **stopped**, Chord **off**. Select a step in the editor and press a key on the **FM-1**. | The step takes that note (replacing what it had; CHANCE, COND, NUDGE kept) and the cursor moves to the next step (decision 5). | – | ☐ pass ☐ fail: |
| 20 | Turn **Chord on**, select a step with a note, press three more FM-1 keys, then a fifth. | Each key joins the step ("+1", "+2", "+3"), the cursor stays; the fifth is refused (four at most). | – | ☐ pass ☐ fail: |
| 21 | Press **Play** on the FM-1 and press a key. | Nothing is written: while playing, the FM-1's sequencer sends its notes on the same channels and they can't be told from your keys, so entry works stopped only. | – | ☐ pass ☐ fail: |
| 22 | Make it read-only again: the debug screen's **Make read-only**. | "read-only: writes are blocked". | – | ☐ pass ☐ fail: |

**Not covered here (and why):**
- **Lock from the phone** (hold a step or latch Lock, then turn a knob): this sets `Session.lockStep`, as the iPad's Lock does, so only knob turns *sent from Lupe* become locks; the FM-1's own knob still changes the sound (the FM-1 locks natively only when the step is held on the FM-1). **Fine for now, as on the iPad (Scott, 2026-11-14).** The phone's knobs are P4's sound pages; their `setParam` has to reach the core before a phone-made lock can be checked here. Tested on the Mac.
- **Select sound** on a pad (the entry's sound picker): a later phase.
- MIDI clock and Play from the phone: the 2026-11-14 morning sheet, check 4.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
