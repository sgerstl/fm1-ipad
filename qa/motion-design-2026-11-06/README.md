# Touch editing for motion lanes: design round, 2026-11-06

Scott: "I'm not sure how to edit motion. When I add a reverb lane to a track I don't know how to edit it. I would like to do it with touch."

**Canvas:** [Lupe motion lane editing](https://claude.ai/artifact/AfJdG7fXUqDkg52g8FCaWC) (private). It holds six boards with notes beside them. Nothing is built: Scott picks first.

## What's wrong today

`ios/FM1/MotionLanes.swift`, as it is in `qa/motion-lanes-2026-11-05/`:

- **No hints.** Nothing on screen says a lane takes touches. The gestures (tap an empty step, drag a point, hold for the menu) are documented only in part, in the Motion chip's key.
- **Too short to drag.** A lane is 28 pt, so 0–127 gets about 16 pt of travel.
- **Grab zones overlap.** A point's grab zone (±22 pt) is taller than its lane.
- **Hold vs lock is hidden.** You only reach it through a 500 ms hold menu.
- **Almost no non-drag path.** The only one is VoiceOver's adjustable action.

## The approaches

- **A · Tap a lane, it opens into an editor (recommended).**
  - The lane opens in place, 140 pt tall. The piano roll squeezes to 3 rows above it, and the divider rises about 120 pt.
  - Draw across steps to paint. Drag a point to move it. Tap a step to set it there.
  - A header holds the value readout, − / +, the Hold / Lock switch, ⋯ and Done. One line under the plot says what the gestures are and what the lane costs in the shared 64.
- **B · A Motion view.** A Notes | Motion switch turns the whole pattern area into one lane at full height (about 290 pt). The notes shrink to ticks along the top. The gestures are the same as A.
- **C · Step first.** You edit in the step inspector's "Motion at this step": a value bar, − / +, Hold / Lock and Delete. The lanes only show; tapping one selects its step.

## Pick: A, with C's inspector rows as the precise path

- **A edits where you look.** You get almost a point per value, the notes stay in view for timing, and painting is the touch gesture Scott asked for.
- **B hides the notes and adds a mode.**
- **C is precise and accessible, but it isn't touch editing.**
- **A is the biggest build of the three.**

## Rules for every approach

- **Editing needs Stop.** Skiff loads each entry's motion when the entry starts, and it refuses writes while playing (rc 3). Lupe says so above the lanes before you touch them. An open editor dims and shows Stop in its header.
- **Hold is the default; a lock (◆) is that step only.**
- **A stroke writes only where the value changes from the step before.** A flat stroke costs one record, plus one to put back what played after it. The readout counts the cost while you draw, and the stroke stops at the 64 limit.
- **Every drag has a tap path (WCAG 2.5.7).** Each lane is one adjustable VoiceOver element with actions. Reduce Motion opens the editor without the animation.

## Open questions for Scott

These are also on the canvas:

1. A, B or C.
2. Should a stroke ever write locks?
3. Should the divider rise when a lane opens?
4. Should painting snap?

Not covered: iPhone and drum tracks.

## How this was made

- **Reference:**
  - `song-tab-today.jpg`, a simulator screenshot of today's Song tab (Look iPad, demo session);
  - the 2026-11-05 QA shots;
  - colours from `tokens/tokens.json` and `ios/FM1/Theme.swift`;
  - the demo's T1 colour (#FF5A36).
- **Design gate:** the `design-standards` pre-flight ran on the boards, rendered locally. What it found and what wasn't checked is in the hand-off below.

## Hand-off

- **Checked.**
  - Contrast on the dark theme:
    - track line on the well: 6.1:1;
    - header text: 8.7:1;
    - axis labels: 7.4:1;
    - annotation pins: 6.7:1.
  - Targets in the mockups are 44 pt keys and 36 pt full-width lanes.
- **Not checked, because these are static mockups.**
  - Light theme: the app has none.
  - Touch feel on a device.
  - A real VoiceOver pass.
  - The divider's behaviour.
- **The checker's "horizontal scroll" BLOCK is expected.** It comes from the fixed 1376 pt device frames, not from a page.
