# Device check: claude/audio-through-398a74, 2026-11-15

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session runs it on the Pixel 10 Pro and the Pixel 7 with the FM-1; checks 13–15 are on the iPhone. The branch merges to the trunk only after it passes.

**What it is.** *Play through the phone*: the FM-1's USB audio input plays on the phone's speaker or headphones, as the iPad's and iPhone's "Play through the iPad/iPhone" do. It's a native AAudio engine (`android/app/src/main/cpp/through/`, no Oboe dependency, built by `android/scripts/build-through.sh`) in place of the spike's AudioRecord/AudioTrack:

- **One callback.** The output stream's callback reads whatever the input has (non-blocking), then fills its buffer. Both streams ask for low latency and exclusive (MMAP) sharing; AAudio falls back to shared on its own, and the screen shows what was granted.
- **The FM-1 at its own rate.** The input opens at the phone's USB rate (no framework resampling). A 32-tap windowed-sinc resampler goes to the output's rate: ~97 dB SNR on the host test, where the spike's linear one measured 20 dB at 10 kHz.
- **Adaptive buffer.** A PI loop holds the buffer's mean on a target by nudging the ratio, at most ±0.2 % (3.5 cents, inaudible). This also absorbs the FM-1's clock, which is ~400 ppm fast. The target follows the jitter actually seen (how far the fill dips), grows on an underrun and decays with a 30 s half-life.
- **Dropout detector.** Skiff dithers its output, so it never sends exact digital zeros or exactly repeated frames inside a signal. When they arrive, the phone's USB path filled a gap. The screen counts these as **phone gaps**, apart from **Lupe gaps** (our own underruns). This is the number that tells "Lupe's fault" from "the Pixel HAL's fault".
- **Where the switch is.** In the FM-1 (song-name) menu: *Play through the phone*, checked, with a line saying where it plays and the delay. In Settings › Audio: the switch, the output, the delay on the phone, a Bluetooth note, and a Details line for this check.

**Setup:** FM-1 on Skiff-Lupe 2.5.1 over USB-C · Lupe from this branch, built and installed by the main session · wired headphones through a powered USB-C hub with a headphone dongle, or the phone speaker at low volume · Bluetooth buds for check 7 · the Mac on wireless adb to count the HAL's log lines.

```bash
cd ~/code/fm1-ipad/.claude/worktrees/audio-through-398a74/android && ./gradlew :app:installDebug
```

Launch flags, for the comparisons. All are optional. The defaults, since the first Pixel run (cea014e), are rate 0 (the phone's USB rate), **input shared** (the Pixel 10's exclusive/MMAP USB input inserted ~45 gaps a second, the crunch) and output exclusive. Add `--activity-single-top` to change them on a running app; without it Android only brings the app to the front and drops the extras. A cold start (`-S`) works as well.

```bash
adb -s <pixel> shell am start --activity-single-top -n com.scottgerstl.lupe/.MainActivity --ez through true --ei throughRate 0 --ez throughExclusiveIn false --ez throughExclusiveOut true
```

Logcat (`adb -s <pixel> logcat -s LupeThrough`) shows:
- each decision (`check: starting …`, `no FM-1 audio input listed; retrying`);
- every restart, with its stream and AAudio error;
- a `stats:` line 1 s after a start and then every 5 s, from its own thread;
- `poll ran N ms after the last` when the main thread is busy.

**phone gaps** now also counts in the FM-1's quiet. Its dither makes a 32-frame run of exact zeros a gap, not silence (host test: 266 of 269 found, no false ones). If the input is pure digital zero for 0.5 s, the line says `(blind: the input is digital silence)`.

Count the HAL's dejitter lines while it plays: `android/scripts/count-dejitter.sh 10 -s <pixel>` (brought over from the spike). Or by hand:

```bash
adb -s <pixel> logcat -c; sleep 10; adb -s <pixel> logcat -d | grep -c "Dejitter underrun"
```

