# Device check: song-grid-panel-tint, 2026-11-09

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; the branch merges to `main` only after it passes.

**Setup:** Skiff 2.2 on the FM-1 · Lupe build from `song-grid-panel-tint` · USB cable · no launch flags.
**Back up first?** No. Nothing here writes the FM-1's flash.

What changed: the Song tab's editor panel tint used to stand 16 pt in from both page edges, so it was narrower than the pads and lanes above it, and its tab sat 16 pt right of the track strip. The grid gave up only 32 of the 56 pt of padding round it, so the editor ran flush to the tint's sides. Now the tint is the page's full width, the tab sits under the track strip, and the editor has 12 pt of tint on each side.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Song tab, Pads view, editor at Half (two chevrons down) | The tint's left and right edges line up with the track strip's left edge and the 16th scene key's right edge. The tab sits directly under the track strip, the same width. The editor's header, step panel and grid stand clear of the tint's sides by about the same gap on both sides. | – | ☐ pass ☐ fail: |
| 2 | Tap the tab to shut the editor, then drag it up to Max (row of 16 pads) | At Max the tint still lines up with the pad row's edges, and the grid's 16th step and the Follow key sit inside the tint, not on its edge. The open and close spring looks the same as before. | – | ☐ pass ☐ fail: |
| 3 | Switch to Timeline at Half, then select a drum track | The tint lines up with the lane heads on the left and the lanes' right end. The drum grid fits across inside the tint with no sideways scroll or clipped 16th step. | – | ☐ pass ☐ fail: |
| 4 | With the editor at Half, open the sampler for the selected track | The sampler slides in inside the same full-width tint and doesn't shift the pads above it. | – | ☐ pass ☐ fail: |

**Not covered here:** the iPhone, which doesn't use this panel. Smaller iPads, where steps are 1.5 pt narrower than before because the grid now gives up the full inset. The simulator was checked on a 13-inch iPad Pro only. VoiceOver is unchanged and waits for the release pass.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
