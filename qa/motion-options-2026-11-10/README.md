# Motion and touch options cleaned up (2026-11-10)

Scott's answers to the proposal (shared notes, 2026-11-10-motion-options-cleanup.md):
1. **Settings › Touch** (new, for good): Hold before a menu (slider, seconds), Slide for a full turn (Fine 360 / Normal 240 / Quick 160 pt), Confirm before clearing a pad.
2. **Merged**: the divider's speed and bounce became **Editor divider: Snappy / Balanced / Bouncy**; menu opening and closing became **Menu speed** (closing follows at ⅔); the two pad-drag distances became one.
3. **Cut and fixed**: track-controls gap 8 pt (only read at Max, where the controls no longer show), grid pan start 10 pt, editor flick 700 pt/s.
4. **No review dates** on the Labs rows.

**What Scott had tuned carries over.** I copied the preferences off his iPad: `labs.dividerDamping 0.86`, `labs.holdToMenu 0.3`, `labs.padPlayFade 0.4`.
- Hold and fade keep their keys, so they carry over as they are.
- **Balanced is his divider feel exactly** (response 0.38, bounce 0.86). Snappy is 0.30 and 1.0 (no bounce); Bouncy is 0.46 and 0.62.
- Before any pick, the divider takes the feel nearest a saved bounce.
- `Labs.migrate()` runs at launch: an old pad-drag distance moves to the merged key when only it was set; an old menu-closing time sets Menu speed when that wasn't set; the cut keys are removed.
- Tested in the simulator with his values plus an old pad-drag distance of 14: all showed and carried.

Diff: every scene at rest identical (`diff-result.txt`; before = the 1ab8c4c captures). Settings changed as intended (not in the capture set).

New labels: Hold before a menu · Slide for a full turn · Editor divider · Menu speed · Switch between Pads and Timeline · Pad colour fade on play · Hold before painting notes · Pad drag: move before it lifts · Pad drag: press before sliding.
