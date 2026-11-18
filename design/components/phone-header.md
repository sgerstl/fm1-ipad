---
component: Phone header
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from the iPhone code (trunk) and Android's (branch claude/android-p2-shell-02c86f); not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/PhoneAppView.swift    # PhoneTopBar (chips, tabs, transport, the ⋯ menu), PhoneLaunchKey
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/TopBar.kt     # the header line, its three menus (branch claude/android-p2-shell-02c86f)
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/Header.kt     # HeaderWord, RoundButton
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/Tabs.kt       # Pads · Edit · Timeline, the gliding underline
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/TabTravel.kt  # the selected track's outline travelling between tabs
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/LupeShell.kt  # the hairline under the header
boards: [46, 47, 71, 73, "design/boards/phone-consolidation.html (row 4, rows 13a and 13b)", "design/boards/phone-landscape.html (Android branch)", "design/boards/phone-portrait-2.html (board 71, Android branch)"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=21-226   # Header · Phone
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-184   # Tabs · Phone
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-195   # Round transport key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-202   # Readout · Phone
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-211   # Word menu key
---

# Phone header

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

> **Under revision (2026-11-14):** both phones get Android's header (decisions 23, 29 and 31 in the vault's `phone-skiff-decisions-2026-11-12.md`):
> - the project as a word with ⌄ that opens the **song-name menu**, which also takes the iPhone's audio, demo and Developer items; the iPhone's ⋯ goes (decision 33);
> - tabs **Pads · Edit · Timeline** as words with the gliding white underline, the selected track's outline travelling between them (decision 29; the build plan calls it "the track thread");
> - **launch timing beside the tempo readout** as a word with ⌄, its menu the **iPhone's, with Cancel waiting** (decisions 29 and 33);
> - the readout left of **round Record and Play** at the far right, Play inside the screen's rounded corner (decisions 23 and 29);
> - **the bar countdown goes for now** (decision 31: too small, and not working on Android).
>
> Per phone (vault `phone-consolidation-build-plan-2026-11-14.md`): Android keeps its header and drops the bar countdown; the iPhone ports all of it. Section 1 below is what's built today on each phone.

## 1. Requirements

### Purpose and scope

The one line at the top of the phone (landscape on both since decision 28): what's loaded, which page, how launches land, and the transport. Chrome, not content: it never uses the content's square key, so the two read apart at a glance (decision 23; `DESIGN.md` on the Android branch, "The header is chrome, not content").

Where it sits: `structure-map.md`, "The phone with a Skiff FM-1". Built names: `.iphone` is `PhoneTopBar` on the trunk; `.android` is `TopBar.kt` on `claude/android-p2-shell-02c86f`.

### Anatomy

**`.android`** (the keeper), left to right:
- **project word** (`HeaderWord`): the project's name and ⌄. Opens the FM-1 menu, which is the song-name menu.
- **tabs** (`Tabs`): Pads · Edit · Timeline as words; the **underline** under the one showing.
- **launch word** (`HeaderWord`): the launch point and ⌄, a **waiting line** under it while something waits. Opens the launch menu.
- **readout**: bar · beat over the tempo. Opens the readout menu.
- **Record** and **Play** (`RoundButton`): round keys.
- **hairline**: ends the header, full width (`LupeShell`).
- **menus** (`LupeMenu`): FM-1 menu, launch menu, readout menu.

**`.iphone`** (built today), left to right:
- **track chip** (`chip`): the selected track's chip (Skiff's six tracks), or four chips (SLOOP).
- **tabs** (`tabs`): four keys in a well; Skiff: Pads · Edit · Mix · Sounds.
- **launch key** (`PhoneLaunchKey`): the launch point and the waiting count.
- **transport**: REC, Play and the **readout**, in one well.
- **more key** (`more`): ⋯, the app menu.

Words to retire: "song menu", "SONG ONE menu" and "the FM-1 menu" for the project word's menu once the iPhone's items join it (say "song-name menu", decision 33); "Bar key" for the launch key or word.

### Requirements

**Functional**
- **F1** `.android` One line: project word, tabs, then at the right the launch word, the readout, Record, Play.
- **F2** `.iphone` One line: track chip, tabs, launch key (Skiff with a song only), transport, more key.
- **F3** `.iphone` With no FM-1 connected, the tabs and the launch key are gone; the chip and transport are dimmed and disabled.

