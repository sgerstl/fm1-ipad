# CPU, idle and playing, 2026-11-05

iOS logged two cpu_resource reports on Scott's iPad (19:42 and 20:05): 90 s of CPU over 178 s, a sustained 50%. That was on earlier builds. The iPad wasn't reachable from here, so these numbers are from the **simulator** (Look iPad, `-demo -demo-skiff -demo-link`). Each is the process's CPU time over 20 s, taken 8 s after launch, as a share of one core. The demo's fake Skiff runs inside the process and is included. **Device numbers from Instruments are still needed.**

A first round measured the wrong process: another session's iPhone simulator running the app. The script now picks this simulator's process by its device id.

| | before | after |
|---|---|---|
| Song, stopped | 18.0% | **2.3%** |
| Shape, stopped | 17.2% | **2.0%** |
| Mixer, stopped | 8.4% | 3.2% |
| Browse, stopped | 6.5% | 3.2% |
| Song, playing | 25.9% | **17.5%** |
| Shape, playing | 19.3% | **10.1%** |
| Mixer, playing | 13.2% | 8.2% |
| Browse, playing | — | 7.7% |

## What it was

1. **The song store's once-a-second poll assigned `song`, `pool` and `divisions` every time**, changed or not. With Observation, an assignment wakes every view that reads the property. So the Song tab's arrange page, its ruler and all six lanes rebuilt every second, stopped or not (`-count-bodies`: `Lane=6 Ruler=1 SkiffArrangePage=1` a second while stopped; nothing after). Each is now set only when it differs.
2. **The resync's parameter reads did the same to `tracks`, `globals`, `bpm` and `swing`** (`apply`, `applyGlobal`). `apply` now changes a copy and sets it back only when it differs.
3. **The top bar rebuilt on every step** (8 times a second at 120 BPM) for the position readout. The readout is now a view of its own.
4. **The Song playhead's TimelineView placed every lane's blocks on each frame** (`laneEnds`). That now happens once per body. The playhead, the pass bars, the editor's playhead and Shape's LFO graphs run at 30 frames a second instead of 60.
5. **On Skiff, the resync backstop read all 64 steps of the selected track every second**: 64 requests a second over USB MIDI, though Skiff pushes step changes (WATCH bit 0). Now it's every 4 seconds. The parameter and other-track reads keep their pace. SLOOP is unchanged.

The view counters (`BodyCounter.tick`) now cover the Song tab's views, the top bar and the piano roll (free unless `-count-bodies`).

## Not done or not checked

- **On the device:** Instruments (Time Profiler, SwiftUI) on Scott's iPad, idle and playing. The simulator renders on the CPU, so its playing numbers overstate the device's drawing cost; they don't capture the device's MIDI or USB work either.
- **Song while playing (17.5%)** is mostly SwiftUI rendering the moving parts: the six pass bars, the song playhead, the editor's playhead, the motion lanes. Next steps if the device numbers call for it: one Canvas for all the pass bars, or drawing the playhead into the lanes' Canvas.
- **MOTION polling** (the selected track every 2 s, every track every 6 s) is unchanged. It writes only on change.
- **Tests:** `WorkflowTests.aLoopSavedToASectionComesBack` failed once in the full run. It passed three runs on its own, so it looks like a timing flake under load in the SLOOP fake.
