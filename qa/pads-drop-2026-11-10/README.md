# Patterns confirms, pad drops, pad drag feel: before/after (2026-11-10)

Scott: "yeah, let's fix the dialogs and make the pads take drops", and the pad drag "is a little klunky… shorter if it detects a slide… the pad should stay under the finger".

1. **Patterns panel confirms**: Clear N unused, Empty its steps and Clear pattern no longer use system dialogs. The ⋯ menu is a fan with in-place confirms (as Clear all pads). Clear N unused opens straight on its confirm by the key (`AppMenu.asking`).
2. **Pads take drops from the Patterns panel**: the pad it would land on gets the pad drag's dashed outline. Empty pad: takes it at once, shared (SET). Filled pad: a fan at the drop point (Replace X with N, shared; Copy N here; Cancel).
3. **Drag feel**: press, then slide more than **8 pt** after at least **0.15 s**: the pad lifts without waiting for the 0.45 s hold. Moving 8 pt sooner than 0.15 s is a swipe (no drag, no menu). A still hold opens the menu as before. Both are Labs items (`padSlideStart`, `padSlideDwell`, review 2026-11-24). The lifted copy is anchored where it was grabbed (before: centred on the finger, so a pad taken by its corner jumped half a pad).

`capture.sh before|after` (demo FM-1, stopped; `-pool-open` added for the drawer scenes), `python3 diff.py`. Before = HEAD 589fa19 plus only the `-pool-open` flag, built in a scratch worktree.

| Scene | Result |
|---|---|
| Pads full T1, full shut, Half T4, Max | identical |
| Pads full and Half with the Patterns drawer, Timeline Half with the drawer | identical |
| Timeline Half T4 | identical in the app; the 5 pt at the foot is iOS's home indicator, shown in that one frame |

Mid-drag frames (simulator): `drag-before`: the copy centred on the finger; `drag-after`: the copy's grabbed corner under the finger. Both in this folder (the cyan ring is where the finger is).
