# The Song tab's pattern editor: four fixes, 2026-11-06

Checked on an iPad Air 13" simulator (iOS 26.2) with the Skiff demo (`-demo -demo-skiff`), the song playing. The "before" shots come from `main` at 9bb8f6f. The simulator was left in portrait, so the landscape canvas is letterboxed and scaled down in every shot.

## 1. The selection bar moved off the velocity and motion lanes

- **Where:** on the Song tab the bar now sits in the pattern header's empty middle, under the divider's handle. Nothing over the grid is covered (`after-2-note-picked.jpg`; before: `before-5-…`, where it sat over CHORUS and REVERB).
- **Icon keys (SF Symbols):** Duplicate after (the primary, filled), Copy, Paste, Move earlier/later (← →), Transpose down/up a semitone (↓ ↑, not on kits), Delete, Cancel (Esc).
- **Targets:** each key is 44 × 44 pt to touch and 36 pt drawn. Each has a VoiceOver label and a `.help` tooltip for the pointer. The count ("1 note", "steps 1–4") stays as text.
- **The undo line** sits on the same row: what changed in words (it truncates first when the row is full), an Undo key (⌘Z), and ✕ when nothing is picked (`after-3-undo-line.jpg`).
- **Divider at its lowest:** the header row is a fixed 44 pt, so the bar fits whatever the split. The busiest case (steps picked, the undo line, "also on entry B", Make unique and the pinned toggle all on one row) also fits (`after-4-…`, `after-5-divider-lowest-steps-picked.jpg`).
- **Sequence (SLOOP):** the bar still floats over the grid's foot there, now with the same icon keys.

## 2. Follow is one toggle

- **Following:** "Follow", sunk, with its LED lit (`after-1-following.jpg`).
- **Pinned:** "Follow", raised, with its LED off and a pin icon and "pinned to D" inside the same key (`after-4-…`). Tapping it follows the song again. This was checked: the editor went back to entry A.
- **Tapped while following:** it pins the entry that's playing now. A toggle that does nothing when it's on felt broken. This is new behaviour, and easy to drop if Scott doesn't want it.
- **VoiceOver:** "Follow the song, on / off, pinned to entry D", with the toggle trait, plus the selected trait while on.

## 3. The "can't open" message, reworded

| Before | After |
|---|---|
| Entry D's pattern opens when the song stops | Entry D can't open while the song plays |
| Skiff edits the pattern a track is playing; going to entry D now would launch it. | Opening it now would make this track jump to D. |
| Stop · Follow | Stop and edit D · Follow the song |

Two departures from the brief's wording:
- **"Entry", not "Block":** the header, the pinned toggle and VoiceOver all say "entry D" one line above, so the message matches them. It's a one-word change if Scott prefers "block".
- **"Follow the song", not "Back to playing":** this matches the toggle it does the same thing as.

What each button does is unchanged.

## 4. The keyboard drawer's keys: taller, with wider light strips

The coordinating session confirmed this item means the keyboard drawer (Keyboard.swift, the rubber keys drawn from the photo of the FM-1), not the piano roll.

- **Keys:** 94 → 112 pt tall, top and bottom rows (`KeyboardDrawer.keyHeight`). The drawer grows by 36 pt and still clears the Song tab's pattern header (`after-6-keyboard.jpg`; before: `before-6-keyboard.jpg`).
- **Light strips:** 4 → 6 pt wide, and 38 → 46 pt tall to match the taller key. Lit, held and silent states are unchanged.
- **The piano roll is as it was on `main`:** 46 pt rows and plain note names. My first try made its note names into rubber keys. I reverted that once the coordinating session answered, so shots `after-1` to `after-5` still show it. They're for items 1–3 only.

## Tests

- **SloopKit:** `swift test` passed, 238 tests. A first run, while six sessions were compiling (load average around 1000), had 20 timing failures. The rerun was clean, and this change touches nothing in SloopKit.
- **The app:** builds with `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`. Without them the FM1 target tried x86_64 and couldn't find SloopKit.

## Design pre-flight

Ran it.
- **Tokens:** existing tokens and modifiers only (`raisedKey`, `latchedKey`, `LED`, `PressSink`, `Theme.*`). The rubber key reuses the keyboard's own colours.
- **Spacing:** 8 pt between keys, 16 pt between groups.
- **States:** pressed (PressSink), disabled (Follow with no entry), latched.
- **Targets:** 44 pt.
- **Not colour alone:** following is shown by sunk vs raised, the LED, and the "pinned to D" text.
- **Motion:** none added.
- **Taste anchor:** the data-dense tool, so the chrome got quieter (icons instead of words) and the grid's foot is clear.

Not checked:
- the `check-render` and `check-tells` scripts (they're for web pages, not SwiftUI);
- the drum grid in the Song tab (same code with `notes: false`; the tap to switch tracks didn't land in the sim);
- pointer hover and keyboard focus;
- a VoiceOver pass by ear;
- the light look;
- Dynamic Type.

## For Scott's hands (a real FM-1 or iPad)

- Try the icon keys by finger: are they clear without words? The tooltips show only with a pointer.
- Check that "Stop and edit D" stops the song and opens D on the FM-1, as Stop did before.
- Do the taller drawer keys and wider light strips feel close to the FM-1's own keys?
