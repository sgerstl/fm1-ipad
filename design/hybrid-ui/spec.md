# Lupe hybrid UI: build spec

Status and the decided-versus-proposed split: `README.md`. Colours are named by `Theme` (iOS) as in `tokens/tokens.json`. Sizes are points at 1x. "Track colour" and "track tint" mean the row's own Skiff colour and its 24 % tint, as today.

---

## 1. Principles: the four mechanisms

1. **Shape carries state, alongside colour.** A playing pad is a full pill; an idle pad is a 10-radius card. A selected badge, scene or segment squares off; unselected ones are round. State never rests on colour alone (WCAG 1.4.1), and shape is the second channel.
2. **Size sets priority.** One white-key primary per view (Stop or Play in the header; Done in a sheet), and it's the largest solid control. Secondary actions are grey pills, tertiary ones outlined.
3. **Containment groups like with like.** Related controls touch as connected groups (tabs, Mute/Solo, pagers, zoom). The scenes sit in one floating toolbar, and panels and sheets are surface steps, never borders.
4. **Motion explains cause and effect.** Spatial changes (shape, size, position) travel on a spring with a little overshoot; effects (colour, opacity) ease out and never bounce. Nothing pops (`DESIGN.md`).

What stays Lupe's: the near-black page and the grey ladder (`page`, `well`, `panel`, `control`, `lifted`, `held`), **no brand accent** (the primary is the white key, `Theme.text` with `Theme.onColour` ink), Barlow for words and Barlow Condensed for numbers, the six Skiff track colours as the only colour on screen, and `DESIGN.md`'s motion, corner and confirm-in-place rules.

---

## 2. Tokens

### 2.1 Colour roles (all existing tokens)

| Role | Theme / token | Used for |
|---|---|---|
| Page | `page` | Screen background |
| Well | `well` | Grids, lanes, graphs, the minimap's ground |
| Panel | `panel` | Sheets, docked panels, the scenes toolbar, Mix strips, menus' parent cards |
| Control | `control` | Idle pads, track heads, unselected segments, Mute, lane fills |
| Lifted | `lifted` | Queued pads, grey (tonal) buttons, the selected rail item and menu row, Record |
| Held | `held` | Menus, popups, the app strip (`Elevation/3 Held`) |
| Primary key | `text` fill, `onColour` ink | Stop or Play, the selected tab, segment and scene, Done, switch on |
| Text | `text`, `textSecondary` | Labels and values; secondary on `page`, `panel`, `control`, `lifted` |
| Text on held | **`textSecondaryRaised`** | Any secondary text directly on `held` (`textSecondary` is 4.13:1 there) |
| Edge | `primaryEdge` | Empty pads, outline buttons, the switch's off edge, dashed rests |
| Divider | `disabledOutline` | Decorative only (1.98:1): settings rows, grid row lines at 50 % |
| Destructive | `recText` | Confirm-in-place outline and label |
| Record | `rec` | The Record dot |

### 2.2 Proposed new tokens

In `tokens-proposal.json`. Short version:
- `radius.sheet = 24`: the sheet's top corners and docked panels. Lupe has only `panel` (14) for containers today.
- `radius.pill`: half the height. Used for buttons, keys, playing pads and the selected tab.
- `radius.pad = 10`: the idle pad (the kit already has `radius/pad`). `radius.key = 8` stays for inner connected corners and app-strip keys.
- `shape.*`: the shape-as-state pairs, so code reads the rule, not a number.
- `motion.*`: starting values only. **Labs first, tokens when settled** (repo `CLAUDE.md` rule 3).

### 2.3 Type (existing faces; sizes as drawn)

| Use | Face, weight, size |
|---|---|
| Sheet and panel titles | Barlow SemiBold 19–21 |
| Tab, button, menu row | Barlow Medium 16 (selected or primary: SemiBold) |
| Track name, list item | Barlow Medium 14.5–16 |
| Secondary line | Barlow Medium 12–13 |
| Readout | Barlow Condensed Bold 26, its line under it Barlow Medium 12 |
| Pad value | Barlow Condensed Bold 21; the word "Rest" Barlow SemiBold 14 |
| Badge number | Barlow Condensed Bold 18 (phone row) or 15 (Mix strip) |
| Tile value | Barlow Condensed Bold 24 with the unit in Barlow Medium 12 |

