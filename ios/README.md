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
