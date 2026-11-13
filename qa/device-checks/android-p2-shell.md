# Device check: android-p2-shell (claude/android-p2-shell-02c86f), 2026-11-13

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel 10 Pro; the branch merges to `main` only after it passes.

**Setup:** no FM-1 needed. This is the Compose shell on a fake core (`FakeLupeCore`, replaying provisional fixtures). Build and install with the Pixel connected over USB (USB debugging on):

```bash
cd ~/code/fm1-ipad/.claude/worktrees/android-p2-shell-02c86f/android && ./gradlew :app:installDebug
```

Or, with adb directly: `adb install -r android/app/build/outputs/apk/debug/app-debug.apk`. Start a scenario straight away with `adb shell am start -n com.scottgerstl.lupe/.MainActivity --es scenario lost` (also `searching`, `wrongFirmware`, `ready`).
**Back up first?** No. Nothing here talks to the FM-1.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open Lupe. | About two seconds of "Looking for your FM-1", "Found it", "Reading", fading into the shell. Top bar: Demo ⌄, Bar ⌄ "1 waiting", REC, Play, readout 1·1 / 120 BPM. Pads · Timeline · Mix; Pads over the Editor placeholder, the divider between. Compare with board 53 (`design/boards/phone-portrait/board-53.png`). | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 2 | Drag the divider handle up, then down past split to the bottom. Release at different heights. | It follows the finger, then settles into the nearest of top only, split, bottom full (300 ms glide, a tick on settle). Top only: the bottom half is gone. Bottom full: the tabs become a strip, the Editor fills the rest. Compare board 54. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 3 | Tap the handle three times. | Steps top → split → bottom → split, animated. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 4 | Tap Timeline, Mix, Pads. | The chosen tab lifts (150 ms blend) and the placeholder cross-fades. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 5 | Tap Play, wait two bars, tap again. Tap REC twice. | Play goes white and its ▶ becomes ■; the readout counts beats at 120 BPM (1·1, 1·2 …), and "1 waiting" drops away on the next bar. Stop returns to 1·1. REC fills red with a dark dot, then back. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 6 | Tap Bar ⌄. Choose Beat. Re-open it. | A menu grows out of the key; the tick moves to Beat and the key reads "Beat". Back button closes a menu. "Cancel waiting" shows only while something waits. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 7 | Tap the readout. Tap +10, −1, then Song, Once. | Tempo and the readout change; the tick follows Loop · Song · Once. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 8 | Tap Demo ⌄. Choose "Bottom: ENV page", then "Bottom: editor". | The FM-1 menu has Projects…, Settings and Labs greyed ("not built yet"). The bottom half cross-fades between Editor and "ENV · ENV" (the slot follows the FM-1's page). | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 9 | Demo ⌄ → Play "lost". Wait. | After 1.5 s the page fades grey and a card drops from under the top bar: "FM-1 disconnected", the cable line, a moving bar. Touches on the page do nothing. At 6 s the line blends to "Back · reading the FM-1"; at 7.5 s the card lifts away and the page returns to colour. | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 10 | Demo ⌄ → Play "searching", then "wrongFirmware". | Searching: a full page, "Looking for your FM-1", a moving bar. Wrong firmware: "This FM-1 isn't running Skiff … reports SLOOP 2.8.4", Try again (it replays "ready"). | – | ☑ pass: Scott, 2026-11-13 ("looks good" on the Pixel) |
| 11 | Turn on Settings › Accessibility › Remove animations, restart Lupe, repeat checks 2, 4 and 9. | Nothing slides or grows: the divider, tabs, menus and the lost card cross-fade instead (about 150 ms). The moving bar stands still. | – | ☐ pass ☐ fail: |
| 12 | Turn on TalkBack. Swipe through the top bar, the tabs and the divider. On the divider use the actions menu. | Every control is named: "Play", "Record, switch, off", "Launch quantize, Bar, 1 waiting", "Pads, tab, selected" … The divider reads "Divider between the top and bottom halves, Split" and offers Top only / Split / Bottom full. While the lost card shows, the page behind is skipped. | – | ☐ pass ☐ fail: |
| 13 | Rotate the phone. Pull the back gesture from the side edge. | The app stays portrait. Nothing in Lupe sits at the side edges (back gesture works); the bottom gesture bar is clear. | – | ☐ pass ☐ fail: |

**Not covered here:** the real FM-1 (P1 brings the core; the link states here are scripted), the Pads, editor and sound pages (placeholders, P3 and P4), animation hitches (the Pixel is the only place to see them; I could only check on a slow emulator), TalkBack in practice (I read semantics, I didn't listen), a font scale above 130%, and the status bar height on the Pixel (the body starts below the real inset, so it may sit a few dp off the boards).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device" (VoiceOver: release pass; on Android, TalkBack gets the same pass).
