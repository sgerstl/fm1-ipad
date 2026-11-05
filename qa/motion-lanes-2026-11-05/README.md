# Motion lanes that "don't react", 2026-11-05

Scott, on the real FM-1 in the Song tab, stopped: "I add a lane, and the line is there, and it just doesn't react to touch or anything."

## Cause

The lanes take touches. In the demo, a tap on an empty step adds a point. The problem was that **+ Lane offered parameters Skiff doesn't record as motion**:
- what + Lane offered: every parameter on the track's Shape pages (ARP, SCALE, CHORD, VOICE allocation, the MOD slots, LFO SYNC/TRIG/POL and others);
- what Skiff records: only the parameters in `motion_param` (motion.c).

A tap on such a lane sent MOTION op 3, which the FM-1 answers with **rc 1** (invalid). Lupe then took the device's reply, without the point, and said nothing. The point appeared for a moment and vanished, so the lane looked dead. The demo's fake accepted any id, which is why it never showed up here.

## Fix

- **`SkiffMotion.recordable`** ports `motion_param` with Skiff 2.2's ids, read from its core.h: 0–16, 32 (GATE), 33–36, 38, 39, 44, 61–80, and from 83 up except 91, 92, 117–119, 126 and 135–137.
- **+ Lane offers only those.** It now also offers the engine's EDIT 1 and 2 parameters (138–145), which Skiff records but the menu used to leave out, and the lane parameters on the drum pages. Lanes added earlier for anything else are dropped.
- **A refusal is said on the lanes** for 6 s, with a dismiss key:
  - not recordable or out of range: "The FM-1 refused that change: … can't be recorded as motion, or the value is out of its range.";
  - all 64 records used;
  - a song playing (rc 3, now decoded).
- **FakeSkiff refuses the same ids**, so the demo and the tests behave as the FM-1 does.

## Checked

- `SkiffSimTests.motionIsRecordedExactlyWhereLupeOffersIt`, against **skiff-sim** (Skiff 2.2's own firmware): 25 ids across every range. Each set is taken exactly when Lupe offers the id, and refused otherwise.
- `SkiffEditTests.whatSkiffRecordsAsMotion` and `aRefusedMotionChangeIsSaid`: ARP MODE is refused, said and not kept; CHORUS is taken and the message clears.
- The simulator, Song tab, stopped: + Lane → INSERT 2 → MIX adds a lane, and a tap on step 5 puts a point there (`new-lane-takes-a-point.jpg`, 8 of 64). Taps on the existing CHORUS lane add points as before.

## Not checked

- On the FM-1 itself.
- Drag and hold on the new lane, beyond the existing CHORUS lane. They're the same gesture code, which wasn't touched (Scott wants to talk through lane editing next).

## The Motion chip (Scott's polish, same build)

- **The banner row is gone.** It held the 64-slot counter, the key and + Lane, and sat under the grid.
- **A "Motion 7/64 ▾" chip** now sits in the pattern header, after the entry, on note tracks. It turns amber (a new `Theme.caution` token, with a warning icon, so the state isn't colour alone) when fewer than 8 of the shared 64 are free.
- **Its menu:**
  - Show or Hide the lanes;
  - + Lane (only what Skiff records);
  - Clear T*n*'s motion;
  - What uses the 64 (jumps to a track);
  - the key: a line is a recorded change held until the next one, a diamond is a lock on that step only.
- One deviation: Scott said "tapping it toggles the lanes and opens a menu". Doing both on one tap fought each other in a quick try, so Show/Hide is the menu's first item.
- **Lanes only when there's motion:** a pattern with none (and none added) shows no lanes, and the grid takes the space. Lanes are 28 pt, up to 4 before they scroll, with their names in the note-name column (`chip-with-and-without.jpg`: T1 with CHORUS and REVERB, T3 with none).
- The notes for "song playing: Stop" and a refusal sit above the lanes as before.
- **Lane editing gestures are unchanged**, waiting on Scott's talk.

**For the polish pass:**
- At 28 pt a lane is shorter than the 44 pt target. It's full width, and a point's grab zone is ±22 pt.
- Drum tracks have no chip and no lanes, as before.
