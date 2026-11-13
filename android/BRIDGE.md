# Lupe on Android: the bridge

*Written 2026-11-13, after the SysEx gate passed on the Pixel 10 Pro. Scope: Skiff only, portrait, no firmware installs, no SLOOP, no Bluetooth, no sample import (vault: `Projects/Dev/fm1-ipad/phone-skiff-decisions-2026-11-12.md`). This is the contract P1 (core link) and P2 (shell) build against at the same time.*

## The shape

```
 Kotlin / Compose                         Swift (SloopKit, compiled for Android)
 ───────────────────────────────          ──────────────────────────────────────
 Compose screens  ◄── ViewState ────────  PhoneCore  (façade over Session)
                  ─── Intent ──────────►      │
                                              ▼
 FM1Link (android.media.midi)                Session ─ SkiffDriver ─ SloopClient
   finds, opens, watches the FM-1             ▲
   bytes in  ──── onBytes ─────────────►  AndroidTransport : SysExTransport
   bytes out ◄─── send ─────────────────      │
```

There are two bridges, and P2 needs only the second one to start.

1. **The MIDI bridge** (bytes): Kotlin owns Android's MIDI service; Swift owns everything that understands the bytes. SloopKit already has the seam: `SysExTransport` (Client.swift), four members.
2. **The state bridge** (screens): Swift publishes what the screens show as `ViewState`; Compose sends back what the person did as `Intent`. Compose never calls `Session` directly.

Why split it this way: the 12,900 lines of SloopKit (the protocol, the Skiff driver, pattern and song edits, the fakes and their tests) stay one codebase for iPad and phone. Kotlin holds only what has to be Android: the USB device, the screens, the lifecycle.

---

## 1. The MIDI bridge

### What SloopKit already expects

```swift
public protocol SysExTransport: AnyObject, Sendable {
    var frames: AsyncStream<[UInt8]> { get }   // whole SysEx frames, F0…F7; finishes when the FM-1 goes away
    var notes:  AsyncStream<NoteEvent> { get } // the FM-1's keys
    var clock:  AsyncStream<ClockEvent> { get }// start, tick (24 a beat), continue, stop
    func send(_ frame: [UInt8])
}
```

`Session` takes a factory, `init(transport: () -> SysExTransport?)`, and calls it once a second (`run()`): nil means "no FM-1 yet", and a finished `frames` stream means "lost it", after which it starts asking again. The iPad's `MIDITransport` is one implementation, `FakeSkiff` another. **Android adds a third, `AndroidTransport`, and nothing above it changes.**

`SysExAssembler` (Frame.swift) already turns a raw byte stream into frames, notes and clock, tolerating clock bytes inside a frame and frames split across reads. Android delivers bytes in arbitrary chunks, so the assembler is reused as is.

### Kotlin side: `FM1Link`

Owns `MidiManager`. One instance for the app's life.

| Job | How |
|---|---|
| Find the FM-1 | `MidiManager.getDevicesForTransport(TRANSPORT_MIDI_BYTE_STREAM)` plus `registerDeviceCallback`. A device is the FM-1 when its `PROPERTY_PRODUCT` or `PROPERTY_NAME` contains "Felucca" (Skiff keeps Felucca's USB name, as the iPad's `findDevice` assumes). **P1 logs the real property values on the Pixel and fixes the match.** |
| Open it | `openDevice(info, listener, handler)`. Asynchronous: the device arrives in the callback. |
| Receive | `openOutputPort(0).connect(receiver)`. Each `onSend(bytes, offset, count, timestamp)` calls straight into Swift: `LupeNative.onBytes(bytes, offset, count, timestamp)`. No buffering in Kotlin. |
| Send | `openInputPort(0).send(bytes, 0, n)`. Frames longer than `getMaxMessageSize()` go out as consecutive sends; SysEx survives being split because the FM-1 reads a byte stream. Today's largest frames fit in 1,024 bytes (the iPad's send buffer), so this is a guard, not the normal path. |
| Lose it | `onDeviceRemoved` for that device → close both ports, then `LupeNative.onLost()`. |
| Report | Calls, not a polled state: `LupeNative.onOpening()`, `onOpened(rawMode)`, `onLost()`. Swift's `LinkGate` turns them into the factory's answer (`none`, `opening`, `open`). *(P1, gate 3.)* |

