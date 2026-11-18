# Messages audit, 2026-11-17

Every passing message Lupe showed before the messages rule (`design/DESIGN.md` › Messages: one component, two homes),
and where each one goes under it. Read from the code on 2026-11-17 (commit dbb6bba).

## What was wrong

- Undo left on three timers: 8 s (iPad step clear, iOS pad clear), 6 s (Android), while Android's core kept the undo 10 s.
- Two undo strips on the iPad (step clear at +132, pad clear at +72), different looks, both up at once.
- The iPhone set "Undo clear" after Clear all steps but never drew it.
- Refusals: until ✕ on the song (iPad top strip, iPhone over the scenes, Android at the foot), 6 s in the sound panel and
  the motion lanes. On the iPad Timeline the same refusal showed twice (the top strip and under the lanes).
- Android could show two refusals at once (the core's strip and the scene row's).
- Five radii (8, 10, 12, 14, 16), four surfaces (held, tones[2], control, panel), 12–15 pt, icons on some only.
- About half announced to VoiceOver or TalkBack.
- Motion from none to 0.3 s; Reduce Motion handled three ways.

## Where each goes

| # | Surface (before) | Apps | Kind | Under the rule |
|---|---|---|---|---|
| 1 | `undoToast` (AppView.swift) | iPad | Undo, 8 s | App strip, Undo |
| 2 | `ListUndoStrip` (ListUndo.swift) | iPad, iPhone | Undo, 8 s | App strip, Undo |
| 3 | `LostCard` (AppView.swift) | iPad | Disconnect | Stays (not a message); the iPhone gets the announcements |
| 4 | `RecordingKnobsBar` (AppView.swift) | iPad, iPhone | Ongoing | App strip, ongoing row |
| 5–8 | `RefusalLine` in `SongStrip`, under the Timeline's lanes, over the iPhone's scenes | iPad, iPhone | Refusal, until ✕ | App strip, refusal; shown once |
| 6 | SongStrip's unseen scene and lanes-apart lines | iPad | Ongoing | App strip, ongoing row |
| 8 | iPhone unseen-scene line | iPhone | Ongoing | App strip, ongoing row |
| 9 | `SoundRefusalNote` (Library.swift) | iPad, iPhone | Refusal, 6 s | Panel home, no timer |
| 10 | Motion-lane refusal (MotionLanes.swift) | iPad, iPhone | Refusal, 6 s | Panel home, no timer |
| 11 | "Playing from the start" tag (TopBar.swift) | iPad | Confirmation, 1.6 s | App strip, confirmation |
| 12 | `TakeOfferLine` (FreeTakePicker.swift) | iPad | Offer | App strip, ongoing row |
| 13 | `FreeTakeLine` (SkiffArrangeParts.swift) | iPad | Status, Undo | App strip |
| 14 | Drag hint (SkiffArrange.swift) | iPad | Control state | Stays |
| 15 | Announcement-only ("Duplicated", drop results) | iPad, iPhone | Confirmation | Stays (the animation is the visual) |
| 17 | `RefusalStrip` (RefusalStrip.kt) | Android | Refusal and confirmation, until ✕ | App strip; confirmations 4 s |
| 18 | `UndoStrip` (UndoStrip.kt) | Android | Undo, 6 s | App strip, Undo until the next edit |
| 19 | `LinkCard` (LinkStates.kt) | Android | Disconnect | Stays |
| 20 | Scene-row notice (PadsPage.kt) | Android | Refusal | App strip, refusal |
| 21–24 | Sound header "held here", lock banners, the ruler's Stop | Android | Control state | Stay |
