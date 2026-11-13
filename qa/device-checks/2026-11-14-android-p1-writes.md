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
| 1 | FM-1 stopped. Tap a pad holding a pattern on a track that's on another entry. | The pad lights as the one the track is on; the FM-1's own SONG view agrees (LIST PLAY). | **Yes** (before 1) | ☑ pass, over adb by Claude (2026-11-13, P2 build ba44e73): track 6 C48 became current, as the FM-1 reports it |
| 2 | Press Play on the FM-1. Tap another pad on that track; before the launch point, tap the same (waiting) pad again. | First tap: it waits (dashed, "bar N"), then lands at the launch point. Tapping it while it waits takes the launch back: the entry playing is relaunched instead. | – | **Scott, 2026-11-13: the FM-1 behaves right (take-back works on its SONG view), so the phone's pads area lags:** the launch lands; taking it back swapped which pad showed playing and waiting, "1 waiting" never went to 0 and stayed after Stop, until a later read (a mute) cleared it. Either the take-back relaunches instead of cancelling, or the pads area lags |
| 3 | Stop. Tap a track's **M**. | The track mutes on the FM-1 (PERFORM). Tap again to unmute. | – | ☑ pass over adb: track 6 muted and unmuted on the FM-1 |
| 4 | Tap **Store**, then an **empty** scene (say 2). Then Store again and scene 2 again (now kept). | The empty one stores at once on the FM-1. Over the kept one the screen asks in place (red-outlined row naming scene 2, Cancel under it, a tap in the first 0.4 s ignored); only the confirmed tap replaces it (Scott, 2026-11-14). *If the row isn't there yet, the phone refuses the replace and logs "must confirm": the row is P2/P3's.* | – | ☑ pass over adb into an empty scene 2 (this build predates the kept-scene confirm) |
| 5 | Tap scene **2** (not in Store mode). | The FM-1 recalls it (stopped: at once). | – | ☑ pass over adb: track 6 C48 → back to D52 on recall |
| 6 | Hold an empty pad › **New pattern**. | A new pattern number appears there, on the FM-1 too; the editor shows it. | – | ☑ pass over adb: track 1 A got new pattern 59; the editor showed it |
| 7 | Hold that pad › **Set pattern…**, pick another number, Set. | The entry holds the other pattern on the FM-1. | – | ☑ pass over adb with an existing pattern (58). **Setting the new, empty pattern 60 was refused:** "FM-1 refused: … the entry is empty, there's nothing to copy, or no room after it". The picker offers numbers Skiff won't take; limit it, or say why. Also the picker's − dropped one of two taps 0.4 s apart |
| 8 | Hold that pad › **Clear** (confirm). | The entry is empty on the FM-1. (Playing, the FM-1 refuses unless it's a REST; the phone logs "FM-1 refused: …".) | – | ☑ pass over adb (cleared track 1's own pattern 59). **Caution:** the confirm reads "removing pattern 58" when the entry shares a pattern with another track (track 2 B58); check whether Clear deletes a shared pattern, and if so name the other track in the confirm or refuse |
| 9 | Tap a track's number (left of the pads). | The FM-1 selects that track. | – | ☑ pass over adb: selectedTrack 2 → 4 (track 5), the editor followed |
| 10 | In the editor, select a step with a note. NOTES: change **VELOCITY** once. | The cell's velocity changes, and the FM-1 plays the step softer or louder. | – | ☑ pass over adb: 100 → 88 on the FM-1, then restored. Scott: listen once |
| 11 | Change **PITCH** up once. | The note goes up a semitone on the FM-1 (a chord moves together). | – | ☑ pass over adb: F5 D5 → G5 E5 (chord moved together), restored. Feel: a column is ~120 dp tall, so one slide reaches ~7 pitch steps |
| 12 | Change **MOVE** once. | The step swaps with its neighbour on the FM-1; the selection follows. | – | ☑ pass over adb: swapped through, selection followed, restored |
| 13 | Change **LENGTH** up once. | The note holds one step longer (a TIE after it) on the FM-1. | – | ☑ pass over adb on step 4 (1→2→1). On a step whose next step holds a note it silently does nothing: show that it can't grow |
| 14 | FEEL: change **CHANCE** down once. | The step's chance drops by 5 on the FM-1 (it starts skipping now and then). | – | ☑ pass over adb: 100 → 95, restored |
| 15 | Step ⋯ › Copy, select another step, Step ⋯ › Paste. | The second step becomes a copy, on the FM-1. | – | ☑ pass over adb: step 3 pasted into step 16 |
| 16 | Step ⋯ › Clear step (confirm). | The step is empty on the FM-1, its locks gone too. | – | ☑ pass over adb: step 16 emptied (confirm named "F5") |
| 17 | On the **FM-1** hold a step and turn a knob (a lock, made on the FM-1). On the phone, open that step's SOUND tab within a few seconds, then ✕ on the lock. | The lock shows up (◆, read from the FM-1's MOTION every 3 s); ✕ removes it from the FM-1. | – | ☑ pass: Scott, 2026-11-13 on the FM-1 |
| 18 | Make two locks on a step that way, then SOUND › Clear all (confirm). | Both locks go from the FM-1. | – | ☑ pass: Scott, 2026-11-13 on the FM-1 |
| 19 | FM-1 **stopped**, Chord **off**. Select a step in the editor and press a key on the **FM-1**. | The step takes that note (replacing what it had; CHANCE, COND, NUDGE kept) and the cursor moves to the next step (decision 5). | – | ☒ fail (main session's run on P2 a592fa6, 2026-11-14): FM-1 stopped, writes allowed, T5 pattern 56, step 16 selected; a key wrote nothing, nothing logged. See "Key entry, after the run" below. |
| 20 | Turn **Chord on**, select a step with a note, press three more FM-1 keys, then a fifth. | Each key joins the step ("+1", "+2", "+3"), the cursor stays; the fifth is refused (four at most). | – | ☒ fail: with Chord on, a second key wrote nothing either. |
| 21 | Press **Play** on the FM-1 and press a key. | Nothing is written: while playing, the FM-1's sequencer sends its notes on the same channels and they can't be told from your keys, so entry works stopped only. | – | ☐ not reached (19 and 20 failed first) |
| 22 | Make it read-only again: the debug screen's **Make read-only**. | "read-only: writes are blocked". | – | ☐ pass ☐ fail: |

**Fixed after the run (P1, 2026-11-14), to re-check:**
- **Check 2, take-back.** The phone never re-read the FM-1's song lists between its own writes. The iPad runs the song store's follow loop while its Pads page is up; PhoneCore now runs it too. So a launch landing at the loop point now shows within a moment, and "waiting" clears. Taking a launch back sends PLAY for the entry playing: the FM-1 has no per-track cancel, and in Loop mode that entry simply goes on. It's no longer counted as waiting. Re-check: playing, Loop, launch a pad, watch it land; launch again and tap the waiting pad; the readout's "waiting" should go to 0 at once. *(The fake used to land every launch at once, which hid this; it now stages them while playing, as Skiff's protocol says.)*
- **Check 7, Set pattern.** Skiff's SET takes only a kept pattern. The pads area now lists the kept numbers (`pads.kept`) for the picker, and the core refuses an empty number with a log line. Showing only those numbers is P2's.
- **Check 8, Clear.** Skiff's CLEAR empties the entry and erases the pattern only when nothing else names it (pattern 58, also on T2 B, would have stayed). The confirm text ("removing pattern 58") is wrong for a shared pattern. P2 is changing it: only an unshared pattern is named as going, as on the iPad.
- **Check 13, LENGTH.** It stops at the next note, as before, but the editor now knows the cap (`step.maxLength`) and the log says why. Showing it is P2's.

**Key entry, after the run (P1, 2026-11-14), for the next try:**
- What's known: nothing was written and nothing was logged. Back then a successful key logged nothing, and neither did a key on another track's channel. Skiff's README says keys go out only *as they sound*, on the sounding track's channel (T1–T6 CHANNEL), and **a muted track sends nothing**. Track 5 looked muted in the earlier screenshots. The editor's cursor went 15 → 0 at 12:26:14, which is what a written key does with Chord off, so that's unexplained until the log says.
- Now every key is logged ("FM-1 key E4 ch 5 vel 90: written to T5 step 16", or the exact reason it was ignored), and the debug screen's `diag` line counts notes in (`notesIn`). Before pressing, check: T5 **not muted**, MENU › MIDI › **NOTES OUT** is ALL or KEYS (not OFF), and the FM-1's selected track is the editor's track.
- New guard: Skiff sounds a step when it's written (STEP PREVIEW), and that note coming back within 0.3 s is no longer entered into the next step.
- **Finding 2 (paste/clear into step 16 cut step 15's tie):** that's Skiff's own behaviour (step 16 was the TIE holding step 15's note). The editor now marks such a step (`step.heldFrom`), so P2's paste and clear confirms can say "this shortens step 15 (D5) to 1 step".

**Not covered here (and why):**
- **Lock from the phone** (hold a step or latch Lock, then turn a knob): this sets `Session.lockStep`, as the iPad's Lock does, so only knob turns *sent from Lupe* become locks; the FM-1's own knob still changes the sound (the FM-1 locks natively only when the step is held on the FM-1). **Fine for now, as on the iPad (Scott, 2026-11-14).** The phone's knobs are P4's sound pages; their `setParam` has to reach the core before a phone-made lock can be checked here. Tested on the Mac.
- **Select sound** on a pad (the entry's sound picker): a later phase.
- MIDI clock and Play from the phone: the 2026-11-14 morning sheet, check 4.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
