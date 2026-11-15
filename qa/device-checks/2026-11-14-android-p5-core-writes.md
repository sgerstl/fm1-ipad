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
| 1 | Mix › Mixer: move track 2's LEVEL. | The FM-1's T2 level follows; the row's dB matches the FM-1's MIXER page. | **Yes** (before 1) | ☐ not run (phone away) |
| 2 | Track 2's hold menu › PAN: move it left. | T2 pans left on the FM-1 (decision 14: PAN in the hold menu). | – | ☐ not run (phone away) |
| 3 | Move track 3's REVERB send. | T3's reverb send changes on the FM-1 (its FX page, knob 4). The other rows' sends update within 3 s of a change made on the FM-1. | – | ☐ not run (phone away) |
| 4 | **Solo** track 4. | The other five tracks mute on the FM-1 (Lupe's solo, through PERFORM's mutes, as on the iPad). Solo again to undo. | – | ☐ not run (phone away) |
| 5 | Pick **Delay** in the selector. | The FM-1 shows GLO › DELAY (the screen link). Turn one of the card's knobs: the FM-1's delay value follows. | – | ☐ not run (phone away) |
| 6 | On Delay, change **DELAY MODE** (2.5.1's setting). | The FM-1's delay mode changes. | – | ☐ not run (phone away) |
| 7 | Open Sounds for the selected track, browse another engine, pick a preset. | The track takes that sound on the FM-1. (An engine a light track (T5–T6) can't play: the phone says why, and the FM-1 keeps the old sound.) | – | ☐ not run (phone away) |
| 8 | On a drum track, pick another kit. | The track's kit changes on the FM-1 (decision 15: a kit per track). | – | ☐ not run (phone away) |
| 9 | Hold a pad › Select sound, pick a preset. | That pad plays the chosen sound (marked: the cut corner), the rest of the track keeps its own. Then clear it: the pad plays the track's sound again. | – | ☐ not run (phone away) |
| 10 | **SAVE** the track's sound into an empty user slot with a name. | The slot shows it, on the FM-1 too (SAVE › USER). | – | ☐ not run (phone away) |
| 11 | SAVE into that slot again. | The screen confirms in place, naming what's there; only the confirm replaces it. | – | ☐ not run (phone away) |
| 12 | Pick that user slot for a track. | The track takes the saved sound. | – | ☐ not run (phone away) |
| 13 | Erase that user slot (confirm). | The slot is empty on the FM-1. | – | ☐ not run (phone away) |
| 14 | Projects › **Save as** into an empty slot, with a name. | The slot holds the music under that name; it's marked as the music's slot. (The FM-1 stops the transport to save, as its own save does.) | – | ☐ not run (phone away) |
| 15 | Change something, then **Load** another slot. | The screen confirms in place, saying the unsaved changes go; the confirm loads it (transport stopped). | – | ☐ not run (phone away) |
| 16 | **Save** (over the music's own slot). | Confirms in place (it replaces what the slot held), then saves. | – | ☐ not run (phone away) |
| 17 | **Rename** a used slot. | The new name shows, on the FM-1's SAVE › PROJECT too. | – | ☐ not run (phone away) |
| 18 | Make it read-only again: the debug screen's **Make read-only**. | "read-only: writes are blocked". | – | ☐ not run (phone away) |

**Not covered here:** firmware installs, sample import and SLOOP (out of scope); user samples (USR slots) in the Sounds list (sample import is out, so the phone shows the 32 sound slots only); the Projects sheet's iPad-side files (the phone has only the FM-1's four slots).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

## Run on build 40c8629, real FM-1 (Skiff 2.5.1, TESTBED), writes allowed, over adb by Claude, 2026-11-13 evening

Phone-side results read back from the core (LupeState); "FM-1 screen" items are for Scott.

| # | Result |
|---|---|
| 1 | ✓ phone: T2 level −4 → −11.5 dB, held through the polls (only after an up-and-down drag; see P5 screens). FM-1 MIXER: Scott |
| 2 | ✓ phone: PAN in the row's hold menu, C → L29. FM-1: Scott |
| 3 | ✓ phone: T2's reverb send 69 → 81 % (same menu). FM-1: Scott |
| 4 | ✗ no Solo on screen |
| 5 | ✓ FEEDBACK 50 → 63 % read back. FM-1 shows GLO › DELAY: Scott |
| 6 | ✗ DELAY MODE can't be changed (plain text on the real core) |
| 7 | ✓ T1 ANALOG › PHASE PD BRASS: the track reads "Phase · Pd Brass". Light-track refusal not tried (every engine is offered) |
| 8 | ✓ T4 kit DRUM KIT → WAR DRUMS |
| 9 | ✓ on drum track 6: pad A took DEEP KIT, cut corner shown, the track kept Soft Kit; "Use the track's own sound" cleared it. ✗ on melodic track 5 it changed the whole track |
| 10 | ✓ saved into user slot 1 (named FLUTE automatically, no name asked) |
| 11 | ✓ "Replace user slot 1 (FLUTE) with this sound?" with Cancel |
| 12 | ? T3 took slot 1 but reads "Sample · Piano"; Scott to listen |
| 13 | ✓ "Erase user slot 1 (FLUTE)? It can't be undone." → slot empty |
| 14 | ✓ Save here into slot 4 stored at once (busy flashed); copied the name, none asked |
| 15 | ✓ changed a level, Load 3 asked in place, confirm loaded TESTBED (tempo 82, new mix) |
| 16 | ✓ "Save over 4 LUPE TEST?" then saved (busy) |
| 17 | ✓ renamed slot 4 to LUPE TEST; the top bar follows. FM-1 SAVE › PROJECT: Scott |
| 18 | deferred: writes stay on for Scott's hands-on checks |
