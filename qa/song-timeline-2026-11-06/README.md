# Song tab timeline, 2026-11-06

Scott's list, the Song tab's upper half (Skiff). Code: `SkiffArrange.swift`, `SkiffArrangeParts.swift`, `TrackControls.swift`; one line each in `AppView.swift` (the popover overlay removed) and `MixerPanel.swift` (PATTERN no longer opens a popover).

## What changed

1. **Mute from the lane headers.** The chip mutes, as SLOOP's Song tab did. On the selected track a tap mutes and unmutes. On another track it selects, so a stray tap can't mute a track you weren't on.
   - Muted shows three ways: the chip goes grey with a line of the track's colour, a crossed speaker leads the name, and LEVEL reads 0.
   - VoiceOver: each chip is a real mute switch (Toggle semantics, on/off) on every lane, so muting another track is one action. The name beside it selects.
2. **The track knobs sit in the timeline.** The popover and its key are gone. LEVEL, STEPS and PAN of the selected track sit in a small grey box at the timeline's right end, just under its lane. On the last lanes it goes above, so it never leaves the lanes. No header, no title.
   - A knob turns on a vertical slide from the first touch: the whole range in about 200 pt, finer as the finger moves sideways. A tap opens the big control (the way without a drag, 2.5.7), and a double-tap resets.
   - VoiceOver: adjustable, plus Open and Reset to default, as before.
   - **SWING is left out.** It sets every track, so in a box under one lane it would read as that track's. It stays on the Mixer's Global card.
   - **Scroll:** the box sits outside the lanes' horizontal scroll, and the top half doesn't scroll vertically, so the slide takes nothing from a scroll.
   - The box steps aside while a pattern or block is being carried, so drops reach the lane.
   - **PATTERN on the FM-1** lights the box with the usual flash ring. The SEQ pad's TRACK page does the same, through the old `trackControlsOpen` flag, which now only lights the box.
3. **↻ in Loop entry.** In Loop entry, playing or stopped, every block shows ↻ in place of ×N; chains show "chain ↻". VoiceOver says "loops" instead of "N times". Play song and Play once show ×N as before.
   - **Narrow blocks show their count.** On short lanes the line reads "B · 05 ×2". A narrow block puts its count under the label where the lane has room for two lines, and after it where it doesn't. The text shrinks before it's cut. On tall lanes, narrow blocks get a count line under the pattern.
4. **Patterns drawer:** a › button, 44 pt, left of the "Patterns" title, closes the drawer.
5. **Playback hint:** "Loop entry: each track repeats the block it's on. Play song: each track plays its blocks in order and starts over. Play once: plays through once and stops."
6. **Hold PLAY to play from the start: skipped.** The Song tab's play key is in `TopBar.swift`, which another session owns.

## Screenshots (iPad Air 13", demo Skiff, stopped)

- `knob-box.jpg`: Play song, track 1 selected. The box sits under lane 1. Narrow blocks show "03 ×1".
- `muted-loop-entry.jpg`: track 1 muted (grey chip, crossed speaker, LEVEL 0). Loop entry is on, and every block shows ↻.
- `slid-level-drawer.jpg`: after a 100 pt slide up on LEVEL, the track is unmuted, since turning LEVEL unmutes as on the FM-1. LEVEL reads 50. The Patterns drawer is open with its close arrow. The arrow then closed it.

## Checked

- The app builds. SloopKit tests: 238. One timing test (`editsFromTheIPadReachTheDeviceAndStick`) timed out during the full run with the Mac's load average near 1000. It passed on its own. The changes are app-only.
- On the simulator: chip mute, ↻ in Loop entry, the LEVEL slide, the drawer arrow. These were checked by tap, swipe and screenshot.

## Not checked

- **Against skiff-sim.** The iOS simulator app doesn't see skiff-sim's port (that needs *My Mac (Designed for iPad)*), and another session's skiff-sim held the "Felucca" port. These screenshots use the demo Skiff (FakeSkiff). Mute and LEVEL go through the same `session.set` paths as before.
- Narrow blocks on short lanes (8 tracks, the divider low), the box above the last lane, and PATTERN's flash on the box.
- Playing state and VoiceOver, by hand. Reduce Motion doesn't apply: nothing new animates.

## For Scott's hands (real FM-1)

- Tap the selected track's chip: the FM-1 mutes and unmutes that track.
- Slide LEVEL, STEPS and PAN in the box: the FM-1 follows.
- Press PATTERN: the box lights.
- Switch to SONG OFF on the FM-1: the blocks turn to ↻.

## Findings left standing

- The box covers the right end of the lane below it, about 290 × 52 pt. With the default zoom that's usually past the song's end. In `knob-box.jpg` it covers the end of Pad's E block, which is still tappable to its left. If that's in the way, the alternative is to open room under the selected lane, which makes the lanes jump on every selection.
- `EditorUI.trackControlsAnchor` (FM1App.swift) is now unused. It was left alone to keep shared files untouched.

Design pre-flight ran:
- Grayscale: the muted state survives without colour (icon, chip shape).
- Spacing is on 4/8. Type is 11/13 at regular and semibold.
- Tokens: `look.surface(.held)`, `textSecondaryRaised` for labels on the raised box, and `tones[3]` for a knob being turned.
- All targets are 44 pt.
- Contrast: labels use the raised secondary token, which measures 6.1:1.
- Taste anchor: data-dense tool.
- Not run: check-tells and check-render, which are web-only, so they have no files to read in a SwiftUI project.
