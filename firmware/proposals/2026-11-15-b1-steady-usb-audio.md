# Proposal B1: steady USB audio packets from Skiff-Lupe (48 kHz)

*Built and host-tested on the Mac (Scott: "Yes, Mac only"), then installed on Scott's FM-1 with a backup first (Scott: "Yes, back up first", 2026-11-15). Results below.* Written 2026-11-15 by the audio-through session (branch `claude/audio-through-398a74`). The evidence is in `qa/device-checks/2026-11-15-audio-through.md` (rounds 1–4), and the models are in `android/app/src/main/cpp/through/tests/through_test.cpp`.

## On the FM-1 (2026-11-15, Scott's go-ahead: "Yes, back up first")

**The install:**
- `tools/fm1fw` with the backup first: `2026-11-15 1901 v2.5.1.json`, 29 objects, every CRC checked. Then the dry run, then `--yes`.
- The FM-1 restarted as FM-1_725 with screen link v6 (Skiff-Lupe 2.5.1, not the take build).

| | before (2.5.1 release) | B1 |
|---|---|---|
| FM-1's rate by the Mac's clock | +422 ppm | **−26 ppm** (FM-1 silent) |
| Pixel 7, FM6 pad playing (peak ~0.49), concealment off: dejitter lines | ~14 a second, in bursts | **0 in 20 s, twice** |
| Pixel 7: phone gaps while playing | climbing | flat |
| Pixel 7: FM-1 against the phone | ±400 ppm | −8..+49 ppm |
| Pixel 7: Lupe gaps / xruns / total | – | 0 / 0 / 15–17 ms |
| Scott, by ear, the FM6 pad crunch | "still do it" | **"Gone"** |

- **Why the rate changed:** at 48 kHz the FM-1 now delivers exactly 48 frames per USB millisecond, so a host measures the USB clock, not the I2S clock. −26 ppm is the Mac's clock against the FM-1's USB frames.
- **The phone-gap counter climbed during silence (15,996).** That was the detector misfiring on Skiff's undithered silence, not real gaps. Fixed in the app the same day: gaps count only inside a signal.

**Still to run** (B1-1, B1-2, B1-3 on the Pixel 10, B1-5):
- the Mac with sound;
- 44.1 kHz on the Mac;
- the Pixel 10;
- the iPad (Play through the iPad, screen link, MIDI, a project load and save).

## Results (host only, 2026-11-15)

**The branch:** `lupe-skiff-2.5.1-b1` in `~/code/skiff-src`, commit **72d4170**, off `lupe-skiff-2.5.1-screen-link` (737e3fb). It's a separate worktree, `~/code/skiff-src/.claude/worktrees/skiff-b1`; the screen-link branch is untouched. Not pushed.

