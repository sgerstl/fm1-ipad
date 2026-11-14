# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (the clock reference, launch countdowns, the readout)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

This sheet covers the **core** side of Scott's play test on b698317 ("the bar counts don't really work"; the iPad's
outline timer on waiting pads, Mute keys and scenes). The core now publishes a `clock` area and the pulse each waiting
thing lands on (`android/core/Sources/PhoneCore/ClockArea.swift`). P2 draws from them, so these checks need P2's side.

**Setup:**

- FM-1 on Skiff 2.5.1, on the Pixel's USB port.
- This branch merged into the combined one, with P2 reading `clock`, the rows' pass ticks and the launch ticks.
- Real core, writes allowed (`--ez allowWrites true`).

**Back up first: no.** Scott, 2026-11-14: "nothing on the FM-1 matters now". These checks launch pads, mute tracks and
recall a scene. Nothing writes the FM-1's flash.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Press PLAY and watch the playing pads' bars for a minute. | Each bar moves smoothly, not in jumps, and reaches its end as the FM-1's pattern comes round. It doesn't drift over the minute. | No | ☐ pass ☐ fail: |
| 2 | LAUNCH on LOOP. While playing, tap another pad on track 1. | An outline draws round the pad from its top left corner, counter-clockwise, and closes as the FM-1 switches to that pattern. | – | ☐ pass ☐ fail: |
| 3 | LAUNCH on BAR. Tap another pad. | The outline closes on the next bar line, when the FM-1 switches. | – | ☐ pass ☐ fail: |
| 4 | While playing, press a track's Mute key. | The outline draws round the Mute key and closes as the track goes quiet on the FM-1. | – | ☐ pass ☐ fail: |
| 5 | Solo a track while playing. | The outline draws on the Solo key until the other tracks have muted. | – | ☐ pass ☐ fail: |
| 6 | Recall a kept scene while playing. | The outline draws round the scene key and closes when the last of its tracks comes in. | – | ☐ pass ☐ fail: |
| 7 | Stop. Start the FM-1 with its own PLAY, then connect the phone while it plays. | Waiting things show a dashed outline (no clock yet). After the next Stop and Play, the outlines draw as in check 2. | – | ☐ pass ☐ fail: |
| 8 | Loop mode, a track on a 1-bar pattern that plays 4 times, selected. Watch the readout. | The bar counts 1 to 4, then starts again at 1. It doesn't keep counting up. | – | ☐ pass ☐ fail: |
| 9 | Song mode. Play past the end of the song. | The bar counts to the song's last bar, then starts again at 1 as the song comes round. | – | ☐ pass ☐ fail: |
| 10 | Once mode. Play to the end. | The bar counts to the song's last bar and stays there. | – | ☐ pass ☐ fail: |

**Not covered here:**

- Tempo changes while a countdown runs: a new clock reference comes every beat, so it should correct within a beat.
  Not tried.
- An external clock (the FM-1 following another device): the rate is taken from the FM-1's BPM, which may not be the
  incoming clock's. Not tried.
- VoiceOver and TalkBack: at the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".
