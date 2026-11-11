# Device check: a11y-pass-2026-11-10, 2026-11-10

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; the branch merges to `main` only after it passes. Findings and the reasons behind each check: `qa/accessibility-2026-11-10/README.md`.

**Setup:** Skiff-Lupe 2.2 on the FM-1 · Lupe from branch `a11y-pass-2026-11-10` (cut from `perform-grid-map`, so the Pads grid is in it) · a song with patterns on at least three tracks and a scene stored in Lupe · headphones. VoiceOver on: Settings › Accessibility › VoiceOver, or triple-click the top button once Accessibility Shortcut is set to VoiceOver (do that first: it's the quickest way out if you get lost). VoiceOver basics: one tap reads, double-tap presses, swipe right/left moves, swipe up/down on a focused control adjusts it or picks an action (the rotor shows "Actions"), two-finger Z (scrub) goes back or closes.
**Back up first?** No. Nothing here writes the FM-1's flash. Check 6 starts a bar selection on the Timeline but applies nothing; check 9 opens the firmware picker and is cancelled, never installed.

## Part A: VoiceOver walk-through (about 10 minutes)

| # | Do this | You should hear / see | Backup | Result |
|---|---|---|---|---|
| 1 | VoiceOver on. Song › Pads, No grid, stopped. Touch a filled pad on the selected track's row. | "‹Track name›, entry A, pattern 01, 4 times, ‹state›, selected, button", then the hint. An empty pad: "…entry G, empty". Two tracks with the same name are told apart by number ("Track 4 Drum Kit…", "Track 6 Drum Kit…"). **The order:** touch track 1's head and swipe right: you should hear its Mute, Solo, then pads A, B, C… of track 1 before track 2's head. If you hear all six heads in a row, then the scenes, the order fix (F4) didn't take: write that. | – | ☐ pass ☐ fail: |
| 2 | Play, Launch at Bar. Swipe to a pad on another row and double-tap. Touch it again while it waits. | It waits (the outline traces round). Its value now includes "Waiting, starts in 3 beats" (or "next bar"). Before this branch the countdown was never read. | – | ☐ pass ☐ fail: |
| 3 | Touch a track head's Mute, then Solo, on two rows. | "Mute track 2, playing, toggle button" / "Solo track 2, off, toggle button"; double-tap: "muted" (or "mutes next bar" while waiting). Every row says its own track number. | – | ☐ pass ☐ fail: |
| 4 | Touch a track head (its name), then the selected one. | "Track 3, ‹name›, ‹what plays›" and on the selected one "selected" as VoiceOver says it, not as part of the name. | – | ☐ pass ☐ fail: |
| 5 | Find the editor's tab (the three chevrons, "Pattern editor, half, adjustable"). Swipe up, then up, then down twice. | Up: "largest", then stays at largest. Down: "half", then "closed". It used to go the other way round. | – | ☐ pass ☐ fail: |
| 6 | Song › Timeline. Find "Bar ruler" above the lanes. Swipe down to "Select bars" and double-tap. Then find the section bar's First bar / Last bar. | "Bars 1–4" bar appears; its steppers move the range. The ruler's value says "bars 1 to 4 selected". Undo it with the ruler's "Clear the bar selection" action. (Nothing is applied: don't press Duplicate or Clear.) | – | ☐ pass ☐ fail: |
| 7 | Timeline, a track head: swipe down through its actions. | "Show track controls"; double-tap shows them (the same as the double-tap on the head). | – | ☐ pass ☐ fail: |
| 8 | **The disconnect.** VoiceOver on, Song tab. Unplug the FM-1. Plug it back in. | VoiceOver says "FM-1 disconnected. Plug it back in; nothing is lost." Swiping finds only the card and the top bar, not the greyed page's pads. Plugged in: "FM-1 back", and the page is reachable again. | – | ☐ pass ☐ fail: |
| 9 | Tap the connection dot › Install firmware…. Swipe right past the last row. Then two-finger scrub. | VoiceOver stays on the picker (it doesn't wander onto the page behind). The scrub closes it. Nothing is installed. | – | ☐ pass ☐ fail: |
| 10 | Open the tempo panel (the BPM readout by the transport). Swipe past its last control; scrub. | Focus stays in the tempo panel; the scrub closes it. | – | ☐ pass ☐ fail: |
| 11 | Play. Touch the position readout by the transport. | "Position, bar 3, step 9, 120 BPM", read once, not chased every step. Stop: "Position, stopped, 120 BPM". | – | ☐ pass ☐ fail: |
| 12 | Song › Pads, Half. Open the editor and swipe through a step in the piano roll; open its actions. | A "Pick step" action. Pick two steps: the selection bar (Duplicate, Copy, Move, Transpose, Delete) appears and VoiceOver can reach it. Same on a drum track. | – | ☐ pass ☐ fail: |
| 13 | Hold a pad (VoiceOver: its "Entry menu" action), then the menu's Move to submenu. | The pad's menu, with Move to › Pad X: the non-drag way to rearrange. | – | ☐ pass ☐ fail: |
| 14 | Touch a scene. | "Scene 3, ‹what each track plays›" from the scenes Lupe has seen; an unseen one says "contents not seen yet". | – | ☐ pass ☐ fail: |

## Part B: the settings toggles (about 5 minutes, VoiceOver off)

Settings › Accessibility on the iPad. Change one, look at Lupe, change it back. Write what you see: these are findings, most of them expected to fail today.

| # | Turn on | Look at | Expected today | Result |
|---|---|---|---|---|
| 15 | Display & Text Size › Larger Text, slider to the right | Every tab, Settings, a pad's menu | **Nothing changes size** except Settings and Labs (proposed finding P1: Lupe's type is fixed). Note anything that clips. | ☐ as expected ☐ other: |
| 16 | Display & Text Size › Bold Text | The same | No change in Lupe's own type (P1). | ☐ as expected ☐ other: |
| 17 | Display & Text Size › Increase Contrast | Empty pads, the scene row, the grey lines | No change (P11: Lupe doesn't read it yet). | ☐ as expected ☐ other: |
| 18 | Display & Text Size › Differentiate Without Colour | Playing, waiting, muted, solo pads and keys | No change; check each state still reads without colour: playing has the pass bar, waiting the traced outline, mute the struck speaker, solo pressed in. | ☐ pass ☐ fail: |
| 19 | Motion › Reduce Motion, then relaunch Lupe | The intro; editor No grid ↔ Half; the sound panel; unplug for the disconnect card; a waiting pad | The intro is the reduced version; panels and the card fade instead of travelling; the play colours still fade (a colour change, allowed). The waiting pad's outline still traces round (P13: your call). | ☐ pass ☐ fail: |
| 20 | Motion › Reduce Transparency | Anything see-through | No change expected (Lupe draws no blur or glass). | ☐ as expected ☐ other: |

## Part C: a keyboard (only if one's to hand, about 5 minutes)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 21 | Settings › Accessibility › Keyboards › Full Keyboard Access on. In Lupe, Tab and the arrow keys through the Song tab, then Mix. | A visible focus ring on every control it lands on; you can get into the pads, the scenes, the editor and back out without getting stuck. Write where the ring is hard to see or where focus can't reach. | – | ☐ pass ☐ fail: |
| 22 | Keyboard: Space (play/stop), Escape on an open menu, the tempo and a sheet. | Space plays and stops; Escape closes each. | – | ☐ pass ☐ fail: |
| 22a | Song › Timeline, tap a block, then on the keyboard: ← → ↑ ↓, = and −, ⌥← ⌥→, Escape. (Stopped; don't press Delete.) | The selection moves between blocks and lanes, = and − change its passes, ⌥ arrows move it, Escape deselects: the shortcuts work as before. (Their hidden buttons changed in this branch, F9.) | – | ☐ pass ☐ fail: |
| 22b | VoiceOver on, Song › Timeline: swipe right through the whole page, top to bottom. | Write it if VoiceOver stops on an unnamed or invisible element, or on "Previous entry", "Delete entry", "Deselect" or similar (they're hidden keyboard shortcuts; F9, P17). | – | ☐ none ☐ found: |
| 23 | Unplug the FM-1 with Full Keyboard Access on; Tab around. | Note whether focus can still land on the greyed page (not fixed yet: P12). | – | ☐ note: |

**Not covered here** (needs the iPhone, a second person, or a later round): the iPhone walk-through (same checks, phone tabs: Pads · Timeline · Mix · Sounds); Switch Control; Voice Control ("tap Mute track 2" should work because the labels now name the track); Zoom at 200 %; a full VoiceOver pass of Mix, Sounds and the sound panel pages (the audit's findings for them are in the README).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device", and VoiceOver ones straight to "VoiceOver".

**Result, 2026-11-11:** Scott marked checks A–C passed on the iPad.
