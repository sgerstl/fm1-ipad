# Android: which sound page has a proper picture (survey, 2026-11-14)

Read from the code at 19b74c9 (the core's `PagePictures.swift` and the phone's `ui/page/PageGraphs.kt`, against the iPad's `ios/FM1/PageGraphs.swift`). No fixes here. "Code" means the phone has no drawing for it; "data" means the page area doesn't carry what the drawing needs. Not checked on a device.

| Family | Page | Picture now | Proper? | Missing |
|---|---|---|---|---|
| ENV | ENV | the ADSR shape, the turned segment white | Yes | – |
| ENV | ENV 2 | the same shape from its own four values | Yes | – |
| LFO | LFO | the wave over two seconds with a moving dot | Partly | Code: the iPad draws the live LFO (restarts with the clock, BPM-synced rates, FADE ramping in); the phone draws a fixed sweep and ignores FADE. Data: the clock reference exists (`clock` area) but the LFO's restart point doesn't |
| LFO | LFO 2 | the same wave as LFO (from LFO's values) | Partly | Code: SYNC, TRIG, POLARITY and ENV SYNC don't change the drawing (they do on the iPad's live graph) |
| LFO | MOD | the eleven routes as tiles, the picked one lit | Yes (tiles, by design) | – |
| SEL | SCALE | the twelve keys, in-scale lit, the root marked | Yes | – |
| SEL | CHORD | none | No | Code and data: the iPad draws the chord a key plays on the keys (or strummed in time). Needs CHORD's mode and voicing with SCALE's root and scale, VOICE's mode and ARP's mode; the page area sends no graph for it |
| SEL | FOLLOW | none | No | Code and data: the iPad writes which track it follows and how, in that track's colour. Needs the followed track and whether it plays a kit |
| EDIT | EDIT 1, ANALOG | the oscillator wave and the filter curve | Yes | – |
| EDIT | EDIT 2, ANALOG | the same picture (shared, as on the iPad) | Yes | – |
| EDIT | EDIT 1 and 2, DIGITAL, PHASE, LOFI, VOICE, TRIO, GRAIN, PHYS, DRUM, SLICE, DRUM-X | none | No | Code and data: the iPad draws a live scope of the sound. Needs the FM-1's scope samples, which the page area doesn't carry |
| EDIT | EDIT 1 and 2, WHEEL, SAMPLE, FM6 | none | Yes (the iPad draws none either) | – |
| EDIT | VOICE | none | No | Code only: the iPad draws the voice mode and the glide ramp from the page's own four values, which the page already has |
| EDIT | VOICE 2 | none | Yes (the iPad draws none) | – |
| EDIT | OPERATOR (FM6) | the six operators' envelopes, with OP1–6 as tiles | Yes | – |
| EDIT | ALL OPS (FM6) | the algorithm chart and the voice's other settings | Partly | Code: at the 110 dp picture height the chart's two rows of operator boxes overlap |
| EDIT | SOUND (DRUM-X) | the picked sound's rows of values, the lanes as tiles | Yes | – (on a kit's one-row Edit panel the tiles take the picture's place) |
| EDIT | LANES, LANE MIX (DRUM) | lane tiles only | Yes (tiles, by design) | – |
| EDIT | SAMPLES (SAMPLE) | none | No | Code and data: nothing is drawn or sent for it (the iPad has its own sample list there, not a picture) |
| EDIT | SLICES (SLICE) | none | No | Data: the slice markers can't be read over the editor link (the iPad shows a card saying so; the phone shows nothing) |
| ARP | ARP | the pattern over sixteen steps on C E G | Yes | – |
| ARP | ARP 2 | the same picture, with SWING and CHANCE applied | Yes | – |

For reference, the FX family (done in e546ff3 and P1's 19b74c9): FX, DELAY, REVERB, DRIVE, INSERT, SLICER and DUCK all have their pictures; DRIVE's output wave beside its curve is the one part still not drawn (code).

## Update, the same day: the four code-only gaps

Fixed on the phone (rows 69–74 of `2026-11-14-android-landscape.md`): VOICE has its picture; ALL OPS' chart shrinks to fit its height; DRIVE draws its output wave; LFO and LFO 2 run live on the clock area with SYNC, FADE and POLARITY. Still open for the LFO (data, P1): the page area sends LFO's four values only, so SYNC, TRIG and POLARITY come from LFO 2's own knobs once that page has been shown; and the LFO's restart (a fresh phrase on the track) isn't sent, so TRIG can't change the drawing. CHORD and FOLLOW are drawn from P1's 10793da (rows 75–78).
