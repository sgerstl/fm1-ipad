# iPad app

SwiftUI on iPadOS. It talks to the FM-1 over USB MIDI using SLOOP's editor protocol (see `../protocol/`). Built on Blue Lion with Xcode, and run there as "Designed for iPad" with the FM-1 plugged into the Mac.

**Pass 1** is a rebuilt subset of SLOOP's web editor, designed for the iPad and written from `vendor/sloop-2.8.4/EDITOR_PROTOCOL.md` (never ported from the editor's code). Its steps, each usable on its own:

1. Sequencer view following the device: four tracks, all 64 steps, drums as 16 lanes, a moving playhead, live updates.
2. Step editing from the iPad.
3. Sound library.
4. Sound shaping.

The app only talks to SLOOP 2.8.4 (protocol 12). It checks `INFO` on connect and refuses anything else.

Design brief and decisions live in my vault (`Projects/Dev/fm1-ipad/`).

The earlier plan (custom protocol, 8 tracks, FM1 Open firmware) is archived on the `slice-1-link` branch.

## Layout

| Path | What |
|---|---|
| `SloopKit/` | Swift package: framing, typed requests and replies, `SloopClient` (one request in flight, replies matched by command and arguments, pushes as a stream), `MIDITransport` (CoreMIDI, finds the "Felucca" port), `SloopSession` (reads and follows the device), `FakeSloop` (a pretend FM-1). Tests run against captured traffic in `Tests/SloopKitTests/Fixtures`. |
| `FM1/` | The SwiftUI app. Drawn on a fixed 1376 × 1032 pt canvas (13-inch iPad Air, landscape), scaled to fit the window. `Theme.swift` mirrors `tokens/tokens.json`. |
| `project.yml` | XcodeGen spec. `FM1.xcodeproj` is generated from it (`xcodegen generate`). |

## Building and running

- Tests: `cd SloopKit && swift test`.
- On Blue Lion: `xcodegen generate`, open `FM1.xcodeproj`, pick **My Mac (Designed for iPad)**, ⌘R, with the FM-1 plugged into the Mac. Signing is the free personal team (`K3CNX79952`). Launching the built `.app` outside Xcode doesn't work: macOS calls the bare iOS bundle damaged.
- Without the FM-1: pass `-demo` as a launch argument, or pick "Demo FM-1" from the connection menu (top left). The demo edits a step on the selected track every 6 seconds; it never switches tracks by itself.
- Close SLOOP's web editor while the app runs. Both editors share the FM-1's one MIDI port, and the device holds one incoming request at a time.
