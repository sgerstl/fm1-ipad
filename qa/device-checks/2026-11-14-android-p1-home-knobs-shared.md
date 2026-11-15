# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (HOME's four knobs read from SloopKit)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

The reading of HOME's four knobs, and the write that turns one, moved from the Android core into SloopKit
(`DeviceSession.homeKnobs`, `setHomeKnob`), so the iPhone can use the same code. The Android phone gets the same
data as before, built from the shared code. Nothing should look different.

**Setup:** FM-1 on Skiff 2.5.1. Pixel on this branch merged into the combined one, real core, writes allowed.

**Back up first: no.** Check 2 turns one sound parameter on the selected track, in memory only.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | FM-1 on HOME, an ANALOG track. Turn the FM-1's KNOB 1. | The phone's four read CUTOFF, RES, ATTACK, RELEASE with the FM-1's numbers; CUTOFF follows and its card lights. | – | ☐ pass ☐ fail: |
| 2 | Slide the phone's RES. | The FM-1's RES follows. | – | ☐ pass ☐ fail: |
| 3 | Hold a step that has a lock on one of the four (or skip if none). | That knob shows the step's value, marked locked, as before. | – | ☐ pass ☐ fail: |

**The iPad:** nothing to check. The iPad app doesn't call the new code; it keeps its own HOME knob table
(`ios/FM1/TrackControls.swift`). SloopKit only gained code.

**Not covered here:**

- The iPhone's screen for the four knobs: that session writes its own check.
- VoiceOver: at the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
