# The `page` area (P4's schema): what recording it takes. P1's findings, 2026-11-13

P4 asked P1 to record a real `page` area (P4 branch `claude/android-p4-sound-pages-7e2a23`, `core/PageState.kt`). P1 did not do it overnight. Why, and how to:

## Where the logic lives today
- **SloopKit (shared):**
  - `SkiffPages.build(track:globals:firstEngineParam:firmware:)` gives `[PageSpec]` (title, family, ids per knob, routes for MOD, picks for LANES, engine pages) as `DeviceSession.pageLayout`.
  - `DeviceDisplay.trackDesc` and `DeviceDisplay.value` format a value as the FM-1 shows it.
  - `SkiffButtonMap.place(for: UIState)` maps the FM-1's screen to a place (`.shape(page)` for sound pages).
  - `SkiffPageMap` maps between 2.2 and 2.5.1 page numbers.
  - `DeviceSession.deviceScreen` is the screen link (verified live on the Pixel).
- **iPad app only (`ios/FM1/Sound.swift`, about 900 lines with SwiftUI):** `SoundPage`, which ties each `PageSpec` to the FM-1's page number (`fw`), plus `SoundPage.page(session, fw:)`, `reached(session, family)` for the drum-track fallbacks, the engine pages' titles (`editPageTitles`), and the graph pictures.

## The clean way
1. Move the non-UI parts of `SoundPage` (the fw numbers, `pages(session)`, `page(session, fw:)`, `reached`) into SloopKit, next to `SkiffPages`. The iPad keeps its views and uses the moved type. **This changes iPad code, so it needs an iPad device check** (Sound tab following the FM-1's page buttons, on 2.2 and 2.5.1).
2. Add `PageArea` to `android/core/Sources/PhoneCore/State.swift` mirroring `PageState.kt`, built from `deviceScreen` → `SkiffButtonMap.place` → the moved `SoundPage` → `PageSpec`:
   - The four controls: label (the spec's `knobLabels` or DESC label), `DeviceDisplay.value` text, raw/min/max, `list` when the desc has names.
   - The graph per kind, from the same ids.
3. `turned`/`turnSeq` come from CHANGED pushes for an id on the page. `lock` waits for MOTION (P3's locks too).
4. Intents: `pickPage` is SCREEN_GOTO and `setParam` is SET/TRACK_PARAM. Both are writes, so the read-only guard drops them until writes are allowed.
5. Record `page-*.json` with the FixtureRecordingTests pattern: FakeSkiff demo with `-demo-link` (the screen link), driving `deviceScreen` through FakeSkiff's own page changes. P1's recorder already carries over P4's hand-written page frames until then.

## Size
About a day. Step 1 is the risky part (iPad behaviour); 2 to 5 are mechanical once 1 exists.
