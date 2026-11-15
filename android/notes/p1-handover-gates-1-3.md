# P1 hand-over (updated overnight 2026-11-13/14, branch claude/android-p1-core-link-faf639)

Nothing is pushed, and nothing is merged into the trunk. P2/P3 was merged into P1 twice (dcbfbb6, 0faf3b7) and P4 once, with Scott's approval. Latest P1 commit: see `git log`; e66ad7e is the last device result.

## Gates (BRIDGE.md §4)
| Gate | State | Evidence |
|---|---|---|
| 1 Builds | **Passed** | macOS 349/349 (with the `reading` flag), iOS Simulator build, emulator 261/261 (`android/scripts/sloopkit-android-test.sh`) |
| 2 Main actor | **Passed** | `looper-probe.sh` + control run on the emulator; in the APK, 74 µs per hop |
| 3 Bytes | **Passed on the real FM-1** (Pixel, read-only) | INFO decoded: "FELUCCA v2.5.1", 6 tracks, 15 engines. **The FM-1 runs Skiff 2.5.1.** |
| 4 Session | **Passed except unplug/replug** | ready on the Pixel, tempo 72, screen link live, 11-minute soak clean, nothing blocked. Unplug/replug within 2 s → Scott's morning check |
| 5 State | **Built; P2/P3's shell renders the real FM-1** | `link`, `top`, `pads`, `editor` from PhoneCore; fixtures recorded; Play/Stop wired, but **untested** (writes) → morning check 4 |

Morning device check: `qa/device-checks/2026-11-14-android-p1-morning.md`.

## Read-only by default
`LinkGate.readOnly` → `GuardedTransport`. Only Skiff's query forms (`skiff-src web/EDITOR_PROTOCOL.md`) pass; everything else is dropped and logged. No UI turns writes on (a tap from P2's screenshot script on the shared emulator hit such a button). Writes need `adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity --ez allowWrites true`. The Pixel is left read-only, with the debug screen or shell open.

## Fixtures
`RECORD_FIXTURES=1 swift test --filter FixtureRecording` in `android/core`. Areas PhoneCore doesn't publish yet (`shell`, P4's `page`) are carried over from the existing files, and those files stay `provisional: true`.

## Not done / follow-ups
- P4's `page` area: deliberately not done. See `android/notes/p1-page-area-brief.md` (needs `SoundPage` moved into SloopKit, which changes iPad code).
- P3's intents beyond padSelect/stepSelect (launches, edits, locks), and MOTION reads (locks, automation lanes).
- `shell` stays in Kotlin until the FM-1's page drives the bottom half.
- MIDI clock on the hardware (needs Play).
- APK size: about 100 MB of Swift runtime, 45 MB of it ICU.
- Fragile SloopKit tests: several session tests index arrays after a timed-out `waitFor`, so under load they crash the whole run instead of failing.
- The Pixel's logcat buffer is 256 KiB: stream logcat to a file for long runs; `logcat -d` after the fact loses lines.

## Toolchain
swift.org 6.4.2, Swift SDK for Android 6.4.2, NDK r30 (`android/scripts/env.sh`). Pixel over Wi‑Fi adb: `192.168.2.56:35413` (port may change: `adb mdns services`).
