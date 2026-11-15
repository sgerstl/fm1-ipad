---
component: Hold menus
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/Menus.swift           # MenuItem, AppMenu, TouchPoint, AppMenuLayer, PlacedMenu, MenuPanel, FanMenu, CheckBox
  - ios/FM1/TrackMenu.swift       # TrackMenu, TrackMenuLayer (the track's options), TrackMenuPress
  - ios/FM1/Settings.swift        # Handedness.menuX / menuY
  - ios/FM1/Labs.swift            # menuOpen, holdToMenu
  - ios/FM1/PadsPage.swift        # the pad's menus (options in pattern-pad.md)
  # Android (branch claude/android-p1-core-link-faf639, not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/HoldMenu.kt
boards: [2, "design/boards/phone-consolidation.html (row 8)", "design/boards/radial-menu.html (Android branch only)"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-362   # Fan menu button
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-388   # Menu row
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-357   # Menu panel · Launch at
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-405   # Callout row · Phone
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-406   # Touch disc · Phone
---

# Hold menus

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

*Lupe's own menus, every one of them: the fan at the finger (pads, track heads, drops, confirms) and the placed menu (keys, submenus). No system menus or alerts.*

> **Under revision (2026-11-14):** on both phones the hold menu takes **Android's radial styling** and carries the **iPad and iPhone's full option set** (decision 31, vault `phone-skiff-decisions-2026-11-12.md`; build plan `phone-consolidation-build-plan-2026-11-14.md`, row "Hold menu": Android adds the iPad's options, the iPhone ports the styling). Android's radial as built (`HoldMenu.kt`, board `radial-menu.html`, Scott 2026-11-14): a disc in the track colour grows under the finger; lines in the track colour run out from its edge to each choice, each ending in a small node, the lit choice's line white; the choices stack round a circle about the finger and open to the left near the right edge. While the finger stays down, sliding onto a choice lights it and lifting picks it; lifting on nothing leaves the menu open for a tap. The page behind dims and takes no touches; a tap outside closes. Leaving: choices and lines fade, the disc shrinks out faster than it came. Reduce Motion: fades only. TalkBack reads a plain menu. A destructive choice asks in place, red-outlined, with the same tap guard. Section 1 below is the iPad and iPhone as built.

## 1. Requirements

### Purpose and scope

Every choice that belongs to a thing on screen opens beside the finger that asked for it, in Lupe's own style, never the system's (2026-11-05). The fan is for holds and taps on things you play (pads, track heads, drops) and for confirms. The placed menu is for keys (a ⋯, a header, the connection readout, Launch at) and for submenus.

The options themselves belong to the thing held: the pad's are in `pattern-pad.md` (B10–B12, B16, B19, B20); the track head's are below. The rule for destructive actions is `DESIGN.md`, "Destructive actions: confirm in place".

### Anatomy

Names as in the code.

- **item** (`MenuItem`): one entry. Kinds: a **choice** (does something), a **submenu** (opens its groups), a **destructive** choice (asks once more), a **note** (a line that says something, never focused).
- **menu** (`AppMenu`): a title, groups of items built when it opens, and where it opens. Flags: `fan`, `tint` (a track), `asking` (opens already confirming), `caption`, `optOut`.
- **fan** (`FanMenu`): the items as separate floating **buttons** coming out of the finger. The **first** is the primary.
  - **caption**: a line or three over the buttons saying what the choice does.
  - **confirm**: the destructive item's own row, turned red-outlined, its words naming what goes.
  - **Cancel**: the row after the confirm.
  - **opt-out box**: "Don't ask again" (`CheckBox`) under the buttons.
- **placed menu** (`PlacedMenu` holding a `MenuPanel`): a panel of **rows** with a **title**, **group dividers** and, in a submenu, a **Back row**.
- **track menu** (`TrackMenu`, `TrackMenuLayer`): the fan for a track head.
- **touch point** (`TouchPoint`): where the last finger went down, for a confirm no gesture opened.

Words to retire: "popover" and "dialog" for any of these; "long-press menu" where the thing is tapped (an empty pad's menu opens on a tap).

### Requirements

**Functional**
- **F1** Every menu in the app is a Lupe menu: no system menus, confirmation dialogs or alerts (2026-11-05; confirms 2026-11-10).
- **F2** A menu's groups are built when it opens and again as it's shown, so values in it stay live.
- **F3** A fan's submenu opens as a placed menu in the fan's place.
- **F4** Track menu, in order: Select sound; Record sample… (a synth track on firmware with samples); Clear motion (n steps), when the track has recorded motion; Clear all pads (destructive); Clear pattern NN's steps. Notes are left out of the fan.
- **F5** Select sound is left out on the Sounds tab, where the browser is the page.
- **F6** Clear all pads asks in place, naming the count, the track and any pattern that goes with them ("Clear all 5 pads on T4 Drum Kit, erasing pattern 07"; Scott, 2026-11-10: "it should probably say clear all pads").
- **F7** Clear pattern NN's steps clears only the pattern the track is on, the pads stay, and it's kept for Undo instead of a confirm (`DESIGN.md`: Undo wins over a confirm).
- **F8** A menu can open already asking (`AppMenu.confirm`): its confirm and Cancel only, for a key whose only job is the destructive thing (2026-11-10).

**States**
- **S1** Fan, tinted (pad and track menus): every button in the track's tint, the first outlined in the track colour (Scott, 2026-11-09).
- **S2** Fan, neutral: the first filled as the primary, the others on the held surface.
- **S3** Disabled item: faded and untappable; its title says why where it can ("Clear all pads: none yet", "Clear all pads (stop first)").
- **S4** Confirming: the item's row is the confirm, outlined in the record-red text colour, words naming what goes; the next row is Cancel (the row before when it's the last); the others fade and take no touches.
- **S5** Confirm guard: the confirm ignores taps for a moment after it appears (`DESIGN.md`).
- **S6** Opt-out box: unticked, ticked; it takes effect only with the confirm.
- **S7** Placed menu: rows with icon or pattern chip, title, a tick on the current choice, a chevron on a submenu; disabled rows in the tertiary grey; the keyboard-focused row highlighted.
- **S8** Placed menu taller than its room: the rows scroll; nothing is cut off.
- **S9** Fan taller than the screen: the buttons wrap into balanced columns side by side (the phone fits five to a column).

**Behaviour**
- **B1** A hold on a pad, a block or a track head opens its fan after the hold time (Settings › Touch, `holdToMenu`). The release after the hold isn't a tap. An empty pad's fan opens on a tap (`pattern-pad.md` B8).
- **B2** Holding a track head selects the track, then opens its fan.
- **B3** The fan opens beside the finger on the side away from the playing hand (Settings › Handedness: right-handed, to the left), the other side where it wouldn't fit, then kept on screen (batch list, 2026-11-08).
- **B4** The first button sits level with the finger, so the likeliest choice is nearest (Scott, 2026-11-09: an empty pad's "New pattern" nine times in ten).
- **B5** The gap between buttons belongs half to each neighbour: the targets are bigger than they look (Scott, 2026-11-09).
- **B6** Buttons come out of the finger one after another and close back with a fade (Labs `menuOpen`; closing two thirds of it).
- **B7** A placed menu from a key opens under the key, above it where it wouldn't fit; at a finger, beside it as B3. It grows out of the finger or the key's corner and shrinks back into it (Scott, 2026-11-09: "expand out from where you touch, slight easing, smooth").
- **B8** A touch outside closes any menu and still reaches the page (OutsideTouch). Escape closes; in a submenu it goes back first.
- **B9** Tapping a destructive item turns it into the confirm in place; tapping the confirm closes the menu and does it; Cancel, a tap away or Escape keeps everything.
- **B10** A confirm opened without a gesture of its own (a store's question) opens at the touch point.
- **B11** iPhone: the same fan and options; buttons wrap into columns where they don't fit the height (merge 2026-11-11).

**Content**
- **C1** Fan titles name what it acts on: "Track 4 · Drum Kit"; the pad's in `pattern-pad.md` C2.
- **C2** Confirms name exactly what goes and say when it can't come back; captions carry what a system alert's message used to (2026-11-10).
- **C3** A disabled item says why in its own title rather than in a separate note.

**Accessibility**
- **A1** A fan is a container labelled with its title (and caption); a placed menu is modal, labelled with its title, its title a heading.
- **A2** Placed menus follow the APG menu pattern: ↑ ↓ between items, → opens a submenu, ← goes back, Return picks, Escape closes; the first item takes focus on opening.
- **A3** Escape from a hardware keyboard and VoiceOver's two-finger scrub close a fan; in a placed menu they go back a level first.
- **A4** The confirm takes VoiceOver focus and its words are announced; hint "Can't be undone. Cancel, or tap away, keeps everything".
- **A5** Current choices carry the selected trait and a tick read as "Current"; submenu rows hint "Opens a submenu"; the Back row reads "Back, title".
- **A6** Every hold has a non-hold way in: the track head's "Track menu" action, the pad's "Entry menu" action (WCAG 2.5.7). The VoiceOver track menu opens at a fixed place beside the track list.
- **A7** The opt-out box is a real toggle (VoiceOver: switch button, on or off), its whole row the target, its hint saying where it comes back on.
- **A8** Targets: fan buttons and placed rows above the 44 pt aim, the fan's gaps adding to them.
- **A9** Nothing by colour alone: the confirm has its icon and words as well as the red outline; the primary its position and weight.
- **A10** Reduce Motion: menus fade in and out; nothing travels from the finger.
- **A11** The confirm's red is the record text colour, chosen because it keeps contrast on every track's tint where the record colour didn't (code comment, `confirmButton`).

**Integration**
- **I1** Clear all pads rewrites the track's list empty through `SkiffSongStore`, so it's refused while Lupe is playing (title says "stop first") and checked against what would be erased.
- **I2** Clear motion clears Skiff's recorded knob moves on the track.
- **I3** Record sample… needs the samples capability (Skiff and SLOOP drivers).

### Ruled out

- System menus: Lupe's own at the finger (2026-11-05, canvas board 2).
- System alerts and confirmation dialogs for destructive actions: confirm in place (Scott, 2026-11-10: "style it like the other menus with the theme and keep it close to the button press"; `DESIGN.md`).
- The pad and track menus as a menu panel: separate floating buttons fanning from the finger (Scott, 2026-11-09).
- Neutral grey for the pad and track fans: the track's tint, the first outlined in its colour (Scott, 2026-11-09).
- Menus fixed to one side of the finger: Settings › Handedness (2026-11-08, 71cef0e).
- An extra tap before a key's only, destructive job: the menu opens already asking (2026-11-10).
- Phones: Android's short track menu (Sounds, Mute, Solo) on its own; the full option set comes with the radial (decision 31, 2026-11-14).

### Out of scope

- The pad's options and their rules: `pattern-pad.md`.
- What each option opens: the Sounds panel (`sounds-panel.md`), the sampler, the editor.
- The Launch at menu's contents, the connection menu's contents, the Timeline's block menus: their own components (the menu style is this one).
- Mix's row hold menu on the phones (PAN): `mix.md` for what it holds.

## 2. Design

Boards: canvas board 2 (the first menu at the finger, 2026-11-05); `phone-consolidation.html` row 8 (iPhone's ten options in two columns beside Android's four); `radial-menu.html` on the Android branch.

Motion follows `DESIGN.md` (arrivals say where they come from: out of the finger). Particular to menus: each fan button travels from the finger to its place with a short stagger; a confirm's row change is a fade, the other rows fading out.

### Decision log

- 2026-11-05: one menu style, Lupe's own, at the finger (Scott).
- 2026-11-08: Handedness decides the side (71cef0e).
- 2026-11-09: the empty pad's menu becomes a fan from the finger, first item level with it; the track head gets the same (Scott).
- 2026-11-10: confirm in place replaces every system alert; "Don't ask again" on clearing a pad (Scott).
- 2026-11-10: "Clear all pads" named for what it does (Scott).
- 2026-11-14: phones take Android's radial styling with the full option set (decision 31).

## 3. Build notes

- Device checks: `2026-11-09-lupe-batch-2026-11-06.md` 10 (menus from the finger, both hands; no result recorded); `2026-11-09-perform-grid-map.md` 19–20 (the empty pad's fan; not recorded), 49 (step clear names its pattern; not recorded), 61 and 66 (no system dialogs, Don't ask again; passed 2026-11-11); `2026-11-10-accessibility.md` 13 and 22 (Entry menu, Escape; parts A–C passed 2026-11-11).
- `TouchPointWatch` records touch-downs without taking part in any gesture, so a confirm can open where the finger was.
- `[open]` Android's radial puts at most six choices in one place, the rest behind "More…" (`HoldMenu.kt`). The iPad's filled-pad menu has nine. How does the full set sit in the radial: More…, two rings, or a column?
- `[open]` Android's radial dims the page and blocks it; the iPad's menus leave the page live and pass an outside touch through. Which do the phones keep?
- `[open]` Android opens to the right unless near the right edge; the iPad follows Handedness. Settings › Handedness is in the phones' union (decision 33). Does the radial follow it?
- `[open]` Slide-to-pick (pick in the same gesture as the hold) is Android's. Does it come to the iPhone with the styling, and to the iPad?

### Decision log

## 4. Usage

- Any new choice list: build an `AppMenu` and set `ui.menu`; set `fan` and `tint` when it belongs to a track's thing held at the finger, `fromKey` when a key opens it.
- Anything that loses work: `MenuItem.destructive(title:confirm:)` in a fan, or `AppMenu.confirm` on its own; never a system alert. Prefer Undo where the change can be kept for it.
- Put the likeliest choice first: it lands next to the finger.