**Watch the names.** Android names ports from the device's side: you *send* to its **input** port and *receive* from its **output** port. The opposite of how it reads.

**Built at gate 3 (2026-11-13):** `core/FM1Link.kt`, `core/LupeNative.kt` and Swift's `LupeNative.swift` (hand-written JNI: `JNI_OnLoad` caches the class and the three Swift→Kotlin methods `send`, `onState`, `onDebug`; Swift-made threads attach on first call). The match is deliberately broad until the Pixel's strings are logged: a USB device with at least one port each way whose name, product, manufacturer, serial or port names contain "Felucca", "FM-1", "FM1" or "M-VAVE". The debug screen (`core/debug/LinkDebugActivity`, opened with `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity`) lists every device's property strings. **The Pixel has one USB-C port**, so adb over USB and the FM-1 can't be plugged in at once: install first, or use wireless debugging.

**Packaging:** Gradle's `buildSwift` task runs `android/scripts/build-native.sh`, which builds `libLupeNative.so` and copies the Swift runtime it needs (followed through ELF NEEDED) into `app/build/swift/jniLibs/arm64-v8a`: 19 libraries, about 100 MB unstripped in debug, 45 MB of it ICU data pulled in by full Foundation. arm64 only. Trimming (FoundationEssentials instead of Foundation, stripping) is a release concern, not P1's.

