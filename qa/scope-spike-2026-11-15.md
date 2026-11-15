# Spike: Skiff's own drawing code in Lupe (decision 45), 2026-11-15

**Question.** Can Lupe draw the FM-1's pictures with Skiff's own drawing code, fed by data it already has, instead of hand-drawing each page? And can the live scope come over the screen link without starving it?

**Short answer.** Yes, and exactly. Skiff-Lupe 2.5.1's UI code builds as a library for iOS, the Mac and Android's Swift core. Fed from the session's mirror, it draws GLO › DELAY (and REVERB, CHORUS, GLOBAL, FX › DELAY and REVERB) with **0 differing pixels** against the board renders, in a unit test and on screen in the iPhone simulator. All 47 pages draw. SCOPE costs about 3 kB/s and didn't slow requests in a measurable way on skiff-sim.

**Recommendation: adopt for some pages.** Use it for the picture panels whose drawing reads only what the session already mirrors: the four GLO pages, FX › DELAY and REVERB first, then ENV, LFO, OSC, FLT, FM6 and the other parameter-driven pictures. Ship it on Android first. On iOS, ship it only once Skiff's authors grant an App Store permission (see "GPL and the App Store"). Until then, keep the hand-drawn pictures on iOS, and correct them against SkiffDraw's frames in a test, so they stop drifting. For the scope, take SCOPE as it is and draw it with `graph_scope`, either through the library or as a 15-line port. Decide first whether Lupe shows the trace or the SKIFF theme's "sea" (see the next section).

Branch `claude/scope-spike-53b5eb`, spike code only. The app's screens are unchanged: the demo screen appears only with `-skiffdraw-spike` (iOS) or through an adb-only activity (Android).

---

## What was built

| Piece | Where | What it is |
|---|---|---|
| `CSkiffDraw` | `ios/SkiffDraw/Sources/CSkiffDraw/` | One C file, `skiffdraw.c`. It includes Skiff's own host-test stubs (`tests/ui_test.c`: the 240 × 240 RGB565 display buffer), and through them `firmware/src/ui*.c`, `gfx.c`, `params.c`, and the rest, unchanged. The vendored tree is Skiff-Lupe 2.5.1 at `737e3fb` (`skiff/VERSION`), with `gen/` holding Skiff's own generators' output. The C API is in `include/skiffdraw.h`: set `song.g`, `trk[t].p`, the engine, the selected track, the transport, the playheads, the theme, the page; feed SCOPE and METER; render. |
| `SkiffDraw` | `Sources/SkiffDraw/` | The Swift face, `SkiffScreen`: the mirror setters, `render() -> [UInt8]` as RGBA, and a `CGImage` on Apple platforms. It has no SloopKit and no UIKit, so it builds for Android too. |
| `SkiffDrawLink` | `Sources/SkiffDrawLink/SkiffMirror.swift` | Fills the mirror from `DeviceSession`: globals, the selected track's DUMP, each track's level, pan, mute and engine, the transport, the clock's 1/16, the playheads, SCREEN, METER and SCOPE. It asks the FM-1 for nothing new. |
| Tests | `Tests/SkiffDrawTests/` | GLO › DELAY (two settings) and GLO › REVERB SPRING, pixel for pixel against `design/boards/fm1-screens`; the page table; a SCOPE frame drawing a trace; the draw cost. `swift test` in `ios/SkiffDraw`: 5 of 5 pass. |
| Tools | `ios/SkiffDraw/Tools/` | `skdcompare.c` and `pixdiff.py` (all 24 board renders), `skdscope.c` (SCOPE round trip), `skdallpages.c` (47 pages × 14 engines). |
| iOS demo | `ios/FM1/SkiffDrawSpike.swift` | Launch argument `-skiffdraw-spike`, plus `-skiffdraw-page 0…4` and `-skiffdraw-theme 0…5`. It replaces the root view only under that argument. |
| Android | `android/core` (SkiffDraw is a dependency of LupeNative), `LupeNative.skiffFrame` (JNI), `core/debug/SkiffDrawDebugActivity.kt` | One frame a call, about 30 a second, drawn by the same C code compiled for arm64 Android. `ios/SkiffDraw`'s `skiffdraw-demo` also runs on its own through `adb shell`. |
| Link load | `tools/skiffprobe.swift scope` | GET round trips and bytes a second, with and without SCOPE, against skiff-sim built from `737e3fb`. |