**States**
- **S1** `.android` Project word: the project's name; before a save or load, the Projects area's name; with neither, "FM-1".
- **S2** `.android` Tabs: the tab showing in the primary text with the underline; the others in the secondary grey.
- **S3** `.android` Launch word: the point's word; "N waiting" under it while launches wait.
- **S4** `.android` Readout: "bar·beat"; under it "tempo BPM" in Loop, else the tempo and the mode in capitals ("120 SONG").
- **S5** `.android` Record off: a ring with the red dot. On: the circle fills red and the dot goes dark.
- **S6** `.android` Play stopped: a ring with the triangle. Playing: filled white with a dark stop square; the symbols cross-fade.
- **S7** `.android` A pressed word gets a soft well behind it; a pressed round key a soft white wash.
- **S8** `.android` Keyboard focus rings the word or the round key.
- **S9** `.iphone` Track chip: the selected track lit in its colour with the selection ring; others raised with a bar of their colour.
- **S10** `.iphone` Tabs: the current one as the selected key; the others flat in the secondary grey.
- **S11** `.iphone` Launch key: the point's word, and "· N wait" while launches wait. Disabled offline.
- **S12** `.iphone` Recording: the transport's well takes the recording tint, REC fills, the readout says REC.
- **S13** `.iphone` Readout: bar.beat.step while playing, "–" stopped; under it the tempo.

