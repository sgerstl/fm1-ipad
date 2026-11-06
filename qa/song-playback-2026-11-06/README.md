# Playback state on the Song tab, 2026-11-06

Scott: "Yes, queue it." Skiff's rules (README: SONG OFF / ON / ONCE, "Playing an entry", LAUNCH; EDITOR_PROTOCOL.md LIST, PERFORM).

## The playback mode

SONG OFF / ON / ONCE (LIST op 6) are relabelled **Loop entry · Play song · Play once** and moved from the arrange tool row into the top bar, beside play and stop. The FM-1's own changes come back with the lists, so the two stay in step. On Skiff the bar is now one row (connection, tabs, mode, transport): centred tabs would have collided with the mode keys (`marks.jpg`).

## The marks, per track

`SongPlayback` (SloopKit) works out each track's marks from its list, the clock-counted passes and LAUNCH. Skiff doesn't report how many of an entry's REPS have played, so:
- `CountedPlayhead` now counts each track's passes;
- the song store records the pass each track came onto its entry on (an entry changes at a pass end).

Each lane draws its marks in its own 4 Hz layer, while playing, so the blocks don't redraw.
- **Playing:** as before (outlined, the pass bar), plus its pass of the REPS: **"2/4"**. **Loop entry:** ↻ instead, and no next.
- **Next** (Play song, Play once): a quiet outline on the block the track moves to when the REPS end. After the last block in Play song that's A, with a **wrap mark** (↩). In Play once, the last block gets **END**.
- **Queued** (a launch while playing): a pulsing outline and a countdown ("3 beats", "now") to where LAUNCH lands it: the track's pass end (LOOP), the next bar, the next beat, or now. LAUNCH is read with PERFORM every few seconds.
  - Skiff's LIST reports the song's own next as "staged" too, in Play song and Play once. Only a staged entry that *isn't* the song's next counts as queued.
- **Rest, chain, an entry's own sound, pinned:** unchanged. The marks are badges and outlines on top of them.
- **Reduce Motion:** no pulse; the queued outline is steady.
- **VoiceOver:** each block adds its state, e.g. "playing, pass 2 of 4", "next, back to the start", "queued, starts at the next bar", "playing, the last: the song ends after it".

## Checked

- **skiff-sim** (`SkiffSongSimTests.songPlaybackRulesOnTheFirmware`, two 1-bar patterns at 120 BPM on T6):
  - Play song played **A, B, A, B**; the marks predicted B next on A, and A (wrapping) on B.
  - Play once **stopped after 4.06 s** (two passes), the marks saying END on the last.
  - A launch staged 0.5 s in landed **2.02 s in with LAUNCH BAR** (the next bar), and **4.03 s in with LAUNCH LOOP** (A's 2-bar pass end, not the bar before).
- `SongPlaybackTests` (7):
  - next and wrap; once's end; loop;
  - the song's own next isn't a launch;
  - a launch with its countdown;
  - the repeat count across passes;
  - where each LAUNCH lands.
- The full suite: 231 tests.
- The simulator, demo playing: counters and next outlines (`marks.jpg`). The demo's fake doesn't move tracks through their lists, so there its counters cycle in place and nothing advances. That part was checked on skiff-sim.

## Not checked

- A queued launch on screen. The fake has no launches; skiff-sim covered the timing, not the drawing.
- The repeat count when Lupe joins mid-song: no Start seen, so there's no count until the next Start.
- VoiceOver walked by hand.

Design pre-flight: ran. The badges are 14 pt capsules (page colour at 85%, white type) inside the blocks' corners. Outlines are white: quiet (55%) for next, full and pulsing for queued. There's no new colour. The pulse is a 1 Hz opacity swing, none under Reduce Motion.

**For the polish pass:** on a narrow block the counter and the countdown can crowd the label. The top bar's tabs are no longer exactly centred on Skiff.
