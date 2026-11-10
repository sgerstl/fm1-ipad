# The last system dialogs, converted: before/after (2026-11-10)

Scott: "Yes, convert them". The 12 `confirmationDialog` / `.alert` calls left in the app are gone (`grep` finds none).

| Was | Now |
|---|---|
| Library: Erase a user sound; Clear a sample slot | `AppMenu.confirm` at the finger: caption + red confirm + Cancel |
| PadsPage, SkiffArrange: the store's "Erase pattern…?", "Replace scene…?" | the same, opened where the finger last was (`TouchPoint`, a passive window recognizer) |
| SongSectionsPanel: SONG REC over a song | the same |
| ProjectsSheet: Delete | the same, in the sheet's own menu layer |
| ProjectsSheet: save first / stop before opening | a fan: Save, then open / Open without saving / Cancel, the question and what happens as its caption (no red: a safety copy is kept) |
| SkiffProjectSlots: Load | changes no slot holds: red confirm; otherwise a plain Load + Cancel |
| ProjectsSheet / TopBar name prompt, SkiffSaveViews Save sound, Skiff slot Save | `TextPrompt`: Lupe's name card at the finger, above the keyboard; red-outlined choice when it replaces something; a refusal shown in the card, which stays |
| SkiffSaveViews "Sound not saved" (information) | inline in the name card (no toast) |

Kept as system UI on purpose: the two `.sheet`s (Projects, Settings). They're full sheets of their own, not dialogs. No file picker is involved here.

New: `AppMenu.caption` (the fan's honest line), `AppMenu.confirm(…)`, `TouchPoint` / `TouchPointWatch`, `TextPrompt.swift`.

`capture.sh before|after`, `python3 diff.py`: every scene at rest identical (`diff-result.txt`). Before = 6983089 in a scratch worktree.
