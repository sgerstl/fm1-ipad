# Accessibility pass, 2026-11-10

Branch `a11y-pass-2026-11-10`, cut from `perform-grid-map` at d19bbf1 (the Pads grid, track lanes, track head, disconnect card). Simulator only: nothing went to the iPad or the FM-1. Target: WCAG 2.2 AA, with EN 301 549 in mind because Lupe is EU-facing (the European Accessibility Act has applied since June 2025).

**In short:** I fixed 22 things that were clear and low risk (labels, values, traits, actions, modal focus, announcements, hidden elements VoiceOver could reach, the Pads grid's reading order). I left 16 for you because they change the look or need a design call. The biggest are: Lupe ignores Dynamic Type and Bold Text; dragging is the only pointer way to set knob columns, the Max editor size and bar ranges; and several outlines that carry meaning measure under 3:1. **The audit found no violations** is not what happened here, and it wouldn't mean "accessible" if it had. It raised 2,893 lines on 11 iPad screens; most come from one cause (fixed type sizes) or are false positives I checked against the screenshots. Every line is kept in `audit/`.

Device check for the morning: `qa/device-checks/2026-11-10-accessibility.md` (VoiceOver walk-through, the settings toggles, a keyboard).

## How it was checked

| Check | How | What it can't tell you |
|---|---|---|
| Automated audit | New UI test target `FM1UITests` (`ios/FM1UITests/AccessibilityAuditTests.swift`): `performAccessibilityAudit` on 11 iPad screens against the Skiff demo (`-demo -demo-skiff -no-intro`), one pass per audit type (a whole screen in one pass ran out of time). Every issue goes to the log and a TSV. Nothing is suppressed: the `accepted` list is empty, so the test fails while any issue stands. | Reading order, whether a label makes sense, gestures, announcements, keyboard, motion |
| Contrast | `contrast.py`: every token pair from `Theme.swift` and both firmware palettes, WCAG luminance, alpha composited. `measure.py`: re-measures each contrast line the audit raised, in the screenshot, inside that element's frame. | Anti-aliasing on thin text (the screenshot method under-reads it), states that weren't on screen |
| VoiceOver semantics | Code review of every gesture, overlay and live value (with a second reviewer for the files outside the Pads grid), plus the element trees the audit wrote (`audit/` has none; they're in the scratch run, the findings below quote them) | How it actually sounds and feels: that's the device check |
| Motion, transparency, contrast settings | Code review (`accessibilityReduceMotion` and friends) | Whether the result looks right |

Run it yourself:

```
cd ios && xcodegen -q
xcodebuild test -project FM1.xcodeproj -scheme FM1 -destination 'platform=iOS Simulator,name=<an iPad>' \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 CODE_SIGNING_ALLOWED=NO TEST_RUNNER_A11Y_OUT=/tmp/a11y \
  -parallel-testing-enabled YES -parallel-testing-worker-count 3
python3 qa/accessibility-2026-11-10/measure.py /tmp/a11y
```

About 6 minutes on three clones. Labs wasn't reached (the test opens Settings but couldn't find the Labs row by its label); Settings itself was audited.

## Fixed (on this branch, in small commits)

| # | What | WCAG | Where |
|---|---|---|---|
| F1 | A pad had two `.accessibilityValue` modifiers; only one is read, so a waiting pad's countdown ("starts in 3 beats") was never said. One value now: state, countdown, held scene. | 4.1.2 | `PadsPage.swift` pad |
| F2 | The selected pad and the selected track head say "selected" as a trait (the head had it as words in its name; the pad not at all). | 1.3.1, 1.4.1 | `PadsPage.swift`, `PadsTrackStrip.swift` |
| F3 | Pad labels name the track's number as well as its name (tracks 4 and 6 are both "Drum Kit" in the demo, so their pads read the same), and say "once" for one pass, not "1 times". | 2.4.6 | `PadsPage.swift` |
| F4 | **Reading order on the Pads grid (applied, not verified).** The element tree shows VoiceOver's raw order as all six heads, then the tool row, then the 16 scenes, and only then the pads, so a row's pads sit about 30 swipes from its head. I gave the grid one named container ("Pads") and sort priorities: tool row, then each head followed by its pads, row by row, then the scenes. The simulator's element tree after the change still lists the old order, and I can't tell from here whether that tree shows sort priorities at all. **Device check A1 settles it**; if the order hasn't changed, the fix is a restructure (one row view holding its head and its pads), which touches the layout, so it would be yours. | 1.3.2, 2.4.3 | `PadsPage.swift` (`rowOrder`) |
| F5 | The editor tab's VoiceOver adjust went backwards (swipe up closed it while its value said closed / half / largest). Swipe up now makes it larger. | 4.1.2 | `SongTab.swift` |
| F6 | **FM-1 disconnected:** the greyed, read-only page could still be pressed with VoiceOver (`allowsHitTesting` stops fingers, not VoiceOver's double-tap). Hidden from VoiceOver while held; the card stays readable. | 4.1.2 | `AppView.swift` |
| F7 | The disconnect and the reconnect are announced ("FM-1 disconnected. Plug it back in; nothing is lost." / "FM-1 back"); the card lost `.updatesFrequently`, wrong for a card that changes twice. | 4.1.3 | `AppView.swift` |
| F8 | Mute and Solo are toggles (VoiceOver: "switch button") with their state, and the compact row's Mute says which track ("Mute" six times before). | 4.1.2, 2.4.6 | `PadsTrackStrip.swift` |
| F9 | **Invisible buttons in VoiceOver's reach (partly fixed).** The Timeline's nine keyboard-shortcut buttons (Previous entry, Delete entry…) sat at one spot, 19 pt tall, opacity 0; their container was hidden but they were in the accessibility tree, and the audit flagged each as a target. `accessibilityHidden` on each button didn't remove them (SwiftUI seems to expose buttons that carry a keyboard shortcut regardless), so they're now zero-size and out of the keyboard's Tab order (`ShortcutOnly`); the same for the four other invisible Escape buttons (knob panel, menus, pool, tempo). A finger can't land on them any more; whether a VoiceOver swipe still stops on them is device check 22b, and the structural fix is P17. | 4.1.2, 2.4.7 | `SkiffArrange.swift` (`ShortcutOnly`), `KnobPanel`, `Menus`, `SongTab`, `TempoPanel` |
| F10 | Timeline's bar ruler was hidden from VoiceOver and its drag was the only way to start a bar range. It's an element now, with "Select bars" (the first 4 bars, then the section bar's steppers move it) and "Clear the bar selection". | 2.1.1 | `ArrangeLane.swift` |
| F11 | Timeline track head: its double-tap (track controls) had no VoiceOver action; the Pads head did. Added. | 2.1.1 | `ArrangeLane.swift` |
| F12 | Piano roll and drum grid: picking steps was only a drag, so the selection bar (Duplicate, Copy, Move, Transpose, Delete) was out of VoiceOver's reach. Each step has "Pick step" / "Unpick step" and reads "picked". | 2.1.1 | `PianoRoll.swift`, `DrumGrid.swift` |
| F13 | Firmware picker and offer card: modal for VoiceOver (it wandered onto the app behind the scrim) with a scrub to close, as the scrim's tap does. | 1.3.1, 2.4.3 | `FirmwareInstall.swift` |
| F14 | The install's end (done, failed, download failed) moves VoiceOver to the new screen. | 4.1.3 | `FirmwareInstall.swift` |
| F15 | The firmware rows' radio symbol was read by name as well as the row's "selected". Hidden. | 1.1.1 | `FirmwareInstall.swift` |
| F16 | The sampler opened from Browse dims the page but wasn't modal: now modal, scrub closes it. | 1.3.1, 2.4.3 | `AppView.swift` |
| F17 | The sampler's replace dialog was modal with no way out but its button: scrub closes it. | 2.1.1 | `SamplerPanel.swift` |
| F18 | The tempo panel is modal (it had the scrub but VoiceOver could leave it). | 1.3.1 | `TempoPanel.swift` |
| F19 | The presets panel: the scrub closes it (deliberately not modal: the track box stays live). | 2.1.1 | `PresetsPanel.swift` |
| F20 | The position readout's label changed eight times a second while playing. Now label "Position", the bar and step as its value, `.updatesFrequently` while playing. | 4.1.3 | `TopBar.swift` |
| F21 | Drum-lane and sample-zone picks on the edit pages relied on VoiceOver synthesising a tap at the element's centre (a zone can be 4 pt wide). Explicit activation. | 4.1.2 | `SkiffEditPages.swift` |
| F22 | The audit itself, as a test target that stays (rule 5's spirit: strict, no silent passes). | – | `ios/FM1UITests/`, `ios/project.yml` |

None of these changes the look. F4 (if it works), F9 and F10 change what VoiceOver and the keyboard reach, so the device check covers them first.

## Proposed: needs your call (severity, criterion, a fix)

Severity: **High** blocks a task for someone; **Medium** makes it hard; **Low** an annoyance or a near miss.

| # | Finding | Sev. | WCAG / EN | Proposed fix |
|---|---|---|---|---|
| P1 | **Lupe ignores Dynamic Type and Bold Text.** Every `Font.lupe` / `lupeNumber` is `fixedSize`, and the iPad draws one 1376 × 1032 canvas scaled to the screen. The audit raised 1,739 "Dynamic Type font sizes are unsupported" lines (60 % of everything it found): one cause. Only native Settings scales. | High | 1.4.4 (Zoom covers 200 % on iOS, so arguably met); **EN 301 549 11.7 (follow the platform's font-size settings)** is the one that bites for the EU | Stage it: (1) sheets, menus, panels and the firmware screens scale with `Font.custom(_:size:relativeTo:)`, capped with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`; (2) the dense grid (pads, lanes, editor) keeps fixed sizes but gets a Labs/Settings "Larger text on the grid" step (1.15, 1.3), since reflowing the canvas is a design job; (3) `legibilityWeight == .bold` maps `.regular`→`.medium`, `.semibold`→`.bold` in `LupeType`. Needs a structure decision for (2). |
| P2 | **Empty pads' outlines are 1.36:1** (`stepEmpty` #2A2A30 on the page; 1.0–1.2:1 on a lane tint). An empty pad is a button (it opens the New / Rest menu), so its edge is what says it's there. Known; the selected lane got `laneEdge`, the rest didn't. | High | 1.4.11 | Use `laneEdge` (#7C7C85: 4.70:1 on the page, ≥3:1 on every lane tint) for empty pads everywhere, or a new token `padEmptyEdge` #63636C (3.27:1 on the page, but 2.2:1 on the tints). |
| P3 | **Knob columns change only by dragging** for a finger (Shape, the sound panel, Mixer cards, the step inspector's LENGTH): a tap only focuses the column. VoiceOver is fine (adjustable, Open, Reset). | High | 2.5.7 | Keep the tap as is (your 2026-11-06 decision); add a long press (or a second tap on the focused column) that opens `KnobPanel`, which already takes taps on its arc and typed values. |
| P4 | **The Max editor size is reached only by dragging** the tab: its tap goes No grid ↔ Half, and Max ↔ Half. VoiceOver's adjust reaches it (F5). | Medium | 2.5.7 | Tap at Half goes to Max, at Max to No grid (a cycle); or a hold on the tab offers the three places. |
| P5 | **A bar range on the Timeline starts only by dragging** the ruler for a finger (F10 gives VoiceOver a way). | Medium | 2.5.7 | A tap on the ruler selects the 4-bar phrase under the finger (it now clears; clearing could move to a second tap). |
| P6 | **Sampler trim handles: drag only** for a finger (VoiceOver adjusts them). | Medium | 2.5.7 | Tap on the waveform moves the nearer handle there, or ‹ › nudge keys beside the handles. |
| P7 | **A waiting pad's base outline is 1.4–2.1:1** (track colour at 0.3) until its traced line comes round. On Half, where pads have no "Waiting" word, the faint outline is the only sign at first. | Medium | 1.4.11, 1.4.1 | Base outline at 0.7 opacity (≥3.0:1 for every track colour), or the word "Waiting" on Half's pads when there's room. |
| P8 | **Timeline blocks dim to 50 % while playing** (all but the playing and selected ones), taking their labels (dark on the track colour) to 2.2–3.0:1 in the screenshot. | Medium | 1.4.3 | Dim the fill only (keep the label at full contrast), or dim to 0.7. |
| P9 | **`textTertiary` (#71717A) is 4.02:1 on the page, 3.59:1 on panels**, under 4.5:1. Mostly disabled text (exempt), but some is information: note names on the drum edit page, "KEY UP" on the FM6 envelope, the firmware screen's "later" state, the fader's value at its minimum, the projects key's chevron. | Medium | 1.4.3 | Lift `textTertiary` to #85858E (5.31:1 page, 4.74:1 panel), or use `textSecondary` for the informative uses and keep tertiary for disabled. A token change, so yours. |
| P10 | **Clipped text at the default size:** a track head's entry on Half ("A · REST" → "A · R…" for Drum Kit), the pad menu's "Duplicate to next empty…". | Low | 1.3.1 (the words are lost on screen; VoiceOver still reads them in full) | Head: the name truncates before the entry; menu: allow two lines, or "Duplicate to next pad". |
| P11 | **Increase Contrast and Differentiate Without Colour aren't read.** No view checks `colorSchemeContrast` or `accessibilityDifferentiateWithoutColor`. State is already doubled in most places (see "Not colour alone"), so Differentiate is low; Increase Contrast would be the clean way to raise P2, P7 and P9 without changing the default look. | Low (Medium if P2/P7/P9 stay as they are) | EN 301 549 11.7 | A high-contrast token set: `Theme` values read from the environment when Increase Contrast is on (`stepEmpty`→`laneEdge`, `textTertiary`→`textSecondary`, outline alphas ×2). |
| P12 | **Full Keyboard Access can still reach the greyed page while the FM-1 is disconnected** (F6 covers VoiceOver; keyboard focus doesn't follow `accessibilityHidden`). | Low | 2.1.1, 4.1.2 | `.disabled(held)` on the page: it also dims standard controls a little more, on a page already faded to 45 %. Your call on the look. |
| P13 | **A waiting pad's outline traces round under Reduce Motion.** `DESIGN.md`'s structure map says "Reduce Motion: static". It's a progress line, not travel, so it may be fine. | Low | 2.3.3 (AAA), Apple's guidance | Your call: keep it (it's information) or show the dashed outline with the countdown word. |
| P14 | **Targets under 44 pt** (all over the 24 pt floor, so 2.5.8 passes): Half's rows (42), the phone's (40), the card's Mute and Solo (64 × 32), the compact row's (30 × 34), Timeline blocks at Half (19 pt tall; they pass 2.5.8 on spacing, the lanes are 40 apart). | Low | 2.5.8 passes; 2.5.5 (AAA) and Apple's 44 | Known exceptions in the structure map; the compact Mute/Solo could grow to 34 × 40 without moving anything else. |
| P15 | **The phone has no disconnect card**: it falls back to the full connection page. | Low | – (structure) | Bring board 42's option A to the phone, with F6 and F7. |
| P17 | **Keyboard shortcuts on hidden buttons stay in the accessibility tree** (F9). | Medium until checked | 4.1.2 | Move the Timeline's shortcuts off buttons: `.onKeyPress` on the lanes once they can take focus, or `UIKeyCommand`s on the hosting controller. A small restructure, and the keyboard behaviour should be retested by hand. |
| P16 | Wording: Patterns' hint says "Drag onto a track to add it"; the lane's Pick a pattern menu is the non-drag way. Sections say "hold to store"; VoiceOver has the action. | Low | 3.3.2 | Mention the non-drag way in the hint. |

## Not colour alone (1.4.1): what carries each state today

| State | Colour | Second channel | Verdict |
|---|---|---|---|
| Track identity | Track colour | The number (1–6) on every head and chip, the name | OK |
| Playing | Track colour fill | The pass bar; "Playing · pass 2 of 4" / "Pass 2/4" on full and Max pads (Half: the bar only); VoiceOver value | OK |
| Waiting (a launch) | – | The traced outline, its shape; "Waiting" on full pads | OK, see P7 for its contrast |
| The song's next | – | A thin outline and "Next" | OK |
| Selected pad | Track-colour outline | The outline's presence; the controls under it at No grid; VoiceOver trait (F2) | OK |
| Muted | – | Struck-through speaker; the chip goes from filled to outlined | OK |
| Solo | Amber fill | Pressed-in (inner shadow), a large lightness change (amber vs control grey) | OK |
| Mute or solo waiting | – | Dashed white edge and the countdown | OK |
| Mixer mute | – | Its LED dot and the word MUTE | OK |

## The audit's output (iPad)

The full run (11 screens) came after F1, F2 and F5–F8 and before F3, F4 and F9. Re-runs after them: Pads No grid (`audit/ipad-pads-nogrid-rerun.tsv`) and the Timeline after F9's final form (`audit/ipad-timeline-rerun.tsv`: hitRegion 22 → 11, the shortcut buttons gone from the audit, the 19 pt blocks left). Counts by screen and type, `audit/ipad-audit.tsv`:

| Screen | dynamicType | contrast | textClipped | elementDetection | hitRegion | description |
|---|---|---|---|---|---|---|
| Song › Pads, No grid | 228 | 99 | 19 | – | – | 1 |
| Song › Pads, Half | 196 | 68 | 18 | – | – | 2 |
| Song › Pads, Max | 112 | 44 | 13 | – | 2 | 1 |
| Song › Timeline | 190 | 88 | 44 | – | 22 | 2 |
| Mix | 84 | 40 | 14 | – | 2 | 1 |
| Sounds | 73 | 56 | 32 | – | – | – |
| A pad's hold menu | 231 | 112 | 24 | – | – | 1 |
| Connection menu | 203 | 60 | 18 | 44 | – | – |
| Settings | 1 | 1 | – | 47 | – | – |
| Projects | 7 | 3 | 2 | 45 | – | – |
| Firmware picker | 209 | 173 | 18 | 19 | – | – |
| Firmware installing | 205 | 1 | 18 | – | – | – |

What each kind turned out to be:

- **dynamicType (1,739):** P1, one cause. Not suppressed, because it's real.
- **contrast (745):** re-measured in the screenshots (`audit/ipad-contrast-measured.tsv`). About half measure over 4.5:1 in the pixels (for example the scene numbers at 6–7:1 and the track names at 9:1, flagged "failed"): the audit misreads text on Lupe's near-black and through the scaled canvas. Of the rest, most read near 1:1 because the element was covered or off screen when measured (pads under the track controls, piano-roll rows scrolled away, browser rows past the edge). The ones I confirmed by eye are P2, P7, P8 and P9; "Cancel waiting" is disabled when nothing waits (exempt). On the menu, picker and sheet screens most lines are the app dimmed behind the scrim (173 on the firmware picker alone): inactive by design while the modal is up, so not a contrast failure.
- **textClipped (220):** mostly false positives from the scaled canvas (it flags "Demo" and "Play song", which aren't clipped). Real: P10.
- **elementDetection (155):** only on screens with a sheet or menu over the app: the text behind the modal is visible but, correctly, not reachable. False positives by design.
- **hitRegion (26):** 11 were the invisible shortcut buttons (F9); 13 are Timeline blocks and "Add to track" at 19 pt (P14); two are the Mix FX header and the sound panel's send rows (19 pt tall, rows of their own; P14).
- **description (8):** unlabelled containers: the Pads grid (F4 makes it a container, so this one should go), the editor's 3,397 pt-wide scrolling strip, a 2 pt divider on Mix. Low; the next run will say whether they remain.

## Contrast from the tokens (`contrast.py`, full table in its output)

Passes: `text`, `textSecondary` and `textSecondaryRaised` on every surface (except `textSecondary` on `tones[3]`, 4.13:1, used for held things: check where); dark `onColour` numbers on every track colour (4.9–12.6:1); every track colour as text on the page (5.0–12.9:1); `laneEdge` on the page and every lane tint; the "next" outline (5.5:1).

Fails that matter: P2 (`stepEmpty` edges), P7 (colour at 0.3), P9 (`textTertiary`). SLOOP's blue (#287CFF) as text on a panel is 4.48:1, a hair under (used in the presets list for the track that owns a preset: Low). Fails that don't occur in use (listed so nobody rediscovers them): white on any track colour (Lupe uses `onColour` there), `control`/`tones` as boundaries (keys are identified by their labels, not edges, so 1.4.11 doesn't ask for 3:1 there).

## Needs a human (what automation can't tell you)

- **How VoiceOver sounds** across a whole set: whether the row order (F4) feels right, whether the pad label is too long to be useful mid-performance ("Track 1 Acid, entry A, pattern 01, 4 times, Playing · pass 2 of 4"), whether "waiting, starts in 3 beats" arrives in time to matter. Part A of the device check.
- **Whether F4's order holds.** It relies on SwiftUI sorting siblings across two side-by-side stacks; the simulator's element tree didn't show the new order, and it may never show sort priorities. VoiceOver on the iPad is the test (device check 1).
- **Full Keyboard Access:** focus visibility on Lupe's custom keys (no focus ring styling was written for them; the system draws its own), whether the pads can be reached at all, traps in the fan menus. Not checked here at all.
- **Switch Control and Voice Control:** not checked. Voice Control depends on visible names matching labels ("tap Mute track 2" works only because the label now says it; the key itself shows a speaker).
- **The iPhone:** only its Sequence screen was audited (see below); the phone's Pads, Timeline, Mix and Sounds need the layout bug fixed first, then the same test.
- **Motion settings**, how each looks with Reduce Motion, and Increase Contrast once P11 exists: Part B.
- Whether the fixes in F13–F19 trap or release focus the way they should when opened from the FM-1's own buttons.

## iPhone

The same test ran on an iPhone 17 simulator (`audit/iphone-audit.tsv`). **It only reached one screen.** On the phone, Lupe with the Skiff demo still shows SLOOP's tabs (Sequence · Shape · Arrange · Browse), not the structure map's Pads · Timeline · Mix · Sounds: `ui.songTab` is set only in the iPad's `AppView`, never in `PhoneAppView`. So the tests that tap Mix or Sounds stayed on Sequence, and the phone's Pads grid wasn't audited. That's a layout bug outside this pass, listed as a follow-up.

What it did see (Sequence, the connection menu, the firmware screens): 15–24 dynamicType lines a screen (P1); one contrast line a screen, the selected "Sequence" tab, which measures 10.7:1 in the screenshot (false positive); the firmware picker's other contrast lines are the app dimmed behind it. No hit-region or missing-label lines: the phone's keys are 44 pt and its piano roll reads step by step ("Track 1, step 1, on, C 3").

## Builds and tests

- SloopKit: `swift test`, 290 tests in 50 suites passed (none of the known flakes failed this time; SloopKit itself is untouched).
- The app builds for the simulator at every commit that changed it (each audit run built it); the final head built on the iPad and iPhone simulators.
- The audit test fails, on purpose, while any audit issue stands (nothing is on its accepted list). If that's too noisy for routine runs, add accepted lines with reasons, never an empty catch.

## Design gate

`design-standards` was loaded and its accessibility gate followed. The pre-flight checklist's visual items (grayscale, spacing, type ladder, tells, gold comparison) don't apply: nothing here changes how Lupe looks, and every change that would is under Proposed. Contrast was checked from the tokens and the rendered screenshots, in Lupe's one theme (it's dark only: `preferredColorScheme(.dark)`). `check-render.mjs` and `check-tells.sh` are for web pages and weren't run on a SwiftUI app.

## Files

- `README.md` (this), `contrast.py`, `measure.py`
- `audit/ipad-audit.tsv`: every issue the audit raised (screen, type, label, frame, description)
- `audit/ipad-contrast-measured.tsv`, `audit/iphone-contrast-measured.tsv`: each contrast line with the screenshot's own measure
- `audit/iphone-audit.tsv`: the phone's run
- `screens/`: each audited screen, landscape
- The test: `ios/FM1UITests/AccessibilityAuditTests.swift`
