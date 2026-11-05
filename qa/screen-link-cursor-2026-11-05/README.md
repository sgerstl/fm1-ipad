# The screen link's cursor (Skiff `56 01 02`), 2026-11-05

Merged `refs/heads/skiff-screen-link` (0171450) on Scott's "yes, merge and build". Lupe now carries the cursor build of Skiff 2.2 with the screen link: `skiff-2.2-screen-link.fwsc`, 610,429 B, SHA-256 `f11c90e3…f11e`, pinned in `FirmwarePackage.swift`. It replaces the first build (`9d8eb232…acb71`, `56 01 01`), which never shipped. **Not installed on a real FM-1 yet.**

## What changed

- **Detection:** INFO's `56` tag value 1 or more is the screen link; 2 or more is the cursor (`hasScreenLink`, `hasScreenCursor`, `DeviceSession.screenCursor`). The old check read bit 0, which the value 2 fails.
- **SCREEN** is decoded by length: SLOOP's 4 bytes, the first build's 6, the cursor build's 8 (`UIState.cursor`, `cursor2`; 127 on the wire is nil).
- **SCREEN_GOTO** takes an optional cursor (`screenGoto(_:cursor:)`, `showOnDevice(page:cursor:)`). The cursor is sent only to the cursor build and never with HOME.
- **The update offer** goes to stock Skiff 2.2 and to the first build. The first build gets its own wording, which says what the cursor adds.
- **MOD's route** follows the FM-1's KNOB 1 (`SoundTab.adoptCursor`) and drives it. A route picked here, whether on the ROUTE knob or by a tap in the graph, sends SCREEN_GOTO MOD with the route. A route picked in Lupe holds for half a second (`ShapeMarks.pickRoute` / `adoptRoute`), so the FM-1's replies to a drag's earlier steps don't pull the knob back.
- **LANES, LANE MIX and SAMPLES** report cursors too, but Lupe has no pages for them yet: the drum and FM6 EDIT pages are on hold. When those pages are built, they read `deviceScreen.cursor` the same way.
- **FakeSkiff** speaks `56 01 02` by default, and `screenLinkVersion = 1` gives the first build. Its cursor pages are MOD, LANES, LANE MIX, SAMPLES, USER and PATTERNS. It also has `turnCursorOnDevice(to:)` and two demo flags: `-demo-link-v1` and `-demo-mod-walk`.

## Checked

- `swift test`: three new tests, all passing:
  - `theScreenDecodedByLength`;
  - `theCursorBothWays` (KNOB 1 on MOD comes in, a route picked here moves the FM-1 and opens MOD, the route is clamped to 11, and a cursor for DELAY is refused with the screen unchanged);
  - `theFirstBuildHasNoCursor` (linked, no cursor sent, so MOD opens with its cursor untouched).
- The simulator: `-demo -demo-skiff -demo-link -demo-mod-walk -page sound`. The fake opens MOD, then walks KNOB 1. Lupe's ROUTE and the lit row follow: route 4 (`modwalk-a.jpg`) and route 9, the matrix slot's row lit (`modwalk-b.jpg`).

## Not checked

- **A real FM-1:** the package isn't installed anywhere. Installs are Scott's.
- **The patched skiff-sim with the cursor:** the old `skiff-sim-link` build has no cursor, and the cursor build of the sim wasn't rebuilt here. Skiff's own tests and the screenprobe run in `skiff/README.md` cover the firmware side.
- **The update card's new wording:** it isn't on screen in the demo, which never offers updates. Its copy was reviewed in the code only.
- **The iPhone layout's MOD page** doesn't use ModColumns and wasn't changed.

## Design pre-flight

Ran the design-standards checklist. The change is behaviour plus one paragraph of copy in an existing card. There's no new layout, colour, type or target. The ROUTE knob and the lit row are the existing components. VoiceOver's "route N of 11" reads the followed value. No motion was added: the route changes as the FM-1's does, at 0 ms. Rule zero: following the FM-1's highlight answers Scott's "I definitely want to see what I'm hearing". `check-render` doesn't apply: this is a native app with no web page.