Two weights per view, as `DESIGN.md` says. `LupeType.scale` already lifts Barlow about 7 % against SF Pro; these sizes are the drawn ones.

---

## 3. Components

The Figma names are in brackets.

### 3.1 Pattern pad [`Hybrid · Pad`]

Same states as `pattern-pad.md` S-list. Only the drawing changes. 76 × 43 on the phone (fills its column), 44 tall on the iPad.

| State | Fill | Edge | Radius | Ink | Extra |
|---|---|---|---|---|---|
| Playing | track colour | — | pill | `onColour` | Progress bar 4 tall, `onColour` at 55 %, grows across the loop; pass count "×4" |
| Queued (next) | `lifted` | 2 pt track colour | `radius.pad` | `text` | "Next" in Barlow Medium 10 |
| Idle (has a pattern) | `control` | — | `radius.pad` | `text` value, `textSecondary` letter | |
| Rest | `control` | — | `radius.pad` | `text` | The word "Rest" in Barlow SemiBold 14 |
| Empty | none (track tint on the selected row) | 1 pt `primaryEdge` | `radius.pad` | `textSecondary` letter | Edge 5.67:1 on `page`, which answers the A11 problem (1.36:1 today) if adopted |
| Selected (iPad) | track tint | 3 pt track colour | `radius.pad` | `text` | |
| Armed (iPad: in the current scene) | `lifted` | 2 pt `textSecondary` | `radius.pad` | `text` | |
| Pressed | | | morph to `radius.pad` | | Spring 200 ms; see the motion table |

Paddings: 12 left (10 on the playing pad), 8–10 right, 3–4 between letter, value and pass count. `[open]` S14 and S15 are untouched; the playing pill on a muted row still needs Scott.

### 3.2 Track head

Phone: 118 × 43, radius pill, `control` (selected: track tint plus a 2 pt track colour edge). Badge 30 round in track colour; selected, it squares to radius 9 (shape as state). Name in Barlow Medium 14.5, engine in Barlow Medium 12 `textSecondary`. Mute beside it, 56 × 43 pill `control`, labelled "Mute" (`textSecondaryRaised`, 13). Keep the word: dropping labels cost usability in Google's own study.
iPad: 276 × 44 with the entry ("A · 01"), Mute (speaker) and Solo (S) as 34 round keys.

### 3.3 Scenes toolbar

A floating toolbar: `panel`, radius 24, 4 inside, 3 between. Store is a 40-tall `lifted` pill (dot and word). Scenes fill the rest at 36–48 wide and 40–48 tall: **selected `text` fill, radius 12 (square); stored `lifted`, radius 20 (round); empty no fill, `textSecondary`**. Numbers in Barlow Condensed Bold 17.

### 3.4 Connected group (tabs, segments, Mute/Solo, pagers, zoom)

Segments 2 apart. The **selected segment is a full pill in `text` with `onColour` ink (SemiBold)**. Unselected segments are `control` with `textSecondary` ink, inner corners `radius.key` (8), and the group's outer ends a pill. Heights: 40 (phone tabs, segments), 36 (pagers, Mix pages, Mute/Solo), 48 (iPad tabs).

### 3.5 Button [`Hybrid · Button`]

Pill, 40 tall, 18 each side, hugs its label (never fixed width).

| Style | Fill | Edge | Label |
|---|---|---|---|
| Primary (one a view) | `text` | — | `onColour`, SemiBold 15 |
| Tonal | `lifted` | — | `text`, Medium 15 |
| Outline | — | 1.5 `primaryEdge` | `text` |
| Destructive (confirm in place only) | — | 1.5 `recText` | `recText` |

### 3.6 Switch [`Hybrid · Switch`]

