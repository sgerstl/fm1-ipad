# The phone's sound pages (P4): page by page

*Note, 2026-11-14 night: P1 read the real FM-1 over the Pixel and it runs **Skiff 2.5.1** (INFO "FELUCCA v2.5.1"), not 2.2. So the 2.5 rows below are the primary ones (FX has eight pages; CHORD has STRUM and DIR; GLO's DELAY has MODE), and the 2.2 tables are the fallback the page builder already handles.*

*Drafted overnight 2026-11-13 → 14 by Claude for Scott to correct. Source of truth for the pages: Skiff's `PAGES[]` (firmware `params.c`, the Skiff-Lupe 2.2 tree in `~/code/skiff-src`) and SloopKit's `SkiffPages` (SkiffDriver.swift), which already builds them per firmware release. Boards 59–63 in `design/boards/phone-portrait-2.html`. Decisions this rests on: the bottom half always follows the FM-1 (D3), four controls first (D8), one page at a time.*

## What stays the same on every page

Board 55 is the template. From the top of the bottom half:

1. **Family row:** ENV · LFO · FX · SEL · EDIT · ARP, six keys, 63 × 36. The lit key is in the track's colour. Tapping one sends the FM-1 there (SCREEN_GOTO) and the bottom half follows, as the iPad's navigation does. GLO isn't here: it changes the top half to Mix (structure map). SEQ isn't here: HOME and SEQ bring the editor back.
2. **Page row:** that family's pages in the FM-1's order. Tap one to send the FM-1 there; pressing the family button again on the FM-1 steps along it. **FX and EDIT have more pages than fit 396 dp**, so the row scrolls sideways and keeps the current page in view, with a fade at the cut edge. The other families fit. (Open question 1.)
3. **Track line**, at the graph's top left: the track's colour dot, number and name ("5 Piano"), as the iPad's sound panel does. It moved off the page row to give the row the full width.
4. **The graph**, where the page has one (table below). 140 tall at split; at bottom full it grows to 220 and the controls keep their size.
5. **Four controls in the FM-1's knob order**, 96 wide each. Label, ring, value. **An empty knob slot (the FM-1's 0xFF) stays an empty well**, so knob 3 on the phone is always knob 3 on the FM-1.
6. **The FM-1's knob turning:** its control lights white and the value grows to 30 (board 55). It fades back 600 ms after the last turn.

**Values:** numbers as the FM-1 shows them (DeviceDisplay already formats Hz, dB, ms, note names, sync divisions). Lists show the name (SAW, ROOM, 1/16T). A long name shrinks from 24 down to 18, then truncates with the whole name in the TalkBack label.