**The change:** `firmware/src/usb.c` behind `FELUCCA_UAC_STEADY` (1 on this branch, 0 gives Skiff's band rule back), plus a test-only hook `UAC_TRACE_OUT`, empty in the firmware.

**Size, measured** (release build `tools/build.py --release 2.5.1`, the same command as the shipped 2.5.1):

| | 2.5.1 (737e3fb, rebuilt here) | B1 | difference |
|---|---|---|---|
| App image | 578,360 B | 578,432 B | **+72 B** (3,132 B left of 581,564) |
| RAM .data + .bss | 86,296 of 94,208 | 86,312 | +16 B |
| Pool / RAM code + .ramx | 351,128 / 29,648 | the same | 0 |
| `.ram_text` (no calls), register access | ok | ok | – |

**Skiff's own host test** (`tests/uac_test.c`, which `#include`s the real `usb.c`), the B1 build:
- **Every 48 kHz packet is 48 frames:** 10,000 of 10,000 with random render times. Also with renders alternating 7 % / 85 % of a half, the band rule's worst case.
- **Every frame is the double-precision resampler at the exact phase `uac_tap48` used** (traced): 0 off, at the existing ±10 LSB tolerance. Phase steps are only 147, or 148/146 inside a slip.
- **Slips follow the clock:** 189 in 10 s at +400 ppm, where the clock needs 192. 0 slips the other way. A slow clock (44,085 Hz) gives only "one more" slips.
- **No underrun or overrun.** The fill at render start stays 76..169 of 512. 1,000 packets with 2.5 ms renders: no glitch.
- **Rate switches** 48 → 44.1 → 48 mid-stream are as before. The resampler's own response and SNR are unchanged.
- **The band-rule build (STEADY 0), for comparison:** in the same harness, 336 short and 530 long packets in 10 s of random render times, 47s and 49s in runs. That's what the Pixel's 16-frame cushion couldn't ride out.
- `run_tests.sh` now builds `uac_test` three ways (STEADY 1 with and without CDC, STEADY 0). All three pass.

**Skiff's whole host suite** (`tests/run_tests.sh` in the `skiff-tests` Docker image, amd64 under emulation, on a `FELUCCA_CDC=0` build): everything that touches this passes:
- all three uac builds, the USB descriptor layouts, the MIDI and USB tests;
- the 176 regression goldens (0 changed), health, voices, the CPU budget, and the second-core runs (bit for bit);
- the fuzzers.

The suite still ends "HOST TESTS FAILED", for reasons that have nothing to do with B1:
- `web/test_web.mjs`: two `fm1pkg.js` checks that want M-VAVE's stock packages (V016) fail the same way on untouched 737e3fb here. A third, "NEON LEAD … factory preset defaults", failed once in the long emulated run and passed both times when re-run alone: a flake.
- The ThreadSanitizer run can't start under amd64 emulation on Apple silicon ("unexpected memory mapping").

**The package, experimental and not for install:** `firmware/proposals/EXPERIMENTAL-Skiff-Lupe-2.5.1-b1.fwsc`, 610,429 B, SHA-256 `2cb940c71557049ba3c46f11d35311b1e69e81d1f9348d9e0b906ec82847383b`. App `felucca.bin` SHA-256 `46999bc9e2446dc5ce9b93f52cec9df0b51e6285ee9d39f609174b2c8ec7945b`.
- **Not pinned** in Lupe and not released.
- **Its identity is `FM-1_725`, the same as the 2.5.1 release** (`--release 2.5.1` sets it). **Open decision for Scott:** keep `FM-1_725` (Lupe would call it "Skiff-Lupe 2.5.1 · up to date" and couldn't tell the two apart), or give it its own identity (Lupe would offer the release over it, and could say which is installed).
- *Skiff's builds aren't byte-for-byte reproducible:* the rebuilt 737e3fb package here hashes `3238eb82…`, not the pinned release's `80b21b33…`. Only this exact file is what was tested.

## Why

- **The FM-1's stream is valid; Android can't follow it.**
  - On the Mac, the FM-1 recorded clean: 0 gaps in 20 s with sound playing (`tools/gapcount.swift live`, check 18). Its rate by the Mac's clock was **48,020.3 Hz, +422 ppm** (+441 on a silent run).
  - Both Pixels insert gaps on both input paths. They take a fixed 48 frames per USB millisecond from a 16-frame cushion, and write zeros when short or drop frames when over. Lupe judged the zeros as replacing real frames ("gaps replace (0.00)").
- **Two things feed those gaps:**
  1. The FM-1 runs ~420 ppm fast, so about 20 times a second a packet must carry 49 frames.
  2. **Render load:** Skiff's band rule (`uac_packet`: ±1 frame when `fill_min` at the last render start is outside 87..139) reacts to render timing. Late renders (FM6 pads) make runs of 47s and 49s. Check 16 on the Pixel 7 saw "Received 47" in 79 of 285 dejitter lines, in bursts (CV 1.67). Scott: "the FM6 pads still do it".
- **The model** (`testPhoneModel`: Skiff's packet rule against a phone taking 48 per ms with a 16-frame cushion):

| renders late by up to | today's rule: 47s / 49s a second | phone underruns / drops a second | B1: packets | B1: phone gaps | B1: FM-1 ring (of 512) |
|---|---|---|---|---|---|
| 0 ms | 0 / 20 | 0 / 20 | all 48 | 0 | 89..242 |
| 1 ms | 94 / 115 | 0 / 21 | all 48 | 0 | 65..270 |
| 2.5 ms (heavy load) | 260 / 281 | 21 / 41 | all 48 | 0 | 27..297 |

*The phone model is a reading of the Pixel's log line ("Avail/Had/Received … Size 16"), not its source. At zero load it predicts drops where check 16 logged underruns, so trust the direction, not the exact counts.*

- **Even pacing (round 1's A) isn't enough.** It removes most 47s, but keeps ~20 long packets a second, and a phone forcing its own clock drops each of them.

## What B1 changes

Every 48 kHz packet is exactly 48 frames. The FM-1's ring takes up its clock offset, and the ring is held in its band by a **slip**: one 48 kHz frame fewer (or more) made by the FM-1's own resampler, spread over ~3 ms.

The slip costs nothing in quality because of how `uac_tap48` resamples 44.1 → 48 kHz:
- It's a 160-phase polyphase FIR, stepping `UAC_FIR_M` = 147 phases per output frame (`ph += UAC_FIR_M` in its loop).
- Stepping **148** for ~148 output frames makes exactly one output frame fewer; **146** makes one more.
- Every output is still the same FIR at an exact phase, so nothing is interpolated or approximated. For 3 ms the time runs 0.7 % fast (12 cents), then it's back.
- Host test (`polySlipSnr`): SNR against the ideal sine at the warped times is **87.7–87.9 dB at 1, 10 and 15 kHz**, the filter's own floor. Each slip makes exactly one frame fewer.
- For comparison, a slip done on the ring's frames by interpolation (`slipSnr`): cubic 48 dB at 10 kHz, linear 38 dB.

Changes in `firmware/src/usb.c`, against Skiff-Lupe 2.5.1 (`lupe-skiff-2.5.1-screen-link`, 737e3fb), 48 kHz only:

1. **`uac_packet`:** when `uac.r48`, `n = 48` always. Drop the `fill_min > hi` / `< lo` adjustment for 48 kHz. The 44.1 kHz path keeps its 44/45 pattern and band rule unchanged: Android opens the FM-1 at 48 kHz, and Apple's hosts follow the asynchronous rate as they do today.
2. **`uac_render_start`, the fill filter**, once per render: `uac.fillq += (((int32_t)fill << 8) - uac.fillq) >> 7;` (Q8, about 128 renders ≈ 370 ms). Reset to `UA_PRIME48 << 8` where the ring is primed.
3. **The slip controller**, a PI loop plus an accumulator, once per packet in `uac_packet` (r48 only):

   ```c
   int32_t err = uac.fillq - (UA_MID48 << 8);                 /* Q8 frames; UA_MID48 = 113 (UA_PRIME48) */
   uac.integ = clamp(uac.integ + err / 64, -(1 << 20), 1 << 20);
   uac.acc += clamp(err + uac.integ / 64, -(1 << 16), 1 << 16); /* Q16 frames per packet */
   if (!rs.slip && uac.acc >= (1 << 16))  { rs.slip =  148; uac.acc -= 1 << 16; uac.adj_up++; }   /* too full: one fewer */
   if (!rs.slip && uac.acc <= -(1 << 16)) { rs.slip = -148; uac.acc += 1 << 16; uac.adj_down++; } /* too low: one more */
   ```

   These are the model's constants (`B1_SHIFT 7`, `B1_KP 1`, `B1_KIDIV 64`, per packet). They hold the slips at the clock's own rate, ~21 a second at +422 ppm, at every render load modelled. Faster constants chased render noise: 59 slips a second at 2.5 ms. *As built,* the loop runs once per render in `uac_render_start`, in the audio ISR with `uac_tap48`, so `rs.slip` has one writer and no race with TIMER5. Its constants are scaled for a render's 2.9 ms: filter `>> 7`, `sint += err >> 4`, rate `err * 3 + (sint >> 4)`.
4. **`uac_tap48`:** `ph += UAC_FIR_M;` becomes `ph += UAC_FIR_M + (rs.slip > 0) - (rs.slip < 0); if (rs.slip) rs.slip -= (rs.slip > 0) - (rs.slip < 0);`
   - Phases stay in 0..159, so the table lookups don't change.
   - The block's room check (`n + n / 8 + 2`) already allows one extra output frame.
5. **State:** `uac.fillq`, `uac.sint`, `uac.sacc` and `rs.slip` (int32 each): **+16 B of RAM, measured** (86,312 of 94,208). `adj_up` and `adj_down` now count slips, for the console.

**Flash: +72 B, measured** (the estimate was 100–200). That leaves 3,132 B in the release build. No extra CPU: the FIR does the same work per output frame.

**Latency:** unchanged (same ring centre, 113 frames ≈ 2.4 ms).

## Does B1 also need a render-jitter fix for FM6?

No separate fix: B1 is that fix.
- **Render timing no longer reaches the packets.** It only moves the ring's fill: 27..297 of 512 with renders up to 2.5 ms late, never empty, never over (`testPhoneModel`).
- **What remains:** a render later than the ring's margin would empty the ring. `uac_packet` then repeats its last frame (`uac.underruns`), which Lupe counts as **repeat** gaps (8+ identical loud frames) on the phone or the Mac.
- **If the FM6 test shows repeats:**
  1. Raise the centre: `UA_MID48` and `UA_PRIME48` +40 frames (+0.8 ms).
  2. At the same time grow the ring: `UA_N` 512 → 1024, +2 KB of RAM, no flash. The top of the range plus a render plus a packet (297 + 140 + 49) is already near 512.

## How to test it, without risking the unit

**On the host first (nothing flashed; done 2026-11-15, see Results):**
- Add `test_b1` to Skiff's own `tests/uac_test.c`, which `#include`s `usb.c` and already drives renders against packets (`run(ms, rend_ns, …)`):
  - every 48 kHz packet is 48 frames, with renders late by 0–2.5 ms;
  - the ring never empties (`uac.underruns == 0`) or overflows (`uac.overruns == 0`);
  - slips ≈ 20 a second at +422 ppm;
  - `test_resampler`'s sine fit is within 1 dB of today with slips running.
- Re-run Skiff's whole host suite and the build's size and `.ram_text` checks.
- The models in `through_test.cpp` (`testPhoneModel`, `polySlipSnr`) already pass.

**Then the device check, only with Scott's go-ahead (not given yet: "Mac only" covered the build and the host tests):**
1. **Back up first:** Lupe's install flow backs up the FM-1 before it writes and stops if the backup fails. Keep the backup's Files path.
2. **Package:** build `Skiff-Lupe 2.5.1-b1` from a branch of `skiff-src` (not `main`, not the release tag), as a `.fwsc`, with its SHA-256 recorded.
   - *Decision for whoever builds it:* the identity string. The same `FM-1_725` keeps Lupe calling it "up to date"; a new one makes Lupe offer the release over it.
3. **Install with the tested path** (Lupe's firmware installer, as for 2.5.1), not by hand.
4. **Rollback:** reinstall `firmware/releases/Skiff-Lupe-2.5.1.fwsc` (SHA-256 `80b21b33…302c`) the same way.

| # | Do this | Pass |
|---|---|---|
| B1-1 | The FM-1 into the Mac: `swift tools/gapcount.swift live 20 Felucca`, a held note, then the pattern. | 0 zero gaps, 0 repeat gaps. Rate ≈ +422 ppm as before. |
| B1-2 | The same at 44.1 kHz (Audio MIDI Setup › Felucca › 44,100 Hz). | As before (the 44.1 path is unchanged). |
| B1-3 | Pixel 7 and Pixel 10, Lupe with `--ez throughConceal false`. Run `android/scripts/dejitter-intervals.sh 20 -s <pixel>` with the pattern playing. | Dejitter lines near 0 (they were 14 a second). Lupe phone gaps near 0. By ear: no crunch. |
| B1-4 | **FM6 pads**, the heaviest render load, for a minute on the Pixel. | No crunch. Repeat gaps 0: the FM-1's ring didn't run dry. If there are repeats, the centre/ring change above. |
| B1-5 | The iPad: Play through the iPad, plus the screen link, MIDI and a project load and save. | All as on 2.5.1. |
| B1-6 | Roll back to the 2.5.1 release if Scott doesn't keep it. | Lupe shows "Skiff-Lupe 2.5.1 · up to date". |

**Afterwards:** if it holds, offer it upstream to Skiff (illuminus5/skiff), as with the screen link. Its value isn't Lupe-specific: any host that takes a fixed 48 a millisecond benefits.

## What it doesn't cover

- A host that takes its frames on an audio clock of its own, not the USB frames. B1 can't match that, and check 19 (another USB source on a Pixel) couldn't be run. B1-3 answers it.
- The 44.1 kHz host rate, which keeps today's rule.
- Bluetooth. It's a separate path.
