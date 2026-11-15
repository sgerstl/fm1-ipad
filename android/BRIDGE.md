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
- **`shell` stays in Kotlin for now.** `BridgedLupeCore` keeps tab and divider locally and answers `setTab`/`setDivider` itself. Swift now sends `shell` with only `bottom` (a sound page while the FM-1 shows one, else the editor; `PageArea.swift`'s `ShellArea`), and `BridgedLupeCore` merges it in, keeping tab and divider.
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

### P3's intents on the real FM-1 (P1, 2026-11-14)

`PadsEditorIntents.swift` sends each pads and editor intent through the call the iPad uses for the same thing:
- **Pads** go through `SkiffSongStore`: `launch` for a tap (a waiting pad tapped again relaunches the entry playing), LIST `new` / `set` / `clear`, PERFORM `mute` / `store` / `recall` / `cancel`, and `select(track:)`.
- **The editor** goes through `Session.write(track:index:)` (with Skiff's extra bytes for CHANCE, COND and NUDGE, as StepInspector does), `setLength` for LENGTH, `deleteMotion` and `clearLocks` for the locks, and `lockStep` for Lock held or latched.

One `stepAdjust` unit is the panel's − / + step (VELOCITY 4, CHANCE 5, the rest 1), as P3's fake has it. Calls made:
- **Write intents are refused in PhoneCore while read-only** (`canWrite`, from the link's switch) and logged, so Session's optimistic copy never shows a change that the guard then dropped. The guard stays underneath (tested).
- **The song store takes one op at a time.** An op turned down (busy, stopped only, patterns full) is logged as "FM-1 refused: …". A screen for it is still to come.
- **Storing over a kept scene asks in place on the screen** (like Clear), and an empty scene stores at once (Scott, 2026-11-14). The screen sends `sceneStore{scene, confirmed: true}` after its row. The core refuses an unconfirmed store over a kept scene (`confirmed` defaults to false). The row itself is P2/P3's.
- **The FM-1's keys never write from the phone** (decision 5 revised by Scott, 2026-11-14: "the fm1 keys should work just like they do on the ipad"). A first version entered keys into the selected step; on the device every key pressed while stopped wrote a step and moved on, and 14 keys replaced a pattern. It was removed. `Session.onDeviceNote` stays only to count notes for the debug screen (`diag.notesIn`). Step entry from the keys is the FM-1's own; Skiff's FREE TAKE picker comes in a later phase, as on the iPad.
- **`editor.chord` is always false** (no Chord entry on the phone; the field stays until both sides drop it). **`editor.values` and `lanes` come from MOTION**, read for the editor's track every 3 s.
- **Lock from the phone catches only Lupe's own knob turns**, as on the iPad: fine for now (Scott, 2026-11-14). It waits on P4's `setParam` reaching `Session.set`.
- **The song lists are kept current:** PhoneCore runs `SkiffSongStore.follow()` while connected, as the iPad's Pads page does. A take-back (staging the entry playing) isn't counted as waiting. FakeSkiff now stages LIST PLAY while playing (lands 2 s on; PERFORM CANCEL drops it), from Skiff's protocol text.
- **`pads.kept`** lists the pattern numbers Set pattern may name (LIST SET takes a kept pattern). **`step.maxLength`** is LENGTH's cap (the next note). Both were added to the shared schema on 2026-11-14.
- **`pads.patternsFree`** (and `timeline.patternsFree`) is how many pattern numbers are free, 0…64, absent until the pool is read: New pattern and Duplicate need one (LIST NEW and COPY answer PATTERNS FULL at 0). **`pads.unused`** lists the kept patterns nothing uses (1…64), as the FM-1's CLEAR UNUSED counts them (POOL's uses: entries in any track's list and in the saved projects, and a track on it). Both come from the pool the core already reads; no clearing intent exists yet.
- **The `notice` area** (`Notice.swift`, `Notice.kt`): `{text, track?, entry?}` for every intent the core didn't carry out, with the reason and what to do. `track` is 1…6 and `entry` from 0, absent when the core doesn't know. It is an event, not a state: published as it happens, again when the words repeat, and never by the watch loop. It carries the FM-1's refusals (the song store's, with its track and entry: PATTERNS FULL, stopped only, one op at a time), the core's own (an empty pattern number, 16 entries, nothing to chain into, a block that's gone, automation full, a project or sound save refused) and the read-only guard, which is said once every two seconds at most so a drag doesn't repeat it. The log keeps the same lines. A malformed intent, or one the screen should have confirmed first, stays in the log only.
- **`clearUnusedPatterns{confirmed}`** (`ClearUnused.swift`): the FM-1's CLEAR UNUSED (POOL op 3) through `SkiffSongStore.clearUnused()`, as the iPad's pattern drawer. It clears every pattern in `pads.unused`, can't be undone, and works stopped only. A write: refused while read-only. The screen confirms first, listing `pads.unused`, and sends `confirmed: true`; without it nothing is sent. The answer is a notice: "Cleared N unused patterns. M pattern numbers are free.", "No pattern is unused…", "Stop playback to clear unused patterns…", or the FM-1's failure. The pool in the pads and Timeline areas is the one the FM-1 answers with.
- **Managing patterns** (board 79; `Patterns.swift`). Area **`patterns`**: `{free, kept, unused, recycle?, picturesWaitForStop, picturesLoading, patterns:[{number, len, uses, here:[{track, entry}], on:[track], saved, unused}]}`: the kept numbers only, from POOL and LIST, live and playing too. `saved` is true when the FM-1 counts more uses than this music shows (saved projects, the loaded music's own saved copy included). `recycle` is the number Recycle would take. Area **`patternPictures`**: `{pictures:[{number, len, drums, notes:[…], hits:[…], live}]}`, per step the highest note (-1: none) and the drum lanes hit. A pattern a track is on is drawn from the track (`live`, playing too); the rest are the FM-1's stored records (backup objects 16…31), read only while the sheet is open (**`patternsOpen{open}`**, not a write), only stopped, three quiet seconds after a stop or change, cached, and read again only where POOL changed. The first read on a connection sends BACKUP_LIST, which would stop playback: it is never sent while playing. Intents, each behind the read-only gate and answered with a notice: **`clearPatterns{numbers, confirmed}`** (POOL op 1 each, unused ones only, stopped only, sent only when confirmed), **`recyclePattern{track, entry}`** (the lowest unused number onto the entry by LIST SET, then POOL op 2 EMPTY; stopped only; its old steps are gone), **`copyPattern{number, track, entry}`** (an empty entry set to it, then LIST COPY; needs a free number; works playing).
- **Not built:** Select sound.

Device check: `qa/device-checks/2026-11-14-android-p1-writes.md`.

### P5 core: mix, sounds, projects (P1, 2026-11-14)

The schema is `P5State.swift` mirrored by `P5State.kt`, the builders `P5Areas.swift` and the intents `P5Intents.swift`, each through the iPad's call:
- **Mix:** `Session.set(track:param:)` for LEVEL, PAN and the REVERB send (the FX page's knob 4, read for every track every 3 s, as the iPad's Mix strips do), and `set(global:)` for the cards (GLO's DELAY, REVERB, CHORUS and GLOBAL pages, 2.5.1's DELAY MODE as a setting). Solo is `SkiffSongStore.toggleSolo`. Picking a section moves the FM-1's screen when linked, and that part is a write.
- **Sounds:** `loadPreset`, `loadUserPreset`, `storeUserPreset` (SAVE) and `eraseUserPreset`. A pad's own sound (decision 15) goes through the store's rewrite on the block's first entry, as `ArrangeEdits.setSound` does. Choosing another track as the target selects it first, so PRESET can't land on the previous track. Kits are a drum engine's presets.
- **Projects:** the FM-1's four slots: `loadSkiffProject`, `saveSkiffProject` (Save, Save as) and `renameSkiffProject`, which is new (PROJ_NAME op 2, in SloopKit's driver and taught to FakeSkiff from EDITOR_PROTOCOL.md). FakeSkiff also gained PROJ_NAME's "changed" byte.
- **Confirm in place** for anything that loses something: Load while the music has unsaved changes, Save over the music's slot, Save as over a used slot, SAVE over a used user slot, and erase. The core refuses these unconfirmed and logs why.

Device check: `qa/device-checks/2026-11-14-android-p5-core-writes.md`.

### P6 core: timeline and automation (P1, 2026-11-14)

The schema is `P6State.swift` mirrored by `P6State.kt` (published first, 100a607). The builders are in `P6Areas.swift` and the intents in `P6Intents.swift`.
- **Timeline:** each track's list as blocks in bars. It comes from `SkiffSongStore.blocks` and `marks`; bars are ticks ÷ `SongPlacement.ticksPerBar`. The block edits (insert, new, move, stretch, delete, set pattern, duplicate, chain, split) are a **port of the iPad's ArrangeEdits** (`ios/FM1/SkiffArrangeParts.swift`): the same SloopKit pieces in the same order, ending in the store's `rewrite`. Playback mode is `store.send(.song(_))`. **Follow-up:** move ArrangeEdits into SloopKit, so both apps share one copy. That touches the iPad and needs its own device check.
- **Automation:** one lane at a time (decision 7). It draws through `MotionPaint.plan` and `Session.paintMotion`, as the iPad's lanes do, and clears with `clearMotionLane`. The lane shown is the screen's own (`automationLane`), so it is not a write.
- **Confirm in place:** drawing (or locking) where the lane shows recorded data, including a change held from an earlier step (decision 16, judged by `TrackMotion.value(of:at:base:).source`); clearing a lane; and a block edit that would erase a pattern used nowhere else (`store.erased`).

Device check: `qa/device-checks/2026-11-14-android-p6-core-writes.md`.

### Back, the lag, and page parity (P1, 2026-11-14)

- **goHome** (decision 19: Android's back gesture is the only way back from a sound page). JSON `{"intent":"goHome"}`,
  Kotlin `GoHome` (`PageState.kt`). It sends SCREEN_GOTO 127 (a HOME tap) through `Session.showOnDevice`, as the
  iPad's HOME key does. It's a write, so it's refused while read-only. The shell's bottom is the editor again at once:
  `shell` and `page` are published in the same call, from Session's optimistic screen, then follow the FM-1's reply.
- **The sound key's lag:** `pickPage` (and `goHome`, `pickRoute`, `pickTile`) publish their areas in the intent's own
  call instead of a frame later. On the Mac that takes intent → page from about 22 ms to 1–2 ms. A trace (`lag` lines
  in LupeLog, Swift and Kotlin on one clock) is there for the Pixel. See `android/notes/page-lag.md`.
- **Parity with the FM-1** (decision 22): `PageParityTests` checks every Skiff 2.5.1 sound page's reach, labels and
  value text against what Skiff's own code prints (`android/scripts/skiff-page-dump.sh`). The fixes are in SloopKit
  (shared with the iPad): Skiff's number rules, FM6's names, the engine's descriptors read after a PRESET, and
  FakeSkiff's per-engine DESC and PRESET. What it can't decide is in `android/notes/page-parity.md`.
- **HOME's four knobs** (decision 21, board 70): the `homeKnobs` area (`HomeKnobs.swift`, `HomeKnobsState.kt`) and
  the `setHomeKnob` intent (slot 0…3, raw value; a write). The area carries the selected track's engine's four main
  parameters (`SkiffHomeKnobs`, from each engine's `.knob` line) in PageControl's shape, built by the same
  `PageArea.control` as a page's columns. `hot` and `hotSeq` mark the knob last turned on the FM-1. The link's
  CHANGED names the parameter, not the screen, so it's hot from any page. `fm1Home` says whether the FM-1 is on HOME.
  The reading and the write live in SloopKit (`SkiffHomeKnobs.swift`: `DeviceSession.homeKnobs`, `shownParam`,
  `setHomeKnob`), shared with the iPhone; `HomeKnobs.swift` only puts them in the wire's shape. The read-only gate
  stays with each app.
- **The FM-1 button block** (decision 24, board 72): the `screenGoto` intent (`screen` GLO, SAVE or SEQ, an optional
  `page` of that key's; SCREEN_GOTO, a write) and the `fm1Screen` area (`ScreenArea.swift`, `ScreenState.kt`). The
  area names the key whose screen is up, its page and title (SAVE's PRESETS, USER, PATTERNS, PROJECT), and the MENU and
  layer. Both use SloopKit's `SkiffButtonMap.place`, the iPad's table. P2 owns the Kotlin `ScreenGoto` class.
- **The sheets and the page's new shape** (decision 25): OPERATOR, ALL OPS and SOUND give the four controls the FM-1's
  knobs turn: the window SELECT is on, from the screen link's second cursor. `Sheets.swift` ports Skiff's `ui_fm6.c`
  and `ui_dx.c`, with `SkiffSheetTables.swift` generated from Skiff's own arithmetic. setParam writes FM6_PUT or
  KIT_PUT, and the sheet is read again every 300 ms while it shows, because the FM-1 pushes neither. The page area
  lost `graph` (its picture values, `fm6`, `sheet`) and gained `title`, `tiles` (MOD's routes, or the names a knob
  picks from) and `window`. P2 owns `PageState.kt`. The phone can't move a sheet's window: see
  `android/notes/page-parity.md`.
- **Note entry** (decision 28, board 73: the landscape Edit tab's keyboard strip), in `NoteEntry.swift`:
  - `setStepNotes` (step, notes): one note, a chord of up to four, or `[]` to clear.
  - `toggleStepNote` (step, note).
  - `toggleHit` (lane, step), for kit tracks.
  - `playNote` (note or lane, on): a note-on and note-off on the track's channel, written nowhere.

  They go through `Session.write`, `Session.toggle` and `noteDown` / `noteUp`, the iPad's calls. All are refused while
  read-only. Skiff takes step writes while it plays, so none is refused for playing. The editor area's steps gain
  `notes`, `hits` and `locked`; the area gains `maxNotes`, `kitLanes` and `kitNotes`. P2 owns the Kotlin classes.
- **The clock and the launch countdowns** (Scott's play test, 2026-11-14), in `ClockArea.swift`:
  - A `clock` area gives a reference the screens run forward each frame: `ticks` (MIDI clock pulses since Start) at
    `atMs` (uptime milliseconds), and `ticksPerSecond`. A new reference comes every beat.
  - Each pads row gives its pass as ticks (`passTicks`, `passStartTick`), a pending mute or solo, and `launchTick`,
    the pulse its launch point comes on. Waiting entries and waiting scenes carry `launchTick` too. With no clock
    they are null, and the outline is drawn dashed.
  - `top.bar` now wraps within `top.bars`: the selected track's block in Loop, the song in Song (Once doesn't wrap).
    Skiff's own screen shows no bar or beat while it plays, so this rule is Lupe's.
  - `atMs` is read from CLOCK_MONOTONIC directly (the clock `SystemClock.uptimeMillis` reads). Each wait is logged
    to LupeLog as it starts and ends ("wait: T1 pad 6 lands at 192 (clock running, …)").
- **The pictures' data** (decision 30: pictures are a setting), in `PagePictures.swift`: the page area's `graph` is
  back as it was before b672052 (the picture values, `fm6`, `sheet`), beside `title`, `tiles` and `window`. Mix's bus
  cards carry a `graph` too: kind delay, reverb, chorus or global, with the four knobs' values.
  The FX family's DELAY, REVERB, INSERT, SLICER and DUCK send graphs too (kinds fxdelay, fxreverb, insert, slicer,
  duck), with what their own knobs don't hold: the delay bus's MIX, INSERT's MIX, and DUCK's source hits and release
  as parts of a bar.
  SEL › CHORD and SEL › FOLLOW send graphs as the iPad draws them. `chord`: `notes` (the MIDI notes a key plays on the
  track's ROOT from C4, resolved by `SkiffChord` from CHORD, SCALE, VOICE and ARP), `root` (pitch class), `title` (its
  name), `caption`, and `values` [ms, dir] when strummed; with no chord, `notes` is empty and `title` and `caption` are
  the two lines that say why. `follow`: the same two lines, and `follow` {track, trackName, mode, by, kit}, absent
  when off. The followed track's live chord isn't sent to an editor, so there are no notes for FOLLOW.

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
