# Lupe: the iPad and iPhone app

Lupe is a SwiftUI editor for the M-VAVE FM-1. It talks to the FM-1 over USB MIDI and shows what the device is
doing as it does it: the song, the patterns, the sounds and the mix, edited from the screen or from the FM-1's own
knobs and buttons.

It speaks two firmwares, picked from the FM-1's `INFO` reply on connect (`FirmwareDetector`, `FirmwareDialect.known`):

- **Skiff 2.2**, with the screen-link patches this repo's firmware adds (`../skiff/`). This is the main target. With
  the patches the app follows the FM-1's screen, its step cursor, levels and scope. Stock Skiff 2.2 works with
  less, and the app offers to install the patched build.
- **SLOOP 2.8.4** (protocol 12, `vendor/sloop-2.8.4/EDITOR_PROTOCOL.md`), the firmware the app began with.

Anything else is refused with a note saying what's supported.

Names: the product is **Lupe**. The Xcode target, its folder and the app struct are `FM1`, and the bundle id is
`com.scottgerstl.fm1ipad`. The Swift package is `SloopKit` for historical reasons; it serves both firmwares.

Design notes and decisions live outside this repo, in the author's notes (`Projects/Dev/fm1-ipad/`).

## Layout

| Path | What |
|---|---|
| `project.yml` | XcodeGen spec. `FM1.xcodeproj` is generated from it and isn't checked in. |
| `SloopKit/` | Swift package, no UI: everything about talking to the FM-1. |
| `FM1/` | The SwiftUI app. |

### SloopKit

