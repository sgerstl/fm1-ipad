# Timeline open tab: before/after (2026-11-10)

Scott: "Yes, add it". The Pads' open tab on the Timeline's selected lane while the track controls are shut.

**Alignment choice:** right-aligned to the block the editor shows. That block is what the controls hang from on the Timeline, so it plays the part the selected pad plays on Pads. The playhead moves while playing and has nothing to do with where the controls open. The tab sits on the lane's top edge when the controls open upward, the bottom edge when they open downward (the same `up` test the box uses).

`capture.sh before|after` (the demo FM-1, stopped), then `python3 diff.py` (whole frames, unshifted). Result (`diff-result.txt`):

| Scene | Result |
|---|---|
| Pads full shut, Pads Half T4 shut, Pads full T1 | identical |
| Timeline full open, Half T1 open, Half T4 open | identical |
| Timeline Half T1 / T4 / T6 shut, full shut, Max shut | only the tab's box (about 42 × 17 pt where it differs from the lane under it) |

The before set was built from 790c2ed. Side note: at Half the Timeline's open box is clipped by the editor, so its own close carets don't show there (unchanged by this; the head's double tap and now the tab still work).