**Changing a value on the phone (proposed, open question 2):** drag up or down on a control, about 2 dp a step for a 0–127 range, with a haptic tick on every step of a list and at the ends. Tap a control and − / + appear under its value (as the step panel's), for one step at a time. Double tap puts it back to the value it had when the page opened (not a factory default: the FM-1 has none per sound).

**Locks on a sound page:** when a step is held (on the phone's editor at bottom full, or on the FM-1, which the screen link reports), the page row turns into the lock banner, "Locking to step 6" (as board 56's ruler does), and every control already locked on that step shows ◆ beside its label. **SC_GLOBAL pages (SAMPLES, GLO's) can't be locked or automated**: while a step is held they show "Not lockable" in the banner instead.

## The pages (Skiff 2.2)

Index is the FM-1's page number (the screen link's). Knobs in order; — is an empty slot.

### ENV (2 pages)

| # | Page | Knobs | Graph |
|---|---|---|---|
| 0 | ENV | ATTACK · DECAY · SUSTAIN · RELEASE | ADSR (board 55), drag a handle to set its values, as on the iPad |
| 1 | ENV 2 | ATTACK · DECAY · SUSTAIN · RELEASE | ADSR, MOD's second envelope |

**Correction to board 55:** its page row shows ENV · ENV 2 · ENV DEST. Skiff 2.0 folded ENV DEST and LFO DEST into MOD's first seven routes; there is no ENV DEST page. Board 55 is fixed to ENV · ENV 2.

### LFO (3 pages)

| # | Page | Knobs | Graph |
|---|---|---|---|
| 2 | LFO | RATE · WAVE · PHASE · FADE | the live LFO, moving (the iPad's LiveLFOGraph) |
| 3 | LFO 2 | SYNC · TRIG · POLARITY · ENV SYNC | the same LFO graph |
| 4 | MOD | (route) · SRC · DEST · AMT | **the route list**, board 60 |

**MOD on the phone:** knob 1 on the FM-1 picks one of eleven routes: seven fixed (LFO → PITCH, CUTOFF, SHAPE, AMP; ENV → PITCH, CUTOFF, SHAPE), where only AMOUNT turns, then four matrix slots with SOURCE, DEST and AMOUNT. The phone draws the eleven as a list in the graph's place, each row its route and amount as a small bar. The route knob 1 has picked is lit; tapping a row picks it (sends knob 1). Knob 1's control is the empty well with "ROUTE" under it and the route's name as the value. On a fixed route, SRC and DEST show their fixed values greyed (text2), not editable.

### FX (6 pages; 8 on Skiff 2.5)

| # | Page | Knobs | Graph |
|---|---|---|---|
| 5 | FX | DIST · CHORUS · DELAY · REVERB | the four sends as bars (FXDrawing), 96 tall |
| — | DELAY (2.5) | SEND · TIME · FEEDBACK · COLOR | the delay taps |
| — | REVERB (2.5) | SEND · TYPE · SIZE · DAMP | the reverb tail |
| 6 | DRIVE | DIST · TYPE · TONE · — | the drive curve |
| 7 | INSERT | TYPE · A · B · C | the insert's own picture; A B C renamed by TYPE |
| 8 | INSERT 2 | MIX · — · — · — | the same insert picture |
| 9 | SLICER | SLICER · PATTERN · RATE · DEPTH | the slicer's gates, 96 tall |
| 10 | DUCK | BY · DEPTH · RELEASE · — | the duck over a bar at the tempo, 96 tall |

**On Skiff 2.5.1 (the FM-1 Scott has) INSERT 2 isn't one of the FM-1's pages:** 2.5 moved its MIX onto INSERT's PRESETS card and the FM-1 counts "FX n/7" (SkiffFirmware.swift). Lupe numbers pages as 2.2 does, with FX › DELAY 46 and FX › REVERB 47, and the driver translates at the wire. So on 2.5.1 open question 3 mostly answers itself: following never lands on INSERT 2.

The iPad merges INSERT and INSERT 2 into one card. **The phone keeps them as the FM-1's two pages**, because the bottom half follows the FM-1 page for page; merging would make "where am I" ambiguous when the FM-1 says INSERT 2. (Open question 3.)

**INSERT's A, B, C** change meaning with TYPE. Their labels come from the firmware's DESC for the current type, as on the iPad. A type change cross-fades the three labels (nothing pops).

### SEL (3 pages)

| # | Page | Knobs | Graph |
|---|---|---|---|
| 11 | SCALE | ROOT · SCALE · QUANTIZE · TRANSP | a keyboard octave with the scale's notes lit from ROOT |
| 12 | CHORD | CHORD · VOICING · — · — (2.5: STRUM · DIR) | the chord on the track's ROOT from C4 |
| 13 | FOLLOW | FOLLOW · MODE · NOTE · — | the track it follows and how (the live chord stays on the FM-1's screen) |

Holding SCL on the FM-1 opens SCALE as the keys' map (SkiffButtonMap's keys layer). The phone shows SCALE with "Keys: SCALE" in the banner place while held.

### EDIT (engine-dependent, 4 to 6 pages)

| # | Page | Shows on | Knobs | Graph |
|---|---|---|---|---|
| 14 | EDIT 1 | every engine | the engine's first four (names from the firmware: ANALOG's WAVE DETUNE MIX NOISE) | the engine's picture where Lupe has one (ANALOG's OSC and FILTER, else the scope) |
| 15 | EDIT 2 | every engine | the engine's next four (ANALOG's CUTOFF RESO …) | shares EDIT 1's |
| 16 | OPERATOR | FM6 | (code-driven) | — |
| 17 | ALL OPS | FM6 | (code-driven) | — |
| 18 | LANES | DRUM | (lane) · LEVEL · TUNE · DECAY | **lane tiles**, board 62 |
| 19 | SOUND | DRUM-X | (lane) and the sound's sheet | lane tiles |
| 20 | LANE MIX | DRUM, DRUM-X | (lane) · LEVEL · PAN · — | lane tiles |
| 21 | SLICES | SLICE | the engine's first two (code-driven) · — · — | — |
| 22 | SAMPLES | SAMPLE on a user set | (sample) · LEVEL · REVERB · DELAY | sample tiles; SC_GLOBAL |
| 28 | VOICE | every engine | VOICE · GLIDE · GL MODE · PRIORITY | voices and glide |
| 29 | VOICE 2 | every engine | ALLOC · DETUNE · SPREAD · — | — |

Pages 23–27 (OP1–4 ENV, OP LEVEL) belong to the DIGITAL engine, which Skiff 2.2 doesn't build: never shown.

