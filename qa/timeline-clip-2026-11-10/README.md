# Timeline box clipping fix: before/after (2026-11-10)

Scott: "fix the clipping, then install." At Half the Timeline's open track controls hang from the selected lane. Where they fit neither above nor below inside the lanes (T4 in the demo, opening downward), the lanes' sideways scroll and the page's foot cut them off: no LEVEL, STEPS or PAN row, and no close carets.

**The fix:** the controls draw outside the scroll, following it by its offset and cut off only at the heads' edge. While they're open on the Timeline (Half or Max), the page's foot gives way so they hang over the editor's top edge, the way the Pads' did at Max before 2026-11-09. Nothing else moves. While the box is scrolled partly under the heads it ignores touches, so the heads' mute and solo keep working there.

`capture.sh before|after` (the demo FM-1, stopped), then `python3 diff.py` (whole frames, unshifted). The before set is 710f7fe, built in a scratch worktree. Result (`diff-result.txt`):

| Scene | Result |
|---|---|
| Timeline Half T4 open | the box, now whole (x 270–666, y 370–437 pt: its bottom row and carets over the editor's top edge) |
| Timeline Half T1 / T5 / T6 open, Max open, full open | identical (they already fit) |
| Timeline Half T4 / T6 shut | identical |
| Pads full T1, Half T4, Max, full shut | identical |