52 × 32, radius 16. **On: `text` track, `onColour` thumb 24. Off: `control` track, 2 pt `primaryEdge`, thumb 16 in `primaryEdge`.** The thumb's size change is the shape-as-state cue; the edge against the track is 4.4:1.

### 3.7 Parameter tile [`Hybrid · Param tile`]

`lifted`, `radius.pad`, 12/10 inside. Label in Barlow Medium 12 `textSecondary`, uppercase as the FM-1 prints it. Knob badge 18 round `panel` with the knob number (Barlow Condensed Bold 11); the knob number sits on the FM-1's key order. Value and unit, then a 4-tall `panel` track with the active part in the track colour, or in `textSecondary` on Global pages, which stay grey (decision 34).

### 3.8 Sheet

Sits **below the header** (y 56) and fills the rest. `panel`, top corners `radius.sheet`, shadow up (y −4, blur 16, 40 %). Drag handle 36 × 4 `primaryEdge` 8 from the top. 24 each side, 16 at the foot. Header row: title (SemiBold 19), then its hint under it (Medium 13 `textSecondary`), never over content. Actions at the right: one Primary (Done) or a close key (40 round `lifted`) when changes apply at once (Settings).
Landscape layouts: list and detail. A 132-wide rail (selected item `lifted`, radius 12; others round and quiet) beside the content. Settings uses two columns with full subtitles wrapping to two lines.

### 3.9 Menu and popup

`held`, radius 14, `Elevation/3 Held`, 6 inside, rows 44 (52 with a second line), row radius 10. Icon 20 `textSecondary` (icons need 3:1, and 4.13:1 passes). Label in Barlow Medium 16 `text`, second line `textSecondaryRaised`. **The selected row is `lifted` with a pill radius and a check** (shape as state). Opens at the control or finger that called it (vault memory: long-press popups at the finger). Rows that go somewhere else get a chevron.
Phone hold menu: a straight column beside the finger with a touch disc (56, `text` at 18 %). **Decided for Android (Scott, 2026-11-17, on the Pixel: "let's adopt the material menu, and not the arc menu"); it replaces the wheel there.** The iPhone and iPad wait for the Android trial.
**Then priority tiles (Scott, 2026-11-17, round 4: "C: priority tiles").** Each group is its own `held` surface; there's no card round them all. Tiles: the three most-used actions, 96 × 84 at radius 18 (icon 24, Barlow 14, an optional `textSecondaryRaised` line). Rows: what's available now, in groups at radius 16, 4 apart, rows 44 / 52, a `lifted` pill on press or on the current choice. Playing: what waits for Stop folds into "N more after Stop" (⏸, ⌄, names on the second line), which unfolds in place, dimmed. Stopped: Playback, Arrange and Remove as their own groups. Two columns past the screen minus 24; no scrolling; 12 from every edge. Record: `design/components/hold-menus.md`, round 4.
iPad hold menu: a column of nine pills from the pad. The default item (Edit pattern) is the white key at radius 14; the rest are `held` pills.

### 3.10 App strip (messages)

`DESIGN.md`'s message rule, drawn: `held`, radius 12, 44 tall, 14 left; icon 16, label Barlow Medium 14, keys 32 tall `control` at radius 8, ✕ last. Bottom centre, 12 above the foot on phones and 24 on the iPad. The Undo strip and the refusal strip (Timeline's "Stop to change the song" with a Stop key) both use it.

### 3.10b Drag wells (decided 2026-11-17)

Decision 41's five wells on the screen's edges while a pad is dragged, drawn as edge tabs: a solid `held` surface flush to its edge, square on the edge side and `radius.sheet` facing in, elevation 3; icon 22 and the label (Barlow 15, `text`; "Stop first" `textSecondaryRaised`). Approach is size, not glow: a well grows outward with the pad's closeness; hot, it fills with the pad's track colour (Clear steps and Delete too), ink `onColour`, icon 26, with the tick. Slides in on the spatial spring, out quicker; growth follows the finger; fill 150 ms ease-out; Reduce Motion fades. Record: `design/components/pattern-pad.md`, decision log.

