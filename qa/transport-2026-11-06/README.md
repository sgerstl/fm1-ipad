# Top bar transport: tempo box from its button, hold PLAY to play from the start (2026-11-06)

Two changes in the iPad top bar (`ios/FM1/TopBar.swift`, `ios/FM1/TempoPanel.swift`), plus the driver call behind the second.

| Shot | What it shows |
|---|---|
| 00 | The tempo panel open, on the demo Skiff |
| 01 | The panel growing out of the readout, frames from a 59 fps simulator recording (left to right) |
| 02 | It shrinking back into the readout |
| 03 | Hold PLAY from stopped: "Playing from the start" under the key, every track on entry A, playhead at bar 1 |
| 04 | Hold PLAY while playing: the same, playing on |

## 1. The tempo box grows out of its button

It scales from 0.2 and fades in, anchored at the readout's middle over the panel's top edge, with a spring (0.25 s, bounce 0.12). It closes faster than it opens (ease-in, 0.15 s). With Reduce Motion it fades instead (0.15 s in, 0.1 s out). Only the transform and opacity animate. The panel's one shadow is on its plain background shape, so nothing re-blurs per frame.

From the recording: the open settles in about 0.29 s (frames 143–160) and the close takes about 0.14 s. The simulator dropped frames under load, so the first steps of the scale are thin in 01.

## 2. Hold PLAY: play from the start

Hold PLAY for half a second does Skiff's GLO + PLAY. A tap still plays or stops, as before.

**Over the editor protocol:** Skiff has no op for GLO + PLAY. TRANSPORT op 3 (RESTART) only restarts the patterns where they are; it doesn't call `song_top`. So `SkiffDriver.playFromStart()` does what the panel does (`ui_layer.c` `layer_play`, `bank.c` `song_top`):
- **SONG on or ONCE:** STOP, waiting until the audio has taken it; then LIST PLAY puts each track on its first entry (a stopped track goes straight there, `entry_go`); then PLAY.
- **SONG off:** RESTART while playing, PLAY when stopped (op 1 already plays a chain from its first part).

If a request goes unanswered partway, the session sends a plain PLAY.

**SLOOP:** its editor can't restart (LIVE op 1 only plays or stops), so the hold, the VoiceOver action and the shortcut aren't offered there.

**Finding it, since a hold can't be seen:**
- The VoiceOver action "Play from the start", and the hint "Hold to play from the start".
- ⇧Space.
- A pointer tooltip: "Tap to play or stop · hold to play from the start (⇧Space)".
- When the hold fires: a "Playing from the start" tag under the key for 1.6 s, a medium haptic, and a VoiceOver announcement.

**A bug found and fixed in the simulator:** I first built this as a Button with a long press beside it. Whether that Button fired on the release ending a hold changed from press to press. So a hold sometimes stopped what it had just started, and a flag meant to skip that release ate the next real tap. The key now uses a single press gesture: a release counts as a tap only if the hold hadn't fired and the finger stayed on the key. It sinks the way PressSink keys do. I checked these in the simulator: a tap stops, a hold from stopped plays and keeps playing, a tap after a hold stops, and a hold while playing restarts.

## Tests

- `PlayFromStartSimTests` (skiff-sim, `SKIFF_SIM=1`). With SONG on, T5 and T6 each get two entries and are put on the second. Play from start, both playing and stopped, lands every track with a list on its first entry and leaves it playing. With SONG off it restarts while playing and plays from stopped. Both pass.
- `PlayFromStartTests` (FakeSkiff, no sim): from stopped through the session, the hold plays from the first entries and is still playing 1.5 s later. Passes.
- The full SloopKit suite: 240 tests pass. The first run had one timing issue while six sessions loaded the machine; the re-run was clean.

## Pre-flight (design-standards)

- Tokens only: `look.surface(.held)`, `elevationShadow(.held)` and `Theme.text` for the tag, the same as the tempo panel. Nothing new. The tag is 13 pt semibold, on the panel's type ladder.
- Targets: the play key is still 44 × 44 pt. The tag doesn't take touches.
- Motion: an entrance spring of about 0.25 s, a faster exit, and fades under Reduce Motion. The tag fades in 0.15 s and out 0.12 s.
- States: disconnected, the key fades to 0.4 and ignores touches. On SLOOP the hold isn't there. The key sinks while pressed.
- The tag hangs below the bar for 1.6 s and covers part of the page under it (on Song, the bar-count stepper). It doesn't take touches, so nothing underneath is blocked.

## Not verified (needs Scott's hands)

- **A real FM-1 on Skiff 2.2:** hold PLAY with SONG on, playing and stopped. Do all tracks land on their first entries without an audible gap, beyond the STOP → PLAY the panel's own GLO + PLAY also makes? With SONG off, does it restart cleanly? With CLOCK on USB or TRS, does RESTART do nothing, as the firmware says?
- **The hold on a real iPad by finger** (only simulated touches here). Does 0.5 s feel right?
- **⇧Space** with a hardware keyboard: the simulator doesn't pass keys. Also check that typing a space in a text field (project name) still types a space.
- **VoiceOver:** the action, the hint and the announcement weren't run with VoiceOver on.
- **Reduce Motion:** the fade wasn't seen on screen.
- **Smoothness at 120 Hz on a real iPad:** the simulator was dropping frames under load.
- **The phone's top bar** (`PhoneAppView.swift`, not mine) has no hold yet.