**Behaviour**
- **B1** `.android` Project word: opens the FM-1 menu: Projects…, Mix…, Settings, Labs (and the fake core's items when no FM-1 is behind it).
- **B2** `.android` Launch word: opens "Launch at" with Loop, Bar, Beat, Now (current ticked); while launches wait, a divider and "Cancel waiting" with the count. Picking sends it to the FM-1.
- **B3** `.android` Readout: opens a menu with the tempo as a value you slide (no steppers, decision 10; double tap puts back the tempo it had when the menu opened) and Playback: Loop, Song, Once.
- **B4** `.android` Record and Play send REC, Play and Stop to the FM-1.
- **B5** `.android` A tab tap shows that tab; the pages slide in the tab's direction (Pads → Edit slides left) and the selected track's outline travels from one page's row to the other's (decision 29; `2026-11-14-android-landscape.md` 33, Android branch).
- **B6** `.android` The underline glides from the old word to the new.
- **B7** `.iphone` Track chip tap: selects the track, or with six tracks opens the track picker at the finger. Hold: the track's menu beside the chip.
- **B8** `.iphone` A tab tap shows that tab and moves the FM-1's screen to match when linked and following (`TopBar.driveDevice`, shared with the iPad).
- **B9** `.iphone` Launch key: a menu under it: Loop, Bar, Beat, Now (current ticked); a note saying how many wait ("Nothing waiting" when none); "Cancel N waiting" (disabled when none).
- **B10** `.iphone` Readout: the tempo popup under it.
- **B11** `.iphone` More: a menu with Play through the iPhone (and its summary when on), FM-1 over USB · Skiff demo · SLOOP demo, Settings…, and Developer in debug builds.

**Content**
- **C1** Launch points: Loop, Bar, Beat, Now, on both.
- **C2** `.iphone` Launch menu's note: "N waiting for the launch point" or "Nothing waiting".
- **C3** `.android` Cancel's line: "Cancel waiting", with "N launch(es) waiting" under it.

**Accessibility**
- **A1** `.android` Project word: a button, "FM-1 menu, project Name".
- **A2** `.android` Tabs: each has the tab role and its name; the showing one is selected.
- **A3** `.android` Launch word: "Launch quantize, Bar", plus ", N waiting".
- **A4** `.android` Readout: a button, "Bar n, beat m, T beats per minute, mode. Opens tempo and playback mode".
- **A5** `.android` Record: the switch role, state On or Off. Play: a button, "Play" or "Stop".
- **A6** `.android` Every word and round key has at least Android's 48 dp target; the drawn round key is smaller and centred in it.
- **A7** `.android` Play and Stop differ by shape (triangle, square), not only fill.
- **A8** `.android` Reduce Motion: the underline cross-fades instead of travelling.
- **A9** `.iphone` Track chip: "Track n" (", drums"), selected trait; the picker chip's hint; a "Track menu" action as the way into the hold.
- **A10** `.iphone` Tabs: the current one carries the selected trait.
- **A11** `.iphone` Launch key: label "Launch at", value the point and the waiting count, hint naming Cancel waiting.
- **A12** `.iphone` REC: "Record" with its value. Play: "Play" or "Stop". Readout: combined, hint "Opens the tempo". More: "More".
- **A13** `[review]` `.iphone` Play's touch area is smaller than the 44 pt aim.
- **A14** `[open]` `.android` TalkBack and Remove animations on the header aren't checked (P2 checks 11–13 open, vault decisions note; `2026-11-14-android-landscape.md`, "Not covered").

**Integration**
- **I1** `.android` Intents: `SetLaunch`, `CancelWaiting`, `SetTempo`, `SetPlaybackMode`, `Rec`, `Play`, `Stop`, `SetTab`. The waiting count is the core's `top.waiting`.
- **I2** `.iphone` Launch and Cancel are the iPad's `performOp(.launch)` and `performOp(.cancel)`; the waiting count is launches queued plus mutes staged.
- **I3** The Android readout's bar wraps with the loop or the song (`2026-11-14-android-p1-clock-countdowns.md` 8–9, Android branch).
- **I4** `[open]` What "the bar countdown" (decision 31) names in the built header. Neither `TopBar.kt` on the Android branch nor `PhoneTopBar` draws a countdown; the nearest are the readout's bar and the launch word's waiting line.
- **I5** `[open]` The song-name menu takes the iPhone's audio item (decision 33), but the phone's v1 scope leaves out audio through the phone (Scope, 2026-11-12). Does Android show it?
- **I6** `[open]` The readout's menu: Android's (tempo slide, Playback) or the iPhone's tempo popup (`TempoPanel`). Decisions 31–33 name the header, not the tempo popup.

### Ruled out

- A header where every control is a square key: it looked like the content (Scott, 2026-11-13, decision 23, board 71).
- The readout right of Record and Play: it moves left of them, which sit at the far right (Scott, 2026-11-13, after using it).
- Play and Record in the rounded corner: they move in from it (decision 29, 2026-11-14).
- Mix and Sounds as tabs: Mix becomes a sheet (decision 28) and a pop-up (decision 31); Sounds is a sheet from the track head's hold menu (decision 33).
- The iPhone's ⋯ menu: its items move into the song-name menu (decision 33).
- The bar countdown, for now (decision 31).
- Launch at drawn as segments on the phone: built as a menu (structure map, board 47).

### Out of scope

- The track picker and track menu the chip opens: `track-head.md`, `hold-menus.md`.
- The menus' panel and placement: `hold-menus.md`. The tempo popup: `tempo-popup.md`.
- The keys' press behaviour: `keys.md`.
- The iPad's row: `top-row.md`.
- The no-FM-1 card (decision 33): `connection-states.md`. The song-name menu's sheets: `projects-sheet.md`, `settings-sheet.md`, `mix.md`.

## 2. Design

Boards: 46 and 47 (the iPhone's landscape boards: the launch key in the top bar), 71 (A with C's tabs, `design/boards/phone-portrait-2.html` on the Android branch), 73 (landscape, `design/boards/phone-landscape.html` on the Android branch), and the consolidation board's rows 4, 13a and 13b (`design/boards/phone-consolidation.html`, screenshots `and-header.png`, `ios-header.png`, `and-menu.png`, `ios-more.png`, `and-launch.png`, `ios-launch.png`).

Particular to the header:
- The underline is white, not a track colour: white is for global things (`DESIGN.md` on the Android branch, "White is global, the track's colour is the track's", Scott, 2026-11-14).
- Record is round like the FM-1's buttons (decision 23).

### Decision log

- 2026-11-13: board 71, A with C's tabs: words with ⌄, round Record and Play, plain readout, hairline, tabs as underlined words (Scott, decision 23).
- 2026-11-14: tabs Pads · Edit · Timeline (Scott, decision 28).
- 2026-11-14: launch timing beside the tempo; Play and Record in from the corner; tabs slide with the track's outline travelling (Scott, decision 29).
- 2026-11-14: one header on both phones, Android's; the bar countdown goes (Scott, decision 31).
- 2026-11-14: the song-name menu takes the iPhone's audio, demo and Developer items; the launch menu is the iPhone's with Cancel waiting (Scott, decision 33).
- 2026-11-17: tabs Pads · Edit · Timeline · Mix as a connected pill group and launch timing as a "Bar ⌄" pill, over decision 29's underlined words; Record round 48 and Play/Stop round 56, the largest key, flush right (Scott, hybrid UI study; `design/hybrid-ui/spec.md` 4.1).
- 2026-11-17 (round 3, Scott on the Pixel): the selected tab is one pill that travels between tabs on M3 Expressive's spatial spring, its leading edge on a stiffer spring so it stretches and thins, then gathers (spec §5, round 3).
- 2026-11-17 (Scott, tab-motion study: "b and c"; vault `assets/tab-motion-2026-11-17/`): **tab changes fade through** (out 90 ms ease-in; in 210 ms ease-out, settling 98 % → 100 % on the spatial spring), replacing the sideways slide; the tab pill still springs across and the selected track's band still travels over the fade. **Edit grows out of the pad** when opened from a pad's or a Timeline block's "Edit steps" (a panel surface with a 2 dp edge in its colour grows from the pad to the page, spring 420 ms bounce 0.15, the pad's colour fading in the first ~120 ms, Edit fading in over the last ~200 ms); a tap on the Edit tab fades through. **Navigation presses with elasticity** (Scott: "the destination where you tap needs to react… With elasticity"): the four tabs, Mixer · Effects, Notes · Feel · Sound, the Song menu, the Bar pill and the effect cards shrink to 0.92 in 100 ms on touch, then spring back (bounce 0.35, ~1.03 overshoot, ~350 ms) as the pill lands; a cancel springs back without navigating. Record and Play/Stop keep their own press. Reduce Motion: a plain cross-fade, and a 150 ms brightness press instead of the scale.
- 2026-11-17: **the FM-1's HOME goes back to the last of Pads and Timeline** (Scott: "the home button doesn't always take you back to pads where you were. It should probably remember whether you came from pads or timeline"). From Mix or Edit, HOME changes to whichever of Pads and Timeline the phone was on last, however it got there; Pads if neither has been visited. Kept for the session. On Pads or Timeline it stays put and only closes what's open (B5). A HOME the phone itself sent (a panel closed, Back) moves no tab. The cause of "doesn't always": HOME restored only a tab the FM-1 had moved the phone off, so a Mix reached by the phone's own tab stayed put. Worse, a Mix pick sends the FM-1 to GLO while the phone is already on Mix, which saved Mix itself as the tab to go back to. The tab change uses the usual transitions (fade-through; Edit → Pads shrinks into the pad). Sound-family keys keep the old restore. Device checks 115–118.
- 2026-11-18: the track badge no longer squares when selected; the head outline squares to 12 instead (Scott, logged in `track-head.md`). The pattern bar's badge stays round.
- 2026-11-18: **tab changes no longer lose their start** (Scott: "Yes, both"; measured: every switch built both pages in its first frame, 50–212 ms, and the animations counted from that frame, so a switch into Pads showed at 85–90 % opacity, a cut). (1) The clock starts after the switch's first frame has drawn: through it the outgoing page stays fully there and the incoming at 0. (2) Each page is movable content: the page showing moves into the outgoing slot instead of being built again. Pages aren't kept built between switches (not yet). **Labs › Tab motion** (temporary, out once Scott settles): Style Staggered (default: out 90 ms ease-in, then in 210 ms ease-out from 90 ms, scale 0.92 → 1 on the spatial spring) or Now (the old overlap, from 0.98); Speed 1×, 1.3×, 1.6× scaling every duration, delay and spring settle of the fade-through and the grow/shrink. Reduce Motion's cross-fades are unscaled and untouched. Tests: `TabPagerTest`. Device check 164.
- 2026-11-18: **tab motion locked in** (Scott: "Lock it in", after trying Labs › Tab motion; he chose Now at 1×). The fade-through is the original overlap: out 90 ms, in 210 ms together, the new page from 0.98 on the spatial spring; grow and shrink at their original timings. The clock-after-the-first-frame and movable-page fixes stay. Labs › Tab motion is gone; its two prefs are cleared on start (`RETIRED_TUNING`).
- 2026-11-18: the song menu loses "Shared effects…" (the Mix tab's sub-pages cover it) and "Labs" (the Labs section is gone).

## 3. Build notes

- `.android` hybrid build (branch `hybrid-ui-android`, 2026-11-17): `TopBar.kt` (Song pill, `Tabs`, Bar pill, readout, `TransportKey`), `Tabs.kt` (`SegmentGroup`: connected pills, the selected one's corners on the spring), `Header.kt` (`HeaderPill`, `TransportKey`). 56 tall; the hairline under the header is gone (containment by surface steps, spec 1.3). The waiting count sits on the Bar pill as a small white disc, since a second line can't live inside a pill. Give-way (`headerGiveWay`) runs at 790 / 750 / 720 / 700 dp; the Pixel 10 Pro's landscape width needs none of it. Play/Stop's corner inset is computed for the 56 circle (`headerCornerInset(keyR = 28)`). The readout keeps Android's menu (I6 is still open), so the tempo popup isn't built. The track thread's place is untouched (`[open]` in spec 7).

- Android's header is on `claude/android-p2-shell-02c86f` (and P1's branch), not the trunk. The trunk's `android/` holds only `BRIDGE.md`.
- `DESIGN.md`'s header rule (decision 23 says it was written into the repo) exists only on the Android branch; the trunk's `DESIGN.md` doesn't have it yet.
- Android already shows Cancel waiting in its launch menu, but only while something waits; the iPhone's always shows it, disabled when nothing waits, with a note above it. The keeper is the iPhone's (decision 33).
- The iPhone shares `ios/FM1` with the iPad: the port is gated to the phone layout and checked against iPad screenshots before and after (build plan, Risks).
- No real iPhone: the iPhone stream is checked in the simulator on the demo FM-1 only (build plan, Risks).

### Decision log

## 4. Usage

- On either phone, anything that opens a menu from the header is a word with ⌄, never a square key.
- The tabs are words with the underline; don't reuse the iPad's tab rise on the phone.
- New app-level items go in the song-name menu, not a new header key.
