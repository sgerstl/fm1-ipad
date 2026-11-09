# Device check: perform-grid-map, 2026-11-09

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; the branch merges to `main` only after it passes.

**Setup:** Skiff-Lupe 2.2 on the FM-1 · Lupe from branch `perform-grid-map` · a song with patterns on at least three tracks, one track with four or more entries · headphones.
**Back up first?** No. Nothing here writes the FM-1's flash (launches, mutes and scene recalls only; check 9 drags a pad, which rewrites a list in RAM, as before).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Song › Pads, editor shut (No grid). | Six rows, one per track, the track heads on the left lined up with them; columns A to one past the last entry used (at least 8); the 16 scenes underneath. | – | ☐ pass ☐ fail: |
| 2 | Stopped: tap a pad on a row that isn't selected. | That track moves to the entry. The selected track (its head tinted) doesn't change, nor does the editor or the FM-1's knobs. | – | ☐ pass ☐ fail: |
| 3 | Tap a track head. | That track is selected: its head tinted, its pad framed with the track controls hanging under it. | – | ☐ pass ☐ fail: |
| 4 | Look at the gap between the selected pad and its track controls. | The same gap as between two pads (Scott's note: they sat too high). Try a pad on the last row too: the controls open upward with the same gap. Tune it in Settings › Labs › Layout if not. | – | ☐ pass ☐ fail: |
| 5 | Stopped: tap the selected pad again. | Its controls roll away; again, they come back. | – | ☐ pass ☐ fail: |
| 6 | Play, Launch at Bar. Tap a pad on another track. | It waits (dashed, countdown) and comes in at the bar. The selected track stays put. | – | ☐ pass ☐ fail: |
| 7 | **The restart check.** While playing, tap the pad that's playing. | It waits and comes back in at the bar. Listen: does the pattern start again from step 1, or carry on where it was? Write which. (If it carries on, a restart needs a firmware op.) | – | ☐ from step 1 ☐ carries on |
| 8 | While playing, tap a pad, then tap it again while it waits. | The launch is taken back: the dashed outline goes and the track keeps playing. (It's done by relaunching the playing entry, so check 7's answer applies to it.) | – | ☐ pass ☐ fail: |
| 9 | Stopped: hold a pad and drag it along its row; then try dragging it onto another row. | Along the row it moves, as before. Onto another row nothing lands. | – | ☐ pass ☐ fail: |
| 10 | Hold a stored scene (one stored or recalled in Lupe). | Each track's pad for that scene gets a white outline; let go and it's gone. | – | ☐ pass ☐ fail: |
| 11 | Drag the editor tab to Half, then Max, and back; then flick the tab quickly up and down. | Half: six short rows beside the lane heads, the pads to their right, a border on the selected pad (no controls). Max: the selected track's row of 16. A quick flick moves one place in its direction, even if short. Speed in Settings › Labs › Gestures › Editor divider: flick at. | – | ☐ pass ☐ fail: |
| 12 | A song using 12+ entries on some track. | The columns grow to fit (up to 16), the pads narrower but all on screen; no sideways pan. | – | ☐ pass ☐ fail: |

**Not covered here** (needs skiff-sim, the iPhone, VoiceOver or a later round): the phone (Skiff's Song isn't on the phone yet, so board 40 waits); a chain drawn as one wide pad (board 35) is not built: chained entries still show as separate pads saying "Chained on"; VoiceOver labels now start with the track name ("Lead, entry C…"): release pass.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