**Back up first?** No. Nothing here writes to the FM-1: the audio is read-only, and the MIDI link does what it always does.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Pixel 10 Pro, FM-1 plugged in, a pattern playing. FM-1 menu › *Play through the phone*. Allow the microphone when Android asks (it counts USB audio as a microphone). | The sound comes out of the phone. The menu line says "Playing on Phone speaker · NN ms" (or the headphones). | – | ☐ pass ☐ fail: |
| 2 | Settings › Audio. Read the Details line with the FM-1 playing for 30 s. | Write down: rates (expect `48 → 48 kHz`), in/out exclusive or shared, in + buffer + out ms, burst, ppm (expect about +400), Lupe gaps, phone gaps, xruns. | – | in __ out __ · in/out ms __/__/__ · ppm __ · Lupe gaps __ · phone gaps __ |
| 3 | **Listen** (wired headphones). Hold one plain note (a sine-like patch) for 20 s, then play the pattern. | No crunch. If it still crunches: note whether **phone gaps** climb with it (then it's the phone's USB path, before Lupe) or **Lupe gaps** do (then it's ours). | – | ☐ clean ☐ crunch · phone gaps/10 s __ · Lupe gaps/10 s __ |
| 4 | Count the HAL's `USB RX Dejitter underrun` lines for 10 s while it plays (command above). | The spike saw about 100 a second. Write the number. | – | lines/s __ |
| 5 | Relaunch with `--ez throughExclusiveIn true` (the old default), then with `--ei throughRate 44100`. Repeat checks 2–4 each time, **with the FM-1 playing** (peak above 0). | First run: exclusive input gave ~45 phone gaps a second (the crunch); shared gave none, but its run was silent, so check that again with sound. | – | shared: lines/s __ gaps __ · 44.1: lines/s __ gaps __ |
| 6 | **Delay by ear.** Wired headphones on the phone, the FM-1's own jack on the other ear (or switch). Tap a key. | The Delay line's number, and a judgement: ☐ fine to play on ☐ listening only. The number covers the phone (USB in to the output). The FM-1's own ~4 ms before USB isn't in it. | – | delay __ ms · ☐ play ☐ listen |
| 7 | **Bluetooth buds** connected while it plays. | It moves to the buds by itself within a second or two. The menu says "… + Bluetooth", and Settings shows the Bluetooth note (it adds its own delay, which the phone can't measure). Judge as in check 6. Codec from Developer options › Bluetooth audio codec. | – | ☐ pass · codec __ · ☐ play ☐ listen |
| 8 | Unplug the wired headphones, then plug them in again (or disconnect and reconnect the buds). | It follows the output each time without a crash; the Output line changes. | – | ☐ pass ☐ fail: |
| 9 | Unplug the FM-1 while it plays, wait 5 s, plug it in again. | "No sound from the FM-1 over USB" while it's out, and it plays again by itself when it's back. The phone's own microphone never plays (no howl). | – | ☐ pass ☐ fail: |
| 10 | Press Home with it playing, then come back. | The sound stops in the background (Android needs a foreground service to record there) and comes back on return; the switch stays on. | – | ☐ pass ☐ fail: |
| 11 | Leave it playing 5 minutes, phone untouched. Read Details again. | Lupe gaps stay where they were after the first seconds. The buffer (the middle ms) stays put rather than creeping up. The MIDI link stays connected. | – | Lupe gaps __ · buffer ms __ · ☐ link ok |
| 12 | **Pixel 7**: checks 1–4 again. | The comparison: if the Pixel 7 is clean and the Pixel 10 isn't, the crunch is the Pixel 10's USB audio path (its offload HAL), not the FM-1. | – | ☐ clean ☐ crunch · lines/s __ · phone gaps __ |
| 13 | **iPhone**, FM-1 plugged in, no headphones: song-name menu › *Play through the iPhone*. | The sound comes from the **speaker at the bottom**, not the earpiece at the top (fixed today: the iPhone needs `.defaultToSpeaker`; the iPad never did). | – | ☐ pass ☐ fail: |
| 14 | iPhone: plug in wired headphones, then connect Bluetooth headphones. | It follows to each. The menu's note line says "Playing through …". | – | ☐ pass ☐ fail: |
| 15 | iPhone: Settings › *Play through the iPhone* off, then on. | The FM-1's own speaker goes quiet while the iPhone plays and comes back when it's off (SessionUpkeep, the same as the iPad). | – | ☐ pass ☐ fail: |

**What the numbers mean.**
- **in:** the input stream's own age, from its timestamp.
- **buffer:** Lupe's adaptive buffer plus the resampler's 0.3 ms.
- **out:** written but not yet heard, from the output's timestamp.
- **The Delay line** is their sum, the phone's share. Bluetooth adds its own after that, and no app can measure it.
- **Lupe gaps:** our buffer ran dry and we played silence. After the first seconds, more than one a minute is a fail.
- **phone gaps:** exact zeros or repeats arrived from the phone's USB path. Skiff never sends those.
- **xruns:** AAudio's own counts, in/out.

## Checked here, and not

**Checked here.**
- **Host test.** `android/app/src/main/cpp/through/tests/run.sh` (clang, ASan/UBSan) covers:
  - the resampler's SNR at 44.1→48, 48→48 and 48→44.1;
  - the adaptive buffer for 60 s against a model of Skiff's packets, with the phone clock at −500/0/+300 ppm, hand-overs every 1, 4 and 10 ms up to 5 ms late, and 30 ms stalls. Zero Lupe gaps after the first 3 s; the stalls cost at most 2, then the buffer grows;
  - the dropout detector: it found 310 of 313 injected gaps and none on a clean stream.
- **Kotlin tests:** `AudioThroughModelTest`.
- **Builds:** `assembleDebug`, and the iOS simulator build.
- **The emulator** (P1_Phone, API 36.1, arm64, its default input with `--ez throughAnyInput true`): see the emulator section below.

**Not checked.**
- Anything with the FM-1, the Pixels, Bluetooth or a real iPhone.
- Whether the Pixel's USB input grants exclusive/MMAP.
- Whether the crunch is gone.

### Emulator measurements

These came from an emulator of my own (P1_Phone, API 36.1, arm64, 4 GB, started with `-port 5600`; Medium_Phone on 5584 belonged to another session and wasn't touched), using its default input (`--ez throughAnyInput true`). There's no USB audio on an emulator and its input is silence, so these numbers say the path works, not how the Pixel will do.

- **Streams:** in dev 8, 48000 Hz stereo, shared; out dev 2 (speaker), 48000 Hz, burst 960 (20 ms), shared, *not* low latency. The emulator only has the legacy path, no MMAP, so exclusive is refused and AAudio fell back as designed. With `--ei throughRate 44100` the input opened at 44100 and the resampler ran 44.1 → 48.
- **Delay (the Details line, settled, 100 s):** in 10–95 ms + buffer 80–300 ms + out 77–150 ms, total 236–445 ms. The emulator's host-audio bridge delivers in uneven 20 ms+ lumps (jitter measured 60–120 ms), so the buffer grew to the 120 ms cap. Lupe gaps: 2 in 100 s; catch-ups 3; ratio swinging ±2000 ppm (chasing that jitter); phone gaps 0, the detector's clean case.
- **The spike on the same kind of emulator** showed a 1088-frame burst and 560 ms total. Neither number predicts a Pixel. The host test's model of a phone with 1 ms USB packets and 4 ms hand-overs settles at about 11 ms of buffer with no gaps.
- **Found on the emulator and fixed:** the input age at first used Lupe's own frame count against AAudio's timestamp. That drifts when the input drops frames (it read 26 s after a minute on a starved emulator). It now uses `AAudioStream_getFramesRead`, which is in the timestamp's own frame base.
- **Seen on screen:** FM-1 menu › *Play through the phone* ✓ "Playing on Phone speaker · 390 ms". Settings › Audio: the switch, Output, Delay, Details. The menu line wrapped between "390" and "ms", so it now uses a no-break space.

### What to expect on the Pixel, and the plan for the run

The Pixel 10 Pro reported a 5 ms burst with low latency granted in the spike.

**If** its USB input gives a steady stream (no HAL gaps), expect:
- out ≈ 2 bursts (10 ms) or 1–2 ms more on MMAP;
- buffer ≈ 3–8 ms (whatever the USB path's hand-over jitter needs);
- in ≈ 2–10 ms.

That's a phone share of about **15–30 ms**, against the spike's 170.

**If** the HAL keeps logging dejitter underruns, the *phone gaps* count shows it. Lupe's buffer can't repair sound that arrived already broken. That decides the firmware and HAL questions below, so checks 3, 4, 5 and 12 matter most.

Order for the main session:
1. Check 1 (it plays).
2. Checks 2–4 at the defaults.
3. Check 5's two variants.
4. Check 12 on the Pixel 7 (same build).
5. The rest.

Send back the Details line from each variant (or `adb -s <pixel> logcat -s LupeThrough`, a `stats:` line every 5 s) and the dejitter count.

## iPhone: AudioThrough in the phone layout

**Where it is.** The iPhone already has the iPad's AudioThrough, the same class with nothing forked:
- the song-name menu's *Play through the iPhone*, checked, with a note line giving the summary (`PhoneHeader.swift`);
- Settings › *Play through the iPhone*, with the same action line as the iPad (`SettingsSheet.swift`);
- the same upkeep on `PhoneAppView` (`sessionUpkeep`: re-check on connect and on return to the front, the FM-1's speaker muted while it plays, Now Playing).

**Fixed today.** The audio session was `.playAndRecord` without `.defaultToSpeaker`, a choice made for the iPad (2026-11-02). On an iPhone that plays to the **earpiece** when no headphones are on. It now adds `.defaultToSpeaker` on the iPhone only (`AudioCore(isPhone:)`), and the failure text says "iPhone audio couldn't start" there. It builds for the simulator. Not run on an iPhone: check 13.

**Gaps noted, not changed:**
- The iPhone shows no delay figure; Android now does. AVAudioSession's `inputLatency + outputLatency + ioBufferDuration` (20 ms) would give one. Worth adding to the note line for parity, if Scott wants it.
- The iPad/iPhone keep a fixed 20 ms IO buffer, "for listening, never for playing live" (2026-11-02). Android aims as low as the stream allows. If Scott wants the same on the iPhone, it's one number (`setPreferredIOBufferDuration`), a Labs candidate (CLAUDE.md rule 3).
- Neither iOS layout says Bluetooth adds delay; Android's Settings does.

**Android gaps against the iPad/iPhone:**
- **The FM-1's speaker isn't muted while the phone plays.** iOS's SessionUpkeep calls `session.muteSpeaker`; the Android core (PhoneCore/FM1Link) has no such intent yet. A follow-up in the core.
- **No Now Playing / media session.** On iOS it's what let Sony XM6 buds take the stream (2026-11-02). Watch check 7 for buds that stay silent.
- **Sound stops in the background** (no foreground service).

**Structure map:** `design/structure-map.md` now lists Settings › Audio and the song-name menu's audio row, marked as started at Scott's request through the main session. The phone v1 list had "audio through the phone" as out. *Scott to OK where it sits* (CLAUDE.md rule 4).

## The firmware question

**The recommendation: don't change Skiff-Lupe's USB audio yet.** Run checks 3–5 and 12 first. The evidence so far points at the Pixel 10's USB audio path, not at the FM-1's pacing.

**What the FM-1 does today** (`firmware/src/usb.c`, Skiff-Lupe 2.5.1, `uac_packet`):
- The endpoint is asynchronous isochronous IN, one packet per 1 ms USB frame.
- At 48 kHz each packet is 48 frames, with one more or one fewer only when the ring's fill at the last render start (`fill_min`) is outside 87..139. At 44.1 kHz it's the 44/45 pattern with the same ±1.
- The FM-1's I2S clock is about 44,117.6 Hz against the host's 44,100, about 400 ppm fast. So on average about 19 packets a second must carry 49 frames.

**The host test's model of that code** (`testPacing`, 60 s):
- Today's rule sends 48s and about 19 49s a second, no 47s. The running sum's spread within any 16 ms is **2.9 frames**, inside the Pixel's 16-frame dejitter ("Size 16").
- The proposed even pacing (a filtered fill driving a fractional rate, spread by an accumulator) brings that to 1.0 frames.
- So, on paper, the FM-1's pacing shouldn't starve a 16-frame dejitter.
- And the spike's ~100 HAL lines a second don't match a ~19-a-second event. 100 a second looks like every HAL period (10 ms), a structural starvation in the Pixel's path, not the FM-1's ±1 frames.
- *The model assumes renders on time; under heavy CPU the real firmware could send late 47s that the model doesn't. Check 2's ppm and the comparison in check 12 test that.*

**A feedback endpoint doesn't apply.** In USB Audio 1.0 a feedback (synch) endpoint serves an asynchronous *OUT* (sink) endpoint. For an asynchronous *IN* (source) endpoint like the FM-1's, the packet sizes themselves carry the rate, which is what Skiff does. The spike's idea of adding one would not change what the host receives.

**If the device run says the FM-1 should change**, the options and their cost against the ~3,204 bytes of flash free on Skiff-Lupe 2.5.1 (release, `skiff-2.5.1-rebase.md`):

| Option | What changes | Flash (estimate) | CPU | Expected effect |
|---|---|---|---|---|
| A. Even pacing | `uac_packet`'s band rule → a filtered `fill_min` (IIR), a PI rate in Q16, an accumulator that adds the 49th frame evenly | ~120–200 B (a dozen lines of integer C, three words of state) | nil | Spread within 16 ms 2.9 → 1.0 frames (model). Same average rate. Helps only if the HAL is sensitive to short-term ±1 clusters. |
| B. SOF-locked rate | The FM-1's USB audio follows the host's 1 ms frames exactly: every packet is exactly 48 (or the exact 44/45 pattern), the drift taken up by a variable-ratio resampler (the 160/147 FIR driven by a phase accumulator steered by the SOF count) | ~0.6–1.2 KB (phase accumulator, SOF counting, interpolating between adjacent phases) | the 48 kHz FIR's cost about doubles (two phases per output frame); Skiff already measures ~65 % CPU under load | The stream looks synchronous: nothing for any host's dejitter to absorb. At 44.1 kHz it adds a resampler where today there is none. Quality cost: nearest-phase alone would be about −47 dB at 10 kHz; interpolating keeps it near today's. |
| C. Nothing in firmware; bypass the HAL in the app | Lupe claims the FM-1's audio streaming interface over usbfs and reads the isochronous packets itself (libusb on the UsbManager file descriptor) | 0 | app side | Removes the Pixel's dejitter entirely. But detaching the kernel's audio driver tears down the whole USB audio card, MIDI included, so FM1Link would need its own usbfs MIDI too. A large job; only worth it if B is refused. |

Before any of them, a read-only look costs nothing: a Skiff build with the serial console (`FELUCCA_CDC=1`) reports `uac_adj_up`, `uac_adj_down`, `uac_missed`, `uac_underruns` and `uac_fill_lo/hi` (`console.c`, `con_uac`). That's the FM-1's own count of short and long packets during a Pixel session. It needs a flash, so it's Scott's call, with a backup, and not part of this check.

**After the run:** record the numbers in the vault note `Projects/Dev/fm1-ipad/bluetooth-poc.md` (the audio spike section). Failures go on the batch list with the check number.

## Round 2: both Pixels, both input paths (after dd12637)

**What came back.**
- **Pixel 7, shared input:** 17.9 ms, Lupe gaps 0, phone gaps ~67 a second, dejitter 316 in 22 s.
- **Pixel 7, exclusive input:** 16.9 ms, phone gaps ~25 a second, dejitter 280 in 22 s.
- **Pixel 10, shared input:** Scott: the crunch is "still there". The earlier 0 was the silent-input blind spot.

So both phones insert gaps on both paths, and Lupe adds none. *Scott's ear; the counts from the session's runs.*

**A correction to round 1's firmware read.** Round 1 said the evidence pointed at the Pixel 10's MMAP path. It doesn't: the gaps come with any Pixel input path, so the MMAP-path explanation is out.

**The working hypothesis (H), to test, not yet shown:**
- The phones' USB capture takes a fixed number of frames per USB millisecond (48), with a 16-frame cushion ("Size 16"). It does not follow an asynchronous source's real rate.
- So any clock offset between the FM-1 and the USB frame clock empties or overfills the cushion at a steady rate: one glitch per frame of mismatch, |offset| × 48,000 a second.
- The dejitter counts fit: 316 in 22 s is 14 a second, which would be a ~300 ppm offset. usb.c's own comment puts the FM-1's I2S about 400 ppm off 44.1 kHz.
- An ordinary USB mic is within ±50 ppm, about 2 glitches a second, which few would notice. The FM-1's offset is six times that.
- Note "phone gaps" counts more than the dejitter lines (25–67 against 14 a second). Before this commit the repeat rule fired on dither: three repeats of a flat waveform top happen by chance. It now needs 8 identical loud frames, and zeros and repeats are counted apart.

**How to tell the FM-1 from Android's USB path.** Cheapest first:

| # | Do this | It says |
|---|---|---|
| 16 | `android/scripts/dejitter-intervals.sh 20 -s <pixel>` while Lupe plays the FM-1 (either Pixel). | **Evenly spaced** lines (CV under 0.3) at ~70 ms mean H: a rate mismatch, and the script gives it as ppm. Irregular means load, the bus, or the FM-1's own pacing. It also lists the `Avail/Had/Received` numbers: always "Received 48" means the FM-1 sends steady 48s. |
| 17 | Lupe on the Pixel with `--ei throughCapture 10` (on a running app add `--activity-single-top`), the FM-1 holding a note. Logcat says `capture: … → <path>`; `adb -s <pixel> pull <path>`, then `swift tools/gapcount.swift file <the wav>`. | The real gaps: how long each is (one packet, 48? a few frames?), zeros or repeats, and their spacing. This is the raw input, before concealment. |
| 18 | **The FM-1 into the Mac**: `swift tools/gapcount.swift live 20 Felucca --wav /tmp/fm1-mac.wav`, the same held note, then the pattern. | **No gaps on the Mac, gaps on the Pixel**: the FM-1's stream is legal, and Android's USB path can't follow it (H). **Gaps on the Mac too**: the FM-1 sends them. Repeats mean its ring runs dry; zeros mean packets it never filled. |
| 19 | Any other class-compliant USB audio source (a USB mic or interface) into the Pixel, recorded with any app, while running check 16. | Clean, or a few lines a second: the FM-1's large clock offset is what trips the Pixel. As bad: the Pixel's USB capture is generally poor. |
| 20 | (If one is to hand) a non-Pixel Android phone (Samsung or any Qualcomm phone) with the FM-1 and Lupe. | Whether this is Google's Tensor USB stack (both Pixels have it) or Android's in general. |

**The firmware options, re-costed with H in mind.** Even pacing (round 1's option A) doesn't help under H: it spreads the 49s evenly but keeps the average rate, and the average is what the phone can't follow. What would help is making the FM-1's average rate match the USB frame clock exactly, so every packet is exactly 48:

| Option | What changes in usb.c | Flash (of ~3,204 B free) | CPU | Expected effect |
|---|---|---|---|---|
| A. Even pacing | the band rule → filtered fill + accumulator | ~120–200 B | nil | **Under H: none.** Kept only for the record. |
| B1. Exactly 48, with a sample slip | `uac_packet` always sends 48 (44.1: the exact 44/45 pattern). The ring absorbs the ~400 ppm, and when its fill leaves the band, one 48 kHz frame is dropped (FM-1 fast) or repeated (slow), crossfaded over ~16 frames so it doesn't click. That's ~19 slips a second at 400 ppm, each a one-sample time shift under a crossfade. | ~150–300 B | a few hundred cycles per slip | Under H: the phone's cushion never empties; no 48-frame holes. What's left is a one-sample slip 19 times a second inside the FM-1, far milder than a hole. Cheapest real fix. |
| B2. Exactly 48, variable-ratio resampling | the 160/147 FIR driven by a phase accumulator steered by the ring's fill (or the SOF count), so the FM-1 resamples its own clock to the host's | ~0.6–1.2 KB (accumulator, per-phase interpolation, steering) | the 48 kHz FIR's cost about doubles; Skiff is at ~65 % CPU under load | Clean: no slips at all. The quality cost is small if it interpolates between phases. Tight on CPU. |
| C. App bypass | none; Lupe reads the isochronous packets itself over usbfs | 0 | app side | Bypasses the HAL, but detaching the kernel's audio driver takes down MIDI too. Large; last resort. |

**Recommendation:** run 16–18 first (no flash). If 16 shows evenly spaced lines and 18 shows a clean Mac, H stands. Then **B1** is the firmware change worth building, as an experimental Skiff-Lupe build to test on the Pixel, with a backup first and Scott's go-ahead. B2 only if B1's slips are audible. If 18 shows gaps on the Mac, the problem is in the FM-1's own pacing or rendering, and the console counters (`uac_missed`, `uac_underruns`) come next.

**App-side stopgap, in this commit:** concealment, on by default (`--ez throughConceal false` to hear the gaps as they come).
- A run of exact zeros the phone filled is held back until it ends (5 ms at most), then concealed.
- **If the phone inserted the zeros** (extra frames: an underrun filled in), they're left out, and the next 32 frames fade from the frame before the gap. Nothing real is lost; the adaptive buffer evens it out.
- **If the phone replaced real frames,** the gap is filled with the frames just before it, faded in at the start and out into the stream.
- Which one it is gets judged every 2 s from the stream itself. Inserted zeros make the raw input run fast by about the gap frames (1.5 % at 15 gaps a second, against clocks within 0.05 %). The Details line shows it: `gaps inserted (1.04)` or `gaps replace (0.04)`. That alone answers how the Pixel fills its gaps.
- Host test, 15 gaps a second of 48 frames on a 0.3 sine. Inserted: the quietest millisecond of output goes from 0.008 (a hole) to 0.244. Replaced: from 0.000 to 0.179 (a short ~4 dB dip: the fill repeats a block that isn't period-aligned).
- Not concealed: gaps shorter than 4 frames after signal, or under 32 in quiet; repeats; the phone dropping frames without a trace.
- On the Pixel, compare by ear: `--ez throughConceal true` against `false` (check 21).

| # | Do this | You should see | Result |
|---|---|---|---|
| 21 | Pixel 10, shared input, the FM-1 playing. Launch with `--ez throughConceal false`, then `true` (cold start `-S`, or `--activity-single-top`). | By ear: the crunch with it off; with it on, gone or much less. Details: `phone gaps N (Z zero, R repeat) · concealed C · gaps inserted/replace (x.xx)`. | ☐ gone ☐ less ☐ same · Z __ R __ · inserted/replace __ |