### 3.11 Confirm in place

`DESIGN.md`'s rule, in a list row (Projects › Save over…). The row gains a 1.5 `recText` edge. Its trailing actions become **Cancel (Tonal) and the Destructive button naming exactly what goes** ("Replace Tuesday Jam with Song One"), with a line saying the safeguard ("The FM-1 is backed up first"). The other rows dim to 40 %. The 0.4 s double-tap guard applies; it isn't drawn.

### 3.12 Loading indicator

No FM-1 uses a morphing 9-lobe shape (48, `text`): it turns at 1 rev / 2.4 s and pulses between 1.0 and 0.82 on a spring. Reduce Motion: no turn, a slow opacity pulse.

### 3.13 Faders (Mix)

A vertical fader: 32-wide `control` track at radius 14, the level in track colour (its top corners 5), and a line handle 44 × 6 in `text` at radius 3 that grows to 1.6× height while held. Beside it a 6-wide meter in track colour at 80 %. The send is a horizontal slider: an 8-tall track with a 4 × 16 handle. The unfilled track against the strip is 1.33:1, as in M3's own sliders. The handle and the fill carry the value. `[open]` decide whether that's enough (see 7).

### 3.14 Minimap (8-step Edit)

28 tall under the grid, as wide as the grid. 16 cells (radius 4): the current page's cells `control`, the other page's `panel`. Behind the current page sits a `lifted` window at radius 10. Notes show as 6-pt dots in track colour. A tap on the other half pages; a label at the left reads "1–8" or "9–16" in Barlow Condensed Bold 13.

---

## 4. Screens

Frame references: `screens/`. Positions are drawn on an 874 × 402 phone frame; see the README for safe areas.

### 4.1 Phone header (every phone screen)

56 tall, 16 each side, 12 between. From the left: **Song menu** (40 pill `lifted`, name and ⌄), **tabs Pads · Edit · Timeline · Mix** (connected group, 3.4), *flexible space*, **Bar ⌄** (40 pill, 1 pt `primaryEdge`, opens the Launch at menu), **readout** (right-aligned: "27·3" and "120 bpm · Song"; tap opens the tempo popup), **Record** (48 round `lifted`, `rec` dot 22), **Play/Stop** (**56 round**, `text`, icon 26 in `onColour`: the largest key, flush to the right margin). Round as decision 23; larger so size carries the priority (Scott, 2026-11-17).

> The space between the tabs and Bar has to grow (`FILL` / `Spacer()` / `weight(1f)`). A mock bug left about 150 pt empty right of the transport (fixed 2026-11-17). The transport sits flush right.

**Narrow widths** (iPhone inside its safe areas, about 734 wide): the row as drawn needs about 760. Tabs and Bar stay pills (Scott, 2026-11-17). Give way in this order, never dropping a tab, Record or Play/Stop: (1) the Song menu's name truncates to 96 with an ellipsis; (2) tab padding goes from 16 to 12 a side; (3) the readout's second line moves into the tempo popup's header; (4) the Bar pill tightens to 12/6. Steps 1–2 alone win about 60.

### 4.2 Pads (`phone-03-pads`)

