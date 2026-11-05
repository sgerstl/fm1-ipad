# The LFO page: how close Jib gets

The page draws Skiff's own view (`lfo_view_at`): 2 s from the last restart, then the last 2 s scrolling, with a dot where
the LFO is now. The model is `SkiffLFO` / `LFOClock` in SloopKit (`SkiffLFO.swift`, tested in `SkiffLFOTests`).

| Setting | What Jib knows | How close |
|---|---|---|
| RATE (SYNC OFF) | The rate, exactly: `0.05 × 800^(v/127)` Hz, the firmware's own table | Exact rate. Over a 2 s window the iPad's and the FM-1's clocks drift by microseconds |
| RATE + TRIG NOTE | The restart: the track's first note after silence, from Skiff's NOTES OUT (track k on channel k + 1) | Phase exact to the MIDI latency (USB, a millisecond or two). Without notes out (NOTES OUT OFF, or a track moved to another channel) the restart isn't seen: the wave runs from when the page opened |
| RATE + TRIG FREE | Nothing: the phase runs on from whenever the LFO started | Right rate, unknown phase. The window starts when Shape first showed an LFO |
| SYNC + TRIG FREE | MIDI clock since Start: Skiff resets the phase at PLAY (`seq.c:1241`) | Follows the clock pulse by pulse, interpolated between pulses (a pulse is 20.8 ms at 120 BPM). Tempo changes and an external clock are followed, because it counts pulses, not BPM |
| SYNC + TRIG NOTE | The restart (as above) and the clock at that moment | Phase from PHASE at the restart, advancing with the clock |
| SYNC, stopped | The BPM (global 0) | Right rate at the set tempo; the phase isn't known |
| FADE | The time: `1 ms × 10000^(v/127)` | Exact, from the restart |
| S&H | Skiff's graph takes its own value per cycle (a hash of the cycle number), not the sound's | The same picture as the FM-1's screen draws. Neither shows the values you hear |

Not followed: the mod matrix moving RATE (`mod.c`), and SYNC's tweak that lines a cycle up with the track's own steps
when they divide evenly (`voice.c:58`), which matters only after very long runs.

Not verified: notes from a real FM-1. The demo (FakeSkiff) sends no notes or clock, so on the sim the window runs from
when the page opened.