**Manifest:** `<uses-feature android:name="android.software.midi" android:required="true"/>`. USB MIDI should need no runtime permission (Android's MIDI service owns the USB device), as Chrome needed none beyond its own site prompt. P1 confirms.

**minSdk 33** (`getDevicesForTransport`). The only target is Scott's Pixel 10 Pro on Android 16; nothing is gained by going lower.

### Swift side: `AndroidTransport`

The iPad's `MIDITransport` minus CoreMIDI:

- `onBytes` feeds `SysExAssembler` under a lock, then yields frames, notes and clock to the three streams, exactly as `MIDITransport.receive` does. It's called on the MIDI handler's thread; the streams are thread-safe.
- `send(frame)` calls Kotlin's send through JNI.
- `onLost` finishes the three streams (the same `finish()`).
- The factory handed to `Session` returns an `AndroidTransport` when `FM1Link` reports `open` and it hasn't been handed out yet, else nil. Never blocks.

**Timestamps:** Android gives each chunk a `System.nanoTime` timestamp. The iPad ignores arrival time today (`ClockEvent` has none), so v1 drops it too. If the playhead jitters on the phone, the fix is to add a timestamp to `ClockEvent` for both platforms, not an Android special case.

### Considered and not chosen: AMidi in native code

The NDK's AMidi (`AMidiDevice_fromJava`, `AMidiOutputPort_receive`) lets Swift read the ports directly without a JNI call per chunk. It needs a polling thread, and the Java device object still has to come from `MidiManager`. The traffic is small (clock at 120 BPM is 48 bytes a second; screen pushes about 30 a second; meters), so a JNI call per chunk costs microseconds against a 30–85 ms visual budget. **Start with the Kotlin receiver.** Switch to AMidi only if P1 measures a problem.

---

## 2. The state bridge

### The rule

Compose renders `ViewState` and sends `Intent`. That's the whole surface. This is what lets P2 build the shell against a fake while P1 brings up the real core.

### `PhoneCore` (Swift)

A façade over `Session`, `@MainActor`, written for the phone's screens rather than mirroring Session's ~110 public properties and ~80 functions. It grows one area per phase:

| Phase | Areas added to `ViewState` | Intents added |
|---|---|---|
| P1 | `link` (searching, connecting, reading, ready, lost with reason, wrong firmware with version) | `retry` |
| P2 | `top` (transport, tempo, playback mode, launch quantize and what waits, REC), `shell` (tab, divider position, which bottom page the FM-1 shows) | `play`, `stop`, `rec`, `setTempo`, `setLaunch`, `cancelWaiting`, `setTab`, `setDivider` |
| P3 | `pads` (six rows, entries, play/wait/mute state, scenes, Select), `editor` (pattern, steps, selected step, locks) | pad tap and hold actions, step edits, lock and clear |
| P4 | `page` (family, page, four controls with value and range, graph data) | `setParam`, `pickPage` |
| P5 | `mix`, `sounds`, `projects` | per screen |
| P6 | `timeline`, `automation` | per screen |

Each area is its own `Codable` struct. Swift sends an area again only when it changed, coalesced to the display frame (at most one send per area per 16 ms). Change detection uses Observation's `withObservationTracking` around each area's builder.

**Encoding:** JSON to start, one string per area across JNI (`LupeNative.onState(area, json)`). Kotlin decodes with kotlinx.serialization into matching data classes. Small areas at 60 Hz are well within budget; if `pads` or `editor` show up in a profile, move those two to a binary encoding, not the whole bridge.

**Intents** go the other way as `LupeNative.intent(json)`, decoded in Swift into an `enum PhoneIntent` and dispatched to Session on the main actor.

**Touch feedback never waits for the round trip.** Compose shows the pressed state, the drag and the haptic itself; the FM-1's answer then confirms or corrects it, the way the iPad already treats a pad tap while a launch waits.

### Built at gate 5 (P1, 2026-11-13)

- **`PhoneCore`** (`android/core/Sources/PhoneCore`) publishes `link` and `top`. `State.swift` mirrors P2's `State.kt` field for field; nil fields are left out.
  - `link.phase` follows `DeviceSession.status`. `reading` comes from a new `DeviceSession.reading` flag, true between INFO and ready (the iPad ignores it).
  - `link.reason` is `unplugged` (the stream ended while connected) or `readFailed`.
  - `top`: `project` is PROJ_NAME's name, read on reaching ready and every 5 s, because Session reads it only when the iPad's Projects sheet opens. `waiting` counts tracks with a staged entry, the same test SkiffSongStore uses. `bar`/`beat` count MIDI clock in 4/4: Session doesn't observe its clock counter, so `top` is rebuilt every 50 ms while playing and sent only when the beat moves.
- **Intents:** `retry` restarts Session's search loop; `play` and `stop` call `setPlaying`. The rest of P2's list decodes and is logged as "not handled yet". `setPlaybackMode` is accepted into the list.
- **`shell` stays in Kotlin for now.** `BridgedLupeCore` keeps tab and divider locally and answers `setTab`/`setDivider` itself. Swift takes `shell` over when the FM-1's page drives the bottom half (screen link).
- **`BridgedLupeCore`** (Kotlin) is P2's `LupeCore` over the bridge. `LupeApp` builds it through `LupeStartup` unless the app preference `core` is `fake`.
- **Fixtures are recorded, not hand-written:** `RECORD_FIXTURES=1 swift test --filter FixtureRecording` in `android/core` writes `ready`, `searching`, `lost` and `wrongFirmware`. The FM-1 side is FakeSkiff (demo) and, for wrong firmware, FakeSloop reporting 2.9.0, as SloopKit's own test does. Unplugging goes through `LinkGate.lost()`, FM1Link's path.

### pads and editor (P1, 2026-11-13, after P3's schema 7cca10c)

`PhoneCore` publishes `pads` and `editor` (`PadsEditor.swift`), derived as the iPad's Pads page derives them: LIST2's lists, PERFORM's mutes and scenes, `SkiffSongStore.marks`, and the counted clock. Both are sent only once the link is ready, because before that Session holds placeholder tracks. Calls made:
- The entry a track is on is `playing`, stopped as well, since that's where it starts. `progress` is set only while playing.
- A staged entry is `waiting` when its launch is queued (with the `bar` it lands on), and `next` when it's the song's own next.
- `top.waiting` counts queued launches only. *(Corrected: the first recording counted the song's next entries.)*
- Columns run through the last entry any track uses, plus one empty.
- The editor shows the selected pad's track and the pattern that track is on. Notes use SloopKit's names (`C♯4`, with the sharp sign).
- `values`, `lanes` and `lock` stay empty and `off` until MOTION is read (not done yet).
- Intents: `padSelect` and `stepSelect` are screen-local (nothing is sent to the FM-1). The rest of P3's intents decode and are logged as not done yet.
- The recorder carries over hand-written frames for areas PhoneCore doesn't publish yet (`shell`), so a re-record doesn't wipe a screen's data. Files with carried frames stay `"provisional": true`.

### Read-only by default (P1, 2026-11-13)

`LinkGate.readOnly` (on by default) wraps every connection in `GuardedTransport`. Only frames that Skiff's own protocol table (`skiff-src web/EDITOR_PROTOCOL.md`) calls queries reach the FM-1; anything else is dropped and logged ("read-only: blocked cmd N…"). The allowlist is in `ReadOnlyGuard.swift`. Tests show Session and PhoneCore reach ready and keep running over FakeSkiff (with and without the screen link) with nothing blocked. The guard was added for Scott's approved overnight read-only tests on the real FM-1. **There is deliberately no button that turns writes on**: a stray tap from another session's screenshot script hit one on the shared emulator. Writes need `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true`. Making it read-only again is one tap. So Play from the phone does nothing until writes are allowed.

### The schema is shared, written once

The area structs live in one place: Swift `Codable` types in `PhoneCore/State.swift`, with a generator (or, at first, a hand-kept Kotlin file plus a round-trip test) producing the Kotlin data classes. A test in each language decodes the other's sample JSON from `android/fixtures/state/`, so a renamed field fails a build, not a screen.

### P2's fake

`FakeLupeCore` (Kotlin) implements the same interface as the real core and replays recorded `ViewState` streams from `android/fixtures/state/`. **The recordings come from SloopKit itself:** a Mac test runs `PhoneCore` over `FakeSkiff(demo: true)` and writes every area it emits. That keeps repo rule 5 (fakes only say what a capture, skiff-sim or the firmware taught them): the phone's fake is a recording of the iPad's tested fake, never invented.

---

## 3. Building SloopKit for Android

- **Toolchain:** the official Swift SDK for Android, **6.4.2** (the current release on 2026-11-13; it must match the compiler exactly, so it's paired with swift.org's 6.4.2 toolchain, not Xcode's) and NDK r30. Install steps and paths are in `android/scripts/env.sh`. JNI glue is **hand-written** (P1 settled the open question): the bridge is a handful of functions, and `swift-java` (pre-1.0) would add a generator step for no gain. *(P1, 2026-11-13: was "Swift 6.3" and "swift-java, or by hand if it gets in the way".)*
- **Files that stay Apple-only**, behind `#if canImport(CoreMIDI)` / `canImport(CryptoKit)` / `canImport(AVFoundation)` so the iPad's build and Xcode project don't change:
  - `MIDITransport.swift`, `UpdatePorts.swift` (CoreMIDI; replaced by `AndroidTransport`)
  - The installer group: `FirmwareStore.swift`, `FirmwarePackage.swift` (CryptoKit), and `FirmwareInstaller.swift`, `FakeLoader.swift` (which use the package type). Installs are out of scope.
  - `FirmwareBackup.swift` stays in: it's Foundation only, and `Session.firmwareBackup` and `ProjectFolders` use its `DeviceBackup`.
  - `SampleFile.swift` (AVFoundation; sample import is out of scope)
  - `FakeSloop.swift`, `SloopDriver.swift` stay in (tests use them) but the phone never builds a SLOOP session.
- **Foundation and Observation** come with the SDK. Every other SloopKit file imports only those two.
- **SloopKit's `Package.swift` doesn't change.** SwiftPM needs no platform entry to build for Android. The phone's code lives in its own package, `android/core/` (`LupeCore`), which depends on SloopKit by path: `AndroidLink` (AndroidTransport, the factory), `PhoneCore`, `MainLooper`, and `LupeNative` (the JNI surface, built as `libLupeNative.so`). The iPad app never sees them. *(P1, 2026-11-13: was "new targets in SloopKit's Package.swift"; a separate package keeps the iPad's package graph untouched.)*
- **Gate 1 result (2026-11-13):** SloopKit compiled for `aarch64-unknown-linux-android33` with only the `canImport` guards above, plus one in `Session.init(demo:)` (no CoreMIDI: the non-demo default factory returns nil, and the phone passes its own). Its tests run on an arm64 Android 16 emulator through `android/scripts/sloopkit-android-test.sh`: 261 of the 349 macOS tests build for Android (the rest are CoreMIDI sims, firmware installs and AVFoundation) and all pass. macOS still passes 349 of 349, and SloopKit still builds for iOS.

### The one real risk: the main actor

`Session` is `@MainActor`. On iOS the main actor runs on the main dispatch queue, which UIKit drains. On Android nothing drains that queue unless it's tied to the app's main `Looper`.

**Settled at gate 2 (2026-11-13): no annotation changes.** The stock main-actor executor still targets the main dispatch queue on Android. libdispatch exposes that queue's wake-up eventfd for CoreFoundation (`_dispatch_get_main_queue_port_4CF`) and a drain call (`_dispatch_main_queue_callback_4CF`). `MainLooper.install()` (`android/core/Sources/MainLooper`) registers the fd on the UI thread's `ALooper`, so Android's own main loop drains the queue, and every existing `@MainActor` in SloopKit runs on the UI thread. Skip's `swift-android-native` does the same. Two rules come with it, and `install()` checks the first:

- `install()` runs on the UI thread (gettid == getpid, the same test the Swift runtime uses for the main actor).
- **`System.loadLibrary("LupeNative")` runs on the UI thread, before any other thread touches Swift**, because libdispatch binds its main queue to the thread that loads it. In practice: `Application.onCreate`.

Proof: `android/scripts/looper-probe.sh` runs on an arm64 Android 16 emulator. A detached task and a raw pthread (like the MIDI handler thread) hop to `@MainActor` and back; each side checks its thread, and `MainActor.assumeIsolated` agrees. 1,000 round trips take about 6–10 µs each, and `DispatchQueue.main.async` lands on the UI thread too. A control run without the hook never reaches the main actor. The same check runs inside the app on the debug screen (gate 3), because the APK's UI thread is the real test. *(P1, 2026-11-13: was "speculative"; the serial-actor fallback isn't needed.)*

---

## 4. P1's order of work, with gates

1. **Builds:** SloopKit (minus the Apple-only files) compiles for arm64-android and its existing tests pass under the Android SDK on the Mac or an emulator.
2. **Main actor:** the Looper executor works (test above).
3. **Bytes:** `FM1Link` + `AndroidTransport` + a debug screen that sends Skiff's version request and prints the reply. The same check Scott ran with the web editor, now through our code.
4. **Session:** `Session` connects to the real FM-1 on the Pixel and reaches `ready`; unplug shows `lost`, replug reconnects within two seconds.
5. **State:** `PhoneCore` emits `link` and `top`; Compose shows the readout and Play works from the phone.

P2 starts the day this file is agreed: the Compose project, the shell from boards 53–54, against `FakeLupeCore` and the fixtures. The two meet at step 5.

## Open, to settle in P1 (not blocking P2)

- The FM-1's exact USB property strings on Android.
- ~~Whether `swift-java`'s generator or hand-written JNI is less trouble.~~ Hand-written (§3).
- Whether the Kotlin data classes are generated or hand-kept with a round-trip test.
- Lifecycle: keep the ports open while the app is in the background (default, so a quick app switch doesn't drop the link), and rebuild everything on process death through the normal search loop.