**The page row shows only the pages the selected track's engine has** (Skiff's `page_visible`), so an ANALOG track's EDIT row is EDIT 1 · EDIT 2 · VOICE · VOICE 2 and fits; a DRUM track's is EDIT 1 · EDIT 2 · LANES · LANE MIX · VOICE · VOICE 2 and scrolls.

**Picker pages** (LANES, LANE MIX, SOUND, SAMPLES, MOD): knob 1 picks *which thing* the other three edit. On the phone knob 1 becomes **tiles** in the graph's place (the iPad's PickTiles): eight lanes BD SD CH OH … as 4 × 2 tiles, or the user samples. Tapping a tile sends knob 1. The lit tile follows the FM-1's knob 1.

**The dense pages, four controls first (D8):** OPERATOR and ALL OPS (FM6), SLICES, and DRUM-X's SOUND have their knobs driven by code on the FM-1, not by PAGES, so the firmware's DESC gives no four controls to draw. The screen link reports only the page and its cursor (SCREEN, `EDITOR_PROTOCOL.md` "Screen link"), not the FM-1's pixels, so there's no picture to mirror either. **v1 on the phone: a card in the graph's place that names the page and where the FM-1's cursor is ("OPERATOR · OP 2 · RATIO"), says it's edited on the FM-1, and keeps the page row and family row working.** The iPad's pictures for these (the FM6 patch editor, the lane faders, DRUM-X's sheet, the slices) port after v1. (Open question 4.)

### ARP (2 pages)

| # | Page | Knobs | Graph |
|---|---|---|---|
| 39 | ARP | MODE · RATE · OCTAVE · GATE | the arp pattern over a bar (ArpDrawing) |
| 40 | ARP 2 | SWING · CHANCE · HOLD · ORDER | the same drawing |

Holding ARP on the FM-1 is PERFORM (the scenes on the keys): the top half goes to Pads, as the structure map says. The bottom half doesn't change.

## Not in the bottom half

- **GLO (30–34):** MIXER, DELAY, REVERB, CHORUS, GLOBAL open in the **top half's Mix tab** on that page (boards 64–65).
- **SAVE (35–38):** PRESETS and USER open the **Sounds browser** in the bottom half (board 66); PATTERNS opens the Patterns drawer over Pads; PROJECT the Projects sheet (board 67).
- **SEQ (41–45):** NOTES and FEEL are the editor with the step panel on that tab; PATTERN is the step panel's PATTERN tab (LENGTH DIV SWING GATE, DIR); AUTOMATION moves the divider to bottom full with the lane (board 54, 69); SONG changes the top half to the Timeline.

## Open questions for Scott (each with a recommendation)

1. **FX and EDIT's page rows don't fit.** Recommended: the row scrolls and keeps the current page in view. Alternative: a "FX ⌄ 3 of 6" key that opens the list. The scroll keeps every page one tap away and looks like the FM-1's own row.
2. **Changing a value on the phone.** Recommended: vertical drag, tap for − / +, double tap to revert to the page-open value. Alternative: horizontal sliders instead of rings, which read better on a phone but no longer look like the FM-1's knobs.
3. **INSERT and INSERT 2.** Recommended: two pages, as the FM-1. Alternative: the iPad's merged card (five controls on one page), which breaks the four-controls rule and the one-to-one following.
4. **The dense pages in v1** (OPERATOR, ALL OPS, SLICES, DRUM-X SOUND). Recommended: a named card with the FM-1's cursor, edited on the FM-1. Alternative: port the iPad's pictures in P4, which roughly doubles P4. (I first thought of mirroring the FM-1's screen; the screen link doesn't carry pixels.)
5. **Sound pages at top only.** Recommended: when the FM-1 opens a sound page and the divider is at top only, the divider moves to split (as AUTOMATION moves it to bottom full), so following the FM-1 never hides what it opened. It goes back when the FM-1 goes HOME.

## Decisions since the first draft (2026-11-14)

- **Questions 1 and 5 (page row scrolls; divider glides to split and back):** kept as built.
- **Decision 12, the dense EDIT pages:** OPERATOR, ALL OPS and DRUM-X's SOUND have pictures now (ported from the iPad: operator tiles and envelopes, the algorithm chart, the kit's windows; read-only on the phone). "Four controls first" no longer applies to them.
- **Decision 17:** INSERT 2 is out of the FX row on Skiff 2.5.1 (the FM-1's own seven pages); it stays only on 2.2.
- **Decision 18, SLICES:** keeps the named card for now (board 70). The iPad has no picture either, because the editor protocol can't read or move slice markers. A SLICES picture goes on the later list for both apps and needs new Skiff commands.