## Pixel match

- **All 24 board renders, 0 differing pixels, whole screen** (`pixdiff.py`): DELAY a–e, REVERB a–e, CHORUS a–g, GLOBAL a–c, FX › DELAY a–b, FX › REVERB a–b. The first run differed in 62 header pixels (`1.1` against `1.2`), which turned out to be the playhead. With `setPlayhead` mirrored, that went to 0. The board images came from tag v2.5.1 and SkiffDraw from Skiff-Lupe 737e3fb, so the screen link changes nothing on these pages.
- **In the iPhone simulator** (`iphone-sim-glo-delay.png`, the demo FM-1 on 2.5.1, track 3): I sampled the screenshot at each FM-1 pixel's centre (4 device pixels each) against a C render of the same state. The panel has **0 differing pixels**. The header differs in 69 pixels, the bar.beat counter, because the demo's playhead was elsewhere. So the `CGImage` path with `.interpolation(.none)` changes nothing.
- Draw cost: 60–250 µs a frame on the Mac and the simulator. The worst of 658 frames across all pages and engines was 0.85 ms. A 60 Hz frame is 16.7 ms.

Images: `qa/scope-spike-2026-11-15/glo-delay-board-vs-skiffdraw.png`, `iphone-sim-glo-delay.png`, `all-47-pages-analog-poweron.png`.

## The scope

