# SEQ on the FM-1: what Lupe sends back, 2026-11-05

Scott pressed SEQ on the FM-1 and something froze. Lupe has no crash log for it, and the screen-link session is reproducing it on skiff-sim. This is Lupe's side.

**When the FM-1's screen changes (SEQ: NOTES, then PATTERN), Lupe:**
1. takes the SCREEN push;
2. follows: the Song tab and a flash on the step panel; then for PATTERN, the whole-track popover opens;
3. reads the selected track's steps if the push carried another track.

It sends **no SCREEN_GOTO**. Every call that moves the FM-1's screen (`showOnDevice`, `driveDevice`) comes from a tap or a pad press in Lupe, and none of them runs on a screen change. I checked every caller by grep. The one automatic case is the iPhone's centred Shape page, which is guarded so it doesn't send the page the FM-1 is already on. New test: `seqOnTheDeviceIsNotEchoed` (NOTES, then PATTERN on the fake: no 91 sent). Requests go one at a time through the driver's client, as before.

**The flood risk found, and fixed:** the new EDIT engine cards (OPERATOR, ALL OPS, SOUND, SAMPLES) re-read their data on *every* screen push. They did this even off screen, since Shape builds every card. A knob turned on NOTES (each step picked is a push) would have queued an FM6_GET (131-byte reply) per detent for an FM6 track. Now:
- a card re-reads only when the FM-1 is on its page or has just left it (`SkiffEdit.concerns`);
- the store keeps one read per thing out at a time, with at most one more after it (`SkiffEditStore.once`; test `readsDontQueueUp`: 20 reads asked at once, at most 2 sent).

That code landed today (529a8ce) and came after the builds Scott was on, so it isn't the cause of his freeze. It's fixed before it could become one.

**Not checked here:** the FM-1 side, which the screen-link session has on skiff-sim.
