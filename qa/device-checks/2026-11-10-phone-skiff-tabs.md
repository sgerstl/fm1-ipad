# Device check: claude/gracious-jackson-60c5c1 (phone Skiff tabs), 2026-11-10

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad, an iPhone and the FM-1; the branch merges to `main` only after it passes. Based on `a11y-pass-2026-11-10` (not merged yet), so it goes in after that branch, or with it.

**What changed:** the flag that turns on Skiff's tabs (`ui.songTab`) is now set at the app's root, for both layouts. It used to be set by the iPad's layout only, so on an iPhone a Skiff FM-1 got SLOOP's tabs (Sequence · Shape · Arrange · Browse). The phone's tab bar also uses Skiff's tab names now.

**Setup:** FM-1 on Skiff-Lupe firmware · Lupe from this branch, on the iPad and on an iPhone · USB cable.
**Back up first?** No. Nothing here writes the FM-1's flash.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | iPhone, landscape, FM-1 on Skiff plugged in. Open Lupe and let it connect. | The top bar's tabs read **Song · Mix · Sounds**. Song is selected and shows the card "Arrange on Skiff is on the iPad for now" (the phone's Pads and Timeline aren't built yet). | – | ☐ pass ☐ fail: |
| 2 | iPhone: tap Sounds, then Mix, then Song. | Each tab opens. Sounds shows the engines and presets. Mix opens, but its layout is the iPad's, and on the phone it's known to be broken (strips under the top bar, effect cards over the strips): note it, don't fail on it. | – | ☐ pass ☐ fail: |
| 3 | iPhone: press SEQ, then EDIT, on the FM-1. | SEQ stays on (or comes back to) Song; EDIT doesn't bring up a Shape tab. No Sequence or Shape tab appears at any point. | – | ☐ pass ☐ fail: |
| 4 | iPad, same FM-1: open Lupe, let it connect, tap through the tabs. | Song · Mix · Sounds as before, Song on the Pads. Nothing changed here (the flag moved, it didn't change). | – | ☐ pass ☐ fail: |

**Not covered here** (needs skiff-sim, VoiceOver or a later round):
- The phone's Pads · Timeline split and its Pads grid (structure map, board 40): not built. A follow-up.
- Mix on the phone needs a phone layout (`qa/accessibility-2026-11-10/README.md`, iPhone › Second run).
- The phone's accessibility audit ran in the simulator only; VoiceOver on the iPhone waits for the release pass.
- A SLOOP FM-1 on the phone still gets Sequence · Shape · Arrange · Browse: seen in the simulator with the SLOOP demo (`-demo`), not on a real SLOOP unit.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".
