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