| Area | Files |
|---|---|
| Transport and framing | `MIDITransport` (CoreMIDI; finds the FM-1's "Felucca" port), `Frame`, `Messages`, `Client` (`SloopClient`: one request in flight, replies matched by command and arguments, pushes as a stream) |
| Firmware seam | `Driver` (`FirmwareDriver`, `FirmwareDetector`, `DeviceShape`, `FirmwareCapabilities`), `SloopDriver`, `SkiffDriver` |
| The session | `Session` (`DeviceSession`: connects, reads everything, follows pushes and polls, and sends edits through the driver) |
| Skiff's song | `SkiffSong` (lists and entries), `SkiffSongStore` (list edits, the pattern pool, `PERFORM` scenes and mutes), `SongPlayback`, `SongSections`, `PadMove`, `SkiffPerform` |
| Sound and steps | `SkiffEdit`, `SkiffLFO`, `SkiffChord`, `PatternEdit`, `MotionPaint`, `Music`, `Samples` |
| Projects and firmware | `Project`, `SkiffProject`, `SkiffSave`, `ProjectFolders`, `FirmwareInstaller`, `FirmwarePackage`, `FirmwareBackup`, `UpdatePorts`; the bundled firmware in `Resources/` |
| Fakes | `FakeSkiff` and `FakeSloop` (pretend FM-1s for the demo and the tests), `FakeLoader` (the update loader) |

Tests are in `SloopKit/Tests/SloopKitTests`. Most run against the fakes or captured traffic (`Fixtures/`). The
`*SimTests` suites need `skiff-sim` running and are skipped unless `SKIFF_SIM=1`. `ScopeHardwareProbe` needs a real
FM-1 and `FM1_HW=1`.

### FM1 (the app)

On the iPad everything is drawn on a fixed 1376 × 1032 pt canvas (a 13-inch iPad Air in landscape), scaled to fit
the window. A compact size class (a landscape iPhone) gets `PhoneAppView` instead, which reuses the iPad's leaf
views. Grid sizes come from `GridMetrics` in the environment, and `Theme.swift` mirrors `../tokens/tokens.json`.

| Area | Files |
|---|---|
| App and shared state | `FM1App`, `EditorUI` (the UI state every view shares), `AppView`, `PhoneAppView`, `SessionUpkeep` (what both keep doing for the session), `TopBar`, `Overview` (the track selector), `Theme`, `Settings` (preference keys), `SettingsSheet` |
| Song tab (Skiff) | `SongTab` (the page and its editor panel), `PadsPage`, `PadGrid`, `PadsTrackStrip`, `PadThumb`, `SkiffArrange` plus `Arrange*.swift` (the timeline), `SkiffArrangeParts`, `Entries` |
| Pattern editor | `PianoRoll`, `DrumGrid`, `StepInspector`, `StepSelection`, `MotionLanes`, `TwoFingerScrollView` |
| Sounds and the mix | `SoundPanel`, `Sound`, `ShapeColumns`, `Knobs`, `KnobPanel`, `TrackControls`, `PageGraphs`, `Library`, `PresetsPanel`, `MixerPanel`, `SamplerPanel` |
| Menus and popovers | `Menus` (`AppMenu`, `MenuPanel`, `PlacedMenu`), `ArrangeMenus`, `TrackMenu`, `OutsideTouch`, `TempoPanel`, `ValueLoupe` |
| Following the FM-1 | `DeviceFollow` (the screen map, where an FM-1 button lands, the SEQ step cursor) |
| Projects and firmware | `Projects`, `ProjectsSheet`, `SkiffSaveViews`, `FirmwareInstall` |
| SLOOP only | `SongPage`, `SongSectionsPanel`, `SongBars`, `SelectedStepPanel` |

## Building and running

The deployment target is iOS 18. The app runs on iPad and, in landscape, on iPhone.

1. `cd ios && xcodegen generate`. Run it again whenever files are added or removed.
2. Open `FM1.xcodeproj` and run on an iPad with the FM-1 plugged into it, or in the iPad simulator with `-demo`.
   Signing uses a free personal team (`K3CNX79952`), whose profiles expire after 7 days. Reinstall before then;
   installing over an unexpired copy keeps its data.
3. Don't build the **My Mac (Designed for iPad)** destination. It rewrites the shared provisioning profile to cover
   only the Mac, and the iPad install then fails as "no longer available".

Tests: `cd ios/SloopKit && swift test`. The Xcode scheme has no test target, so ⌘U does nothing.

Close any other FM-1 editor (SLOOP's web editor, Skiff's) while the app runs. They all share the FM-1's one MIDI port,
and the device answers one request at a time.

### Without an FM-1

Pass `-demo` as a launch argument, or pick "Skiff demo" or "SLOOP demo" from the connection menu (top left). The
demo FM-1 answers as a real one would and makes small edits of its own.

| Launch argument | Does |
|---|---|
| `-demo` | Starts on the demo FM-1 (SLOOP unless `-demo-skiff`). |
| `-demo-skiff` | The demo is Skiff 2.2 (`FakeSkiff`). |
| `-demo-link`, `-demo-meter`, `-demo-scope` | The demo Skiff has the screen link: buttons, then levels too, then the scope too. |
| `-demo-stopped`, `-demo-still` | The demo starts stopped, or makes no edits of its own (screenshots, recordings). |
| `-demo-notes-walk`, `-demo-mod-walk` | The demo turns the FM-1's cursor through SEQ's steps or MOD's routes. |
| `-demo-firmware NAME` | Shows the firmware installer as for that firmware, without a device. |
| `-page song\|mixer\|library\|sound` | Opens on that tab. |
| `-song-timeline` | The Song tab opens on the timeline rather than Pads. |
| `-no-intro` | Skips the launch animation. |
| `-slow-motion` | The Song tab's divider spring runs eight times slower, to study a transition. |
| `-show-touches` | Draws a circle under each finger and logs touches (screen recordings). |
| `-count-bodies` | Debug builds only: prints how often each counted view's body runs. |

The rest (`-demo-chord`, `-demo-engine`, `-demo-song`, `-demo-track`, `-demo-turn`, `-demo-usr`, `-demo-user-sounds`,
`-demo-link-v1`, `-family`, `-sound-panel`, `-motion-lane`, `-motion-locks`, `-motion-paint`, `-library-user`,
`-intro-at`) set up particular screens for screenshots. Each is described where it's read: `FakeSkiff.swift`,
`EditorUI.swift`, `MotionLanes.swift`, `LaunchIntro.swift`.
