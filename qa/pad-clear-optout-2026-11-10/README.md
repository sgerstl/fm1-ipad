# Pad clear: "Don't ask again" (2026-11-10)

Scott: "i want the option to check a box and not have to confirm clearing a pad every time."

- The confirm for clearing one pad (asked only when the pad's pattern is used nowhere else, since it's erased with the entry) has a **Don't ask again** box: a real Toggle (`CheckBox` style), 44 pt row, VoiceOver hint "Clears pads without asking, erasing a pattern nothing else uses. Turn back on in Settings". It takes effect when the confirm is tapped; Cancel leaves the setting alone.
- **Settings › Confirm before clearing a pad** (`confirmPadClear`, default on) is the way back, with a footer saying what Off does.
- Only one pad's clear. Clear all pads, Clear pattern, Clear N unused and Delete project still ask.
- A pad clear whose pattern is shared never asked and still doesn't.

**Undo: none.** A pad clear goes straight to the FM-1 (LIST CLEAR), not through the Timeline's rewrite, so it isn't on Lupe's undo stack. And the stack holds the lists only: SkiffSongStore.undo says "a pattern a change erased can't come back". Undoing an erased pattern would mean reading its steps before the clear and writing them into a new pattern after, not a cheap addition. So with the box ticked, a mis-tap on Clear entry loses that pattern for good.

Diff: every scene at rest identical (`diff-result.txt`, before = 18a29e4). Settings has the new section (an allowed change, not in the capture set).