- **SCOPE round trip.** For four signals, I compared `graph_scope` drawing from the raw ring (what the FM-1 shows) with `graph_scope` drawing from the 120 points SCOPE sends, put back into the ring (`skd_set_scope`: each point twice, with one pre-trigger sample that restores the firmware's own scale). The trace matches in shape and scale. The difference is 280–830 pixels, all from the halving: SCOPE keeps the larger of each pair, so Lupe's trace steps every 2 px where the FM-1's moves every pixel. Images: `scope-roundtrip-saw.png`, `scope-roundtrip-pluck.png`.
- **Live in the app.** `iphone-sim-edit1-scope-HI-CON.png` shows the demo FM-1's SCOPE stream, through `DeviceSession.scope`, then the mirror, then Skiff's `graph_scope`, at about 8 a second (the fake sends fewer than the firmware).
- **Not a waveform on SKIFF.** On the SKIFF, CRYPT and QUARK themes, an EDIT page's scope (`graph_scope` at full panel height) doesn't draw the trace. It draws the theme's level picture: SKIFF's "sea" of track-coloured columns with the boat, from each track's level and the clock. The trace appears only on HI-CON, PAPER, NEON (as a skyline) and in MENU › LARGE's strip. The library draws the sea from METER (`edit1-sea-SKIFF-from-METER.png`), but it can never match the FM-1 frame for frame, because the swell runs on the FM-1's own `fm1_ms`. **If Scott's FM-1 is on SKIFF, the FM-1 shows the sea, not the waveform Lupe's SCOPE carries.** He needs to choose what Lupe shows.

## Link load for SCOPE (skiff-sim, Skiff-Lupe 2.5.1's own editor.c)

`skiffprobe scope 8`, playing, with WATCH steps, parameters, screen and METER on, and a GET every 20 ms:

| Phase | In (MIDI bytes/s) | SCOPE | GET round trip: median / 95 % / max | Lost |
|---|---|---|---|---|
| Without SCOPE | 752 | – | 1.0 / 6.8 / 44.8 ms | 0 of 307 |
| With SCOPE | 3,865 | 25.0 a second, 126 B each, 3,149 B/s | 1.0 / 9.6 / 46.2 ms | 0 of 275 |
| Without again | 746 | – | 1.0 / 7.4 / 23.2 ms | 0 of 305 |

- It arrives at 25 a second, not the nominal 30. `editor.c` sends SCOPE only into an empty queue, and on a pass when METER isn't going out, so the two take turns. That is the firmware's own guard against starving the link: SCOPE never queues ahead of a reply.
- The cost is about 3.1 kB/s of MIDI (about 4.2 kB/s of USB-MIDI packets). The median round trip doesn't move; the 95th percentile rises by about 3 ms.
- **Caveat.** skiff-sim runs on the Mac's clock and its USB, not the FM-1's. On the real unit the same guard applies, but the timings need a read-only run on a real FM-1, which the main session would arrange. Lupe already asks for SCOPE only while a scope is on show (`showScope`).

## How much state must be mirrored, and how fragile that is

**Enough for the parameter pictures, and it's already read.** The global ids on the link are `song.g`'s indexes, and the track ids are `trk[].p`'s (wide ids from 128), so the mirror is a straight copy. Per frame: 28 globals, the selected track's 148 parameters, 3 values for each of the 6 tracks, 6 meters, 120 scope points, and the transport.

What the drawing reads, by page (`skdallpages.c`: each page drawn again after changing one kind of state):

| Kind of state | Pages | Mirrored today? |
|---|---|---|
| `song.g` and the selected track's `p[]` only | GLO's 4, FX › DELAY, REVERB, FX, DRIVE, INSERT, SLICER, DUCK, LFO, LFO 2, MOD, ARP, ARP 2, VOICE, VOICE 2, EDIT pages with their own charts (OSC, FLT, FM6, FM) | Yes |
| Other tracks' values | ENV, ENV 2, SCALE, CHORD, FOLLOW, MIXER | Partly: level, pan, mute and engine; not their other parameters |
| The steps | NOTES, FEEL (PATTERN's grid too, once steps exist) | No. The session holds every track's steps, but the spike doesn't copy them |
| The clock or animation | EDIT scope pages (the sea), LFO's moving dot, the header's rolling digits | Approximated with the app's clock |
| Lists and storage | PRESETS (from the firmware's own tables: free), USER, PATTERNS, PROJECT, SONG, AUTOMATION, SAMPLES' waveform | No |

**Where it's fragile:**

1. **Locked to one firmware build.** The vendored code must be the firmware on the unit. A different Skiff (2.2, a newer Skiff-Lupe) shifts ids and pages silently. It must check INFO's version and refuse otherwise, or vendor one tree per supported build.
2. **Names and per-track sound state.** The footer's "SAW LEAD" and "PULSE LD" come from the mirror's default presets, not from the unit. Mirroring each track's preset (which Lupe reads) needs a setter that sets the name without resetting the parameters. Small, but every such field is one more place to drift.
3. **One global firmware state.** One `SkiffScreen` per process, used from the main actor. Pictures render one after another, which is cheap enough (under 1 ms each).
4. **Transient UI state isn't in the mirror.** Messages, card highlights, menus. The spike draws the page "at rest" (`ui.hot_t = 0`). Lupe only wants the panel anyway.
5. **Colour.** It draws in the FM-1's theme colours (the selected track's). Decision 44's grey GLO panel would need a Lupe palette. Skiff's palette table is plain data (`gen/ui_palettes.h`, `palette_set`), so a seventh entry is a few lines, but it changes the vendored copy.

## What Skiff Studio does (upstream 2.6, f956a12 and 0ea3682)

Studio doesn't mirror state. It **replays inputs in lockstep**:

- The unit casts every input it takes as 16-byte records over SysEx 83. Records cover the buttons and keys `ui_input` took, the knobs' detents, the MIDI the audio interrupt took, each editor request, the audio block count, the frame boundaries and `fm1_ms`.
- A complete copy of the firmware in the browser does the same things at the same block counts. It starts from an identical state: the unit restarts with its stored music loaded before the audio first runs, and the copy loads the same backup.
- Drift is caught by hashes: each frame's pixels (`e`), and once a second the music, the UI and the last 512 sound samples (`C`). A sequence gap or a ring overflow (seq 127) means resync.
- Even so, the FM-1's HALL reverb differs slightly from the computer build, so the scopes can be a few pixels off.

**What Lupe can reuse without the cast** (the cast needs about 3.2 KB of flash that Skiff-Lupe can't spare):

1. **A cheap drift check.** Lupe already has `Digest`. A periodic hash of the mirrored `song.g` and `p[]` against the unit's catches a lost push the way Studio's `C` record does. A mismatch means DUMP again.
2. **Run Lupe's own writes through the copy too.** Studio feeds the editor's requests to its copy through the unit's own `editor.c`. For the mirror, applying Lupe's SETs locally at once, as the session already does, is the same idea at parameter level.
3. **Don't chase the sound.** Studio shows that sample-exact sound needs the identical start state, every input and the same reverb. The trace and the sea will never be frame-exact from a mirror. Draw them from SCOPE and METER, and accept "the same picture of the same sound", not "the same frame".

## Effort to cover every page

- **Productionise the GLO and FX pictures** (the panel cropped from the frame, canvas y 76–213, scaled by whole pixels; the version check; preset names; a Lupe palette if grey stays): about 2 days for iPad and iPhone, plus about 1 day for Android's Compose (the bytes are already there).
- **The other parameter-driven pictures** (ENV, LFO, MOD, OSC, FLT, FM6, INSERT, DRIVE, SLICER, ARP, VOICE): no new drawing. Each page's panel crop replaces a `PageGraphs` case. About half a day each to wire up and check on the device, so about a week for all.
- **Steps pages** (NOTES, FEEL, PATTERN): copy the session's steps into `trk[].step` (about 1 day). Lupe's own editors are richer, so probably not wanted.
- **Lists** (PRESETS, USER, PATTERNS, PROJECT, SONG, AUTOMATION, SAMPLES): not worth it. Lupe has its own screens for these.
- **Trimming.** The library currently drags in the whole firmware: 1.7 MB of arm64 object, 727 KB of it code, including the audio engines and 124 KB of sample ADPCM, because Skiff's host test builds it that way. A translation unit with only `gfx.c`, `ui*.c`, `params.c` and stubs for the audio state should be well under 500 KB. That's about 2–3 days, and it's the part most likely to break on each Skiff update.
- **Keeping up with Skiff.** Re-vendor on every Skiff-Lupe release, which means re-running Skiff's generators, `swift test` and `pixdiff.py`. About an hour a release, if the stubs still fit.

## GPL and the App Store

- Lupe is GPL-3.0. Skiff is GPL-3.0-only, copyright Leo Kuroshita / Hügelton Instruments and contributors. Linking Skiff's drawing code into the app makes Lupe's binary a combined work that contains their code.
- The App Store's terms (one device, DRM, no further distribution) add restrictions that GPL-3.0 §10 forbids. This is the known tension: the FSF's position, and VLC's removal in 2011 after a contributor objected. **Scott can grant an App Store permission for his own code, but not for Skiff's.** Shipping SkiffDraw on iOS safely needs an additional permission under GPL-3.0 §7 from Skiff's copyright holders, for example an "App Store exception" like the ones other GPL apps carry, or their written OK. Without it, the risk is one objection and a takedown.
- Google Play has no such conflict, and sideloaded APKs certainly don't. **Android can ship it under the GPL as it stands**, with the source offered as Lupe already does.
- Already true today, separately: Lupe ports Skiff's formulas by hand (`PageGraphs.swift`) and installs Skiff-Lupe firmware images. The firmware is a separate program, which is aggregation and fine. Hand-ported formulas are a greyer area than linking, but also derived from GPL code. This isn't legal advice. The clean fix for all of it is the same permission from upstream.
- Suggested next step: ask illuminus5 (Skiff's maintainer) whether they'd add an App Store exception, or grant one to Lupe. The ask is cheap, Studio shows they want the screen shown elsewhere, and their answer decides iOS.

## Not done or not verified

- **Not checked on an FM-1.** No real unit was used (the constraints said read-only, only if arranged). The link-load numbers come from skiff-sim, and the live scope came from the demo fake.
- **Android:** the arm64 cross-compile of the library and of `libLupeNative.so` with SkiffDraw linked succeeded, and the APK built. For what ran on the emulator, see "Android emulator" below.
- **iPad layout:** only the iPhone simulator was used. The library doesn't care, but the demo screen wasn't checked on the iPad.
- **Accessibility:** the demo screen is a developer tool behind a launch argument. Its frame has a VoiceOver label; nothing else was checked.

## Android emulator

(Filled in below once the emulator run finished.)
