# Device check: claude/android-p1-core-link-faf639, 2026-11-13

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the **Pixel 10 Pro** and the FM-1; the branch merges to `main` only after it passes. This covers P1's gate 3 (bytes) from `android/BRIDGE.md` §4. Gates 1 and 2 were proven on the Mac and an arm64 Android 16 emulator (below); check 2 repeats gate 2 on the Pixel itself.

**Setup:** FM-1 on Skiff-Lupe 2.2 · Lupe for Android, this branch (debug build; it includes P2's shell, merged in at 5bf7c67) · a USB-C cable from the Pixel to the FM-1 (the one that worked with Skiff's web editor on 2026-11-13) · no launch flags.
**Back up first?** No. Nothing here writes the FM-1's flash: the only thing sent is INFO, a read.

**The Pixel has one USB-C port**, so adb and the FM-1 can't both be plugged in. Install over USB first, then swap the cable to the FM-1; everything to read is on the debug screen (text is selectable, or take a screenshot). If you'd rather watch logcat too, use wireless debugging (Settings › System › Developer options › Wireless debugging, then `adb pair` and `adb connect`).

**Install** (Pixel on USB, from the repo root; Chrome's web editor tab closed so it doesn't hold the FM-1):

```bash
cd android && ./gradlew :app:assembleDebug
```

```bash
adb -s 59200DLCH0022G install -r android/app/build/outputs/apk/debug/app-debug.apk
```

**Open the debug screen** (it isn't on the home screen; the normal Lupe icon opens P2's shell on its fake core):

```bash
adb -s 59200DLCH0022G shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity
```

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | With the debug screen open and nothing plugged in, read the top. | "FM-1 link (debug)"; "FM-1: not found. Plug it in with USB."; the log starts with "Swift loaded; main actor hooked to the UI thread's Looper" and "0 MIDI device(s) at start". No crash, no "isn't responding". | – | ☐ pass ☐ fail: |
| 2 | Tap **Check main actor**. | Within a second: "Main actor: OK. 200 hops … each ran on the UI thread: true, round trip …µs". Note the µs number (about 74 on the emulator). | – | ☐ pass ☐ fail: |
| 3 | Unplug the Mac, plug the FM-1 into the Pixel (FM-1 on). Watch the log. Then **screenshot the "MIDI devices Android lists" block** and send it to the next session. | A line "added: #… USB ins=1 outs=1 [name=…, product=…, manufacturer=…] ports [in0=… out0=…]", then "opening device …" and "open: input port max message … bytes". The top reads "FM-1: open". If instead you see "not the FM-1: …", the screenshot is exactly what's needed to fix the match: send it. | – | ☐ pass ☐ fail: |
| 4 | Tap **Send version request**. | "→ INFO request [F0 7D 46 4C 01 F7]" then within a moment a line starting "← INFO: "FELUCCA v2.2" …, 6 tracks, … supported by Lupe: yes". Any "← …" line at all proves bytes go both ways; the decoded words prove SloopKit reads them on Android. | – | ☐ pass ☐ fail: |
| 5 | Unplug the FM-1, wait two seconds, plug it back in, tap **Send version request** again. | "removed: …", "lost: unplugged", "frames stream finished", top reads "not found"; after plugging back: "added", "opening", "open", and the INFO reply again. | – | ☐ pass ☐ fail: |

**Not covered here** (later gates, or not testable yet):
- `Session` reaching ready, the lost state and the 2-second reconnect: gate 4 (the debug screen reads the frames itself; no Session runs yet).
- `PhoneCore`, the `link` and `top` areas, Play from the phone: gate 5.
- Clock and notes from the FM-1 (they are assembled, but nothing shows them yet).
- Background behaviour (app switch with the FM-1 plugged in), and sending frames larger than the port's maximum message size (none today).
- VoiceOver/TalkBack: the debug screen is developer-only and not part of the release pass.

**Proven off the device (2026-11-13):**
- Gate 1: macOS `swift test` 349/349; SloopKit builds for iOS Simulator; on the arm64 Android 16 emulator 261/261 of the tests that build for Android pass (`android/scripts/sloopkit-android-test.sh`).
- Gate 2: `android/scripts/looper-probe.sh` passes on the emulator, and its control run (no hook) never reaches the main actor; inside the APK the debug screen's check passed (200 hops on the UI thread, 74 µs).
- `AndroidTransport` and `LinkGate`: 6 Mac tests (chunked bytes, clock inside frames, notes, send after finish, hand-out-once, a `DeviceSession` sending INFO through the gate).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device". Send the check 3 screenshot either way: the property strings go into `FM1Link.isFM1` and BRIDGE.md §1.

## Run overnight, 2026-11-13/14 (by the P1 session, read-only, Scott's approval)

Run against the Pixel over Wi‑Fi adb with the FM-1 on its USB port, not by hand. Checks 1–4 were done in that form: the install, the debug screen, the INFO round trip, and the device strings read from the Pixel. Check 5 (unplug and replug) needs a hand and moves to `2026-11-14-android-p1-morning.md`.

| # | Result |
|---|---|
| 1 | Pass: no crash, the log as described. |
| 2 | Pass on the emulator and in the APK (74 µs per hop). Not repeated on the Pixel. |
| 3 | Pass. The FM-1's strings: manufacturer "Hügelton Instruments", product "Felucca", name "Hügelton Instruments Felucca", USB 0x1209:0001, one port each way (names empty). Max message 1015 bytes. Chrome (Skiff's web editor) also held a connection to the device without its ports, which didn't get in the way. |
| 4 | Pass: `← INFO: "FELUCCA v2.5.1" (v2_5_1), 6 tracks, 15 engines, supported by Lupe: yes`. **The FM-1 runs Skiff 2.5.1**, not 2.2. |
| 5 | Moved to the morning check. |