Six rows of 43 with 4 between: head (118), Mute (56), then 8 pads filling the width (about 78 each on 874; about 63 inside the iPhone's safe areas). The scenes toolbar sits under them. The selected row's empty pads take the track tint. Hold menu: `phone-04-pads-hold-menu`.

### 4.3 Edit · 8-step pages (`phone-01`, decided)

- **Pattern bar** (44): badge, "Acid · Pattern A 01" over "Chromatic · 16 steps", then Step ⌄ (Tonal at radius 12), Velocity (outline toggle) and **Follow** (toggle; on = white key) at the right. It spans the width left of the panel.
- **Grid:** piano edge 40 wide (white keys `text` with the note name, black keys `lifted`, radius 8), then a `well` grid at radius 18 holding **8 steps at about 65 each** and all 7 rows. Odd beats sit on `panel` bands, row lines are `disabledOutline` at 50 %, the playhead is `text` at 12 % with a 4-pt cap, and notes are pills in track colour with two length marks.
- **Minimap** (3.14) under the grid.
- **Sound panel** docked right at 280 wide, from the header's foot to 8 above the bottom: `panel`, left corners `radius.sheet`, 14/12 inside. Page title (ENV, "1 of 2") and a connected pager. Four tiles in 2 × 2 (60 tall), then the envelope on `well`.
- **Panel closed** (`phone-02`): the same grid shows all 16 steps at the full width, which is what's built today.
- **Paging:** with **Follow on**, the page turns with the playhead (to 9–16 at step 9, back at step 1), as `motion/edit-8-step-page-flip.mp4` shows. With Follow off, paging is by hand: a tap on the minimap's other half or a horizontal swipe, and the minimap shows where the playhead is as a moving cell highlight (Scott, 2026-11-17; amends the 2026-11-01 "no paging with the playhead" for 8-step pages only).

### 4.4 Timeline (`phone-05`)

Zoom (− +, connected, 50 × 40), then the ruler. Track heads are 104 pills (badge and name). Lanes are `well` at radius 14, and the selected lane gets a 2 pt track colour edge. Blocks: radius 12, track colour when playing, `block` tint with a 1.5 edge otherwise, rests dashed `primaryEdge`. The pass count sits in a `page` chip ("2/4", Barlow Condensed Bold 11). The playhead is 2 wide with a 14 round handle on the ruler. A refusal shows in the app strip.

### 4.5 Mix tab (`phone-06`, decided)

Sub-pages Mixer · Delay · Reverb · Chorus · Global as a quiet segmented row (selected `lifted` pill, 36). Six strips fill the width (about 135 each on 874): `panel` at radius 20, and the selected strip gets the track tint and a 2 pt edge. Each strip holds a badge and name, the fader with its meter (taller now), dB, **a values line "C · Rev 12%"** (Medium 12 `textSecondary`), and Mute/Solo connected (labelled). **Pan and the reverb send live in the strip's long-press menu** (`phone-06b`): a `held` menu at the finger with the track's badge and name, a centred Pan slider, a Reverb send slider, a divider, then Select sound…. State stays visible on the strip and the controls are a hold away (Scott, 2026-11-17: "you can longpress most things in the app for more options"). VoiceOver: Pan and Reverb send as adjustable actions on the strip, so they don't depend on the long press. The Global pages are grey (decision 34). The Mix pop-up and its sheet go.

### 4.6 Sheets and popups

- **Sounds** (`phone-07`): rail of engines plus presets in two columns of 46-tall rows (radius 12). The selected preset is track tint with a 2 pt edge, a pill radius and a check. Save (Tonal) and Done (Primary).
- **Projects** (`phone-08`): four 56-tall slot rows (`control`, radius 16). Playing now gets the white-key slot badge and a live dot, and the empty slot is dashed on `well`. Load (Tonal) and Save over… or Save here… (Outline); Done is the primary. Confirm in place: `phone-09`.
- **Settings** (`phone-10`): two columns, rows with title and full subtitle, and controls at the right: switches, the Sideways / Up and down segments, and the hold-time value chip.
- **Launch at menu** (`phone-11`): from Bar ⌄. Loop, Bar ✓, Beat, Now; a divider; "2 waiting: …"; Cancel waiting.
- **Tempo popup** (`phone-12`): from the readout, right-aligned to the screen's margin. The tempo card (`well`: TEMPO, 120 BPM, a range bar in `text`), a big Tap key (`lifted`, 88 wide, radius 20), Playback segments, then the hint.
- **Undo strip** (`phone-13`) and **No FM-1** (`phone-14`): the copy now names Skiff 2.5.1 only (SLOOP retired 2026-11-15).

### 4.7 iPad (`ipad-01…04`)

The same components at iPad sizes:
- **Header:** 72 tall, iPad tabs Pads · Timeline · Mix at 48, Play as the primary at 76 × 52.
- **Pads at Half:** heads 276 with the track controls unrolled as a tile card (`panel`, 2 pt track edge, radius 22).
- **Editor panel:** track-tinted, top corners 28. It holds a step card with connected Previous and Next, tiles and a Lock key, and the piano roll with its velocity and motion lanes.
- **Timeline:** zoom group "− · 28 bars · +" and the notice in the app strip.
- **Mix:** thick vertical faders and a Global page group with grey cards.

---

## 5. Motion

Starting values. Put each in **Labs** (`ios/FM1/Labs.swift`) and graduate it to a token when Scott settles it.

**Springs:** SwiftUI `.spring(duration:bounce:)` takes these directly. In Compose, bounce 0.25 is about `dampingRatio 0.75`, and 0.2 about 0.8. Pick the stiffness to land near the duration.

| Change | Properties | Duration | Curve | Reduce Motion |
|---|---|---|---|---|
| Pad starts playing at the bar line (queued → playing) | radius pad → pill, fill → track colour, ink → `onColour`, edge 2 → 0, "Next" fades | 200 (shape), 150 (colour) | spring 0.25 / ease-out | cross-fade 150 |
| Pad stops (playing → idle) | radius pill → pad, fill → `control`, progress bar and pass count fade | 200 / 150 | spring / ease-out | cross-fade |
| Track selected | old badge round, new badge square; head tint and edge move; the selected row's empty-pad tint moves | 200 / 150 | spring / ease-out | cross-fade |
| Scene recalled | press squash 0.92 (100 ms ease-out), then back to 1 on a spring; selected scene round → square and fill → `text`, old one back | 200 | spring 0.25 | colour only |
| Pad hold menu (phone) | touch disc 0.5 → 1; menu slides 16 from the finger, scale 0.94 → 1, fades in; rows fade 20 ms apart | 200 (exit 120) | spring 0.25; exit ease-in | fade 150 |
| iPad hold menu | pills 0.7 → 1 from 70 % of the way to the finger, 25 ms apart | 220 (exit 120) | spring | fade |
| Sheet arrives | rises its own height; contents fade 30 ms apart after it | 300 | spring 0.2 | fade |
| Popup or menu from a control | y −12 → 0, scale 0.94 → 1, fade; rows 20 ms apart | 200 | spring 0.2 | fade |
| Docked panel opens | slides in from the right edge | 300 | spring 0.2 | fade |
| Edit page flip (8-step, by hand) | grid strip slides one page; minimap window slides 8 cells; label cross-fades | 280 | spring 0.25 | cut to the page, cross-fade the label |
| Playhead step | glides 60 ms into each step | 60 a step | ease-out | jumps (it's a position readout) `[open]` |
| Note hit | scale 1 → 1.12 → 1 | 50 up, 200 back | ease-out, spring | none |
| App strip arrives | y +24 → 0, fade | 300 | spring 0.25 | fade |
| Confirm in place | trailing keys scale 0.9 → 1 and fade; row edge 0 → 1.5; other rows → 40 % | 150–200 | spring / ease-out | fade |
| Fader handle held | handle grows to 1.6× height | 150 | ease-out, release on a spring | none |
| Loader | turn 360° / 2.4 s; scale 1 ↔ 0.82 | loop | linear / spring 0.3 | opacity pulse |

Exits are quicker than entrances, and nothing reaches 500 ms (`DESIGN.md`). References: `motion/`.

**Round 3 on Android (Scott on the Pixel, 2026-11-17: "the animation should show the transformation from one shape to another").** Shape changes ride Material 3 Expressive's springs, read from the AndroidX source (`compose/material3/.../tokens/ExpressiveMotionTokens.kt`): default spatial damping 0.8, stiffness 380 (pads, badges, scenes, tabs, toggles); fast spatial 0.6, 800 (presses, the squash's first beat); default effects 1.0, 1600 (colour). Because a corner radius can't overshoot past a pill, every shape-as-state change also **squashes and stretches**: going on, 6 % wider and 4 % shorter on the fast spring, settling on the spatial one; going off, the reverse. The tab pill's leading edge rides a stiffer spring than its trailing edge, so it stretches and thins, then gathers. All of it is in Labs (Shape spring · stiffness, · damping; Fast spring · stiffness; Squash and stretch). A spring may settle past 500 ms; the visible motion is done well before. Reduce Motion: the two shapes cross-fade, no squash. `graphics-shapes` `Morph` wasn't used: between a rounded card and a pill it traces the same outline as the radius, so it adds nothing visible here.

---

## 6. Accessibility (computed, not eyeballed)

| Pair | Ratio | Needs |
|---|---|---|
| `textSecondary` on `control` | 5.88 | 4.5 ✓ |
| `textSecondary` on `lifted` | 4.82 | 4.5 ✓ |
| `textSecondary` on `panel` | 6.77 | 4.5 ✓ |
| `textSecondary` on `held` | **4.13** | 4.5 ✗: use `textSecondaryRaised` |
| `text` on `held` | 9.07 | ✓ |
| `onColour` on `text` (primary key, selected tab) | 16.27 | ✓ |
| `recText` on `control` (destructive label) | 6.65 | ✓ |
| `primaryEdge` on `page` (empty pad edge) | 5.67 | 3:1 ✓ |
| `primaryEdge` on `control` (switch off edge) | 4.40 | 3:1 ✓ |
| `rec` on `lifted` (Record dot, an icon) | 3.33 | 3:1 ✓ |
| `onColour` on track colours (playing pad ink) | 6.2–12.8 | ✓ |
| `control` on `page` (idle pad against page) | 1.29 | The text identifies it; same as today |
| `lifted` on `panel` (slider's unfilled track) | 1.33 | `[open]`: the handle carries the value |
| `disabledOutline` on `panel` (dividers) | 1.98 | Decorative |

- **Targets:** every key is 40 tall or more (header keys 48). Scenes at the iPhone's width come out around 34 wide, above 24 but under 44, as today.
- **Labels:** keep words on Mute and Solo. Every icon-only key (Record, Stop, zoom, pager, close, scene numbers) needs a VoiceOver or TalkBack label.
- **Shape as state** gives every colour change a second channel: playing, selected, queued (edge and "Next"), switch (thumb size).
- **Non-drag ways in** (WCAG 2.5.7): the minimap's page tap, the faders' VoiceOver adjustable action, and the hold menus' VoiceOver actions as today.
- **Not checked:** VoiceOver, TalkBack, Dynamic Type, Increase Contrast and keyboard. Those belong to the release accessibility pass (rule 6).

---

## 7. Decisions (Scott, 2026-11-17) and what's still open

The five conflicts this spec raised, settled:

| # | Question | Decision | Effect on built decisions |
|---|---|---|---|
| 1 | Tabs: pills or words | **Pills**, as drawn (connected group, the selected tab a white pill) | Replaces decision 29's word tabs with the gliding underline; the track thread needs a new home or goes |
| 2 | Transport | **Round**, Record 48 and Play/Stop **56** | Keeps decision 23's shape; Play/Stop grows |
| 3 | Launch timing | **Pill** ("Bar ⌄", outlined) | Replaces decision 29's word form |
| 4 | Pan and send on the Mix strip | **In the strip's long-press menu**; the strip shows their values | Answers `mix.md`'s level-and-send `[open]` for the phone tab |
| 5 | Edit paging and the playhead | **Follows only when Follow is on** | Amends the 2026-11-01 log for 8-step pages |

**Still open:**
- Where the track thread goes now the tabs are pills: drop it, or move it to the selected pill's edge?
- Whether the playhead's 60 ms glide counts as travel under Reduce Motion, or jumps.
- The slider's unfilled track at 1.33:1.
- The phone's Sounds: a sheet here (`phone-07`). The structure map's phone section (2026-11-10) still lists a Sounds tab.
- ~~The arc wheel vs the straight pad menu~~: decided 2026-11-17, the straight menu on Android (see `design/components/hold-menus.md`).
