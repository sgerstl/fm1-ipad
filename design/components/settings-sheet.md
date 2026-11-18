---
component: Settings sheet
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/SettingsSheet.swift   # the sheet and every section but Labs
  - ios/FM1/Settings.swift        # SlideToTurn, Handedness, PadPreviews, ThemeColours, Magnifier, SoundButtons
  - ios/FM1/Labs.swift            # LabItem, Labs, DividerFeel, SlideLength, LabsSection
  - ios/FM1/TopBar.swift          # the FM-1 menu's Settings…
  - ios/FM1/PhoneAppView.swift    # the iPhone's ⋯ › Settings…, the same sheet
  - android/app/src/main/java/com/scottgerstl/lupe/ui/settings/SettingsSheet.kt   # Android (branch claude/android-p2-shell-02c86f)
  - android/app/src/main/java/com/scottgerstl/lupe/ui/slide/PhoneSettings.kt
boards: ["design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-295   # Settings row
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-274   # Toggle
---

# Settings sheet

> **Under revision (2026-11-14):** the phones. Decision 33 (vault `phone-skiff-decisions-2026-11-12.md`) gives both phones Android's grouped bottom sheet, carrying the union of both apps' options, naming handedness, Magnifier, slide-to-turn, Show graphics and Sound keys. Android adds the iPhone's options to its sheet; the iPhone swaps the iPad's form for Android's sheet (`phone-consolidation-build-plan-2026-11-14.md`, rows "Settings" and "Sound keys rail"). Decision 32 adds Settings › Sound keys, off by default. Section 1 below is the iPad's sheet, which the iPhone shows today.
> - `[open]` "The union of both option sets": the iPhone shows the iPad's whole sheet today, so does every iPad option (Touch, theme colours, pad pictures, Keep sends, Play through, the iPad's Labs) go to the phones, or only the five the decision names?
> - `[open]` The name: decision 32 says "Sound keys"; the iPad and iPhone say "Sound buttons". One word on all three?
> - `[open]` Android's Labs row for how long the sound panel stays tunes the timeout decision 32 removes. Does it go?
> - `[open]` Haptics is Android's only. Does it come to the iPhone?

## 1. Requirements

### Purpose and scope

What a player sets once to suit their hands and setup, and Labs, the feel values still on trial. Every change is kept the moment it's made. It isn't for anything the FM-1 holds, with one exception the FM-1 offers (Keep sends).

Way in: the FM-1 menu › Settings… (iPad), ⋯ › Settings… (iPhone).

### Anatomy

Names as in the code.

- **sheet**: a system form, "Settings", with **Done**.
- **section**: a group with a header and a footer that explains it, often changing with the choice.
- **setting row**: a picker, a segmented control, a toggle or a slider with its value.
- **audio action line**: under Play through the iPad, only when there's something to do.
- **Labs row**: a title, its value, a slider, a line saying what changes and its default, and **Reset** when changed.
- **Put every Labs value back**: under Labs, when anything in it has changed.

### Requirements

**Functional**
- **F1** Every setting is stored at once and read wherever it applies; nothing waits for Done.
- **F2** Sections in this order, and what each controls:
  1. **Slide to turn**: Sideways (default), Up and down, or Both. How a column turns on a slide in Shape, the sound panel, the Mix cards and HOME's four (`SlideToTurn`).
  2. **Handedness**: Right-handed (default) or Left-handed. Which side of the finger menus open on, and which side the sound buttons sit (`Handedness`).
  3. **Touch**: "Hold before a menu", a slider (Labs key `holdToMenu`); "Slide for a full turn", Fine, Normal or Quick (Labs key `columnTravel`, through `SlideLength`); "Confirm before clearing a pad", on (`PadsPage.confirmClearKey`).
  4. **Sound buttons**: off by default. On, the FX to SEQ rail stays down the side and the sound panel leaves its keys out; off, an open panel carries the FM-1's twelve along its foot (`SoundButtons`).
  5. **Track colours from the FM-1's theme**: on. The six track colours follow the FM-1's THEME; Lupe's surfaces and greys don't (`ThemeColours`).
  6. **Show every pattern on the pads**: on. While stopped, Lupe reads the pattern pool so each pad shows its picture before it's played (`PadPreviews`).
  7. **FM-1 · Control**: "Keep sends when loading a sound", only when the FM-1 offers it. KEEP SENDS on the FM-1.
  8. **Magnifier**: on. A bigger copy of a value above the finger while it slides (`Magnifier`).
  9. **Play through the iPad**: the FM-1's sound on the iPad's speaker or headphones (`AudioThrough`).
  10. **Labs · Motion**: Editor divider (Snappy, Balanced, Bouncy: `DividerFeel`), then the Labs keys `menuOpen`, `songSlide`, `padPlayFade`.
  11. **Labs · Touch**: the Labs keys `holdToPaint`, `padSlideStart`, `padSlideDwell`.

**States**
- **S1** Slide to turn's footer: Sideways says a vertical drag scrolls the panel; Up and down or Both says panels scroll from the gaps between columns.
- **S2** Handedness's footer names the side menus open on and where the sound buttons sit.
- **S3** FM-1 · Control shows only when the FM-1 reports KEEP SENDS (Skiff 2.5's editor menu).
- **S4** The audio action line shows only when the user has something to do: microphone access off, no sound from the FM-1 over USB, a failure, a USB audio problem, or (Skiff) "Turn the FM-1's MASTER down to quiet its speaker". Otherwise nothing.
- **S5** A Labs row's value is brighter when it differs from its default; Reset shows only then.
- **S6** "Put every Labs value back" shows only when a Labs value has changed or a divider feel has been picked.

**Behaviour**
- **B1** Hold before a menu moves in Labs' step for `holdToMenu` and shows its value in seconds.
- **B2** Slide for a full turn shows the length nearest the stored one; a length set on the old slider stays as set until one is picked.
- **B3** Confirm before clearing a pad is the same switch as the pad confirm's "Don't ask again".
- **B4** Keep sends writes the FM-1's MENU › CONTROL setting.
- **B5** A Labs change applies the next time the thing happens; Reset puts one value back, the footer button all of them and the divider feel.
- **B6** Done closes the sheet.

**Content**
- **C1** Labs' footer: "Try-outs: each becomes the default or goes. Changes apply the next time the thing happens."
- **C2** Each Labs row's line ends "Default <value>.", from the Labs item.
- **C3** Touch's footer explains the clear confirm: a pattern nothing else uses is erased with the pad, and can't be undone.
- **C4** Show every pattern's footer still says "A trial until 16 November". `[open]` `Settings.swift` says it stays after its review on 2026-11-16; the copy needs to change then.
- **C5** Track colours' footer names the themes that have track colours (SKIFF, CRYPT, NEON, QUARK, custom) and those that don't (HI-CON, PAPER).

**Accessibility**
- **A1** Native controls throughout; sliders carry their title as the label and the value in words.
- **A2** Slide to turn's picker hides its label; the section header names it. `[review]` What VoiceOver reads on it.
- **A3** The audio action line's label is its text; the icon adds nothing VoiceOver needs.
- **A4** A changed Labs value is brighter and also has Reset beside it, so the change isn't shown by colour alone.
- **A5** `[review]` Larger Text: the form scales (accessibility check 15's expectation), but the explanation lines and Labs' lines are Lupe's fixed type.
- **A6** The audit (accessibility 2026-11-10) checked Settings on the iPad; it didn't reach Labs, or Settings on the phone.

**Integration**
- **I1** Stored in UserDefaults under each setting's key (`SlideToTurn.key`, `Handedness.key`, `PadPreviews.key`, `ThemeColours.key`, `Magnifier.key`, `SoundButtons.key`, `DividerFeel.key`, each Labs item's key). Sound buttons has a new key so the old default (on) doesn't carry over.
- **I2** Keep sends is the FM-1's (Skiff 2.5, editor menu id 21), read with the session; the sheet only shows and sets it.
- **I3** Track colours follow the FM-1's THEME within a few seconds of a change on its MENU; a colour too dark for Lupe's page keeps Lupe's own.
- **I4** Play through: Lupe can't turn Skiff's MASTER, so the speaker is the user's to quiet.
- **I5** Labs items carry an added date and a review date two weeks on; by the review each becomes the default or goes (Labs.swift, Scott, 2026-11-09).

**Device checks.** Handedness: `2026-11-09-lupe-batch-2026-11-06.md` 10. Labs: the same file 17. Sound buttons: the same file 18; on the phone, `2026-11-10-phone-pads-edit-mix.md` 12. Touch and Labs after install: `2026-11-09-perform-grid-map.md` 67, passed with checks 50–71 (batch list item 8, Scott, 2026-11-11). Theme colours: the same file 30. Keep sends: `2026-11-11-skiff-2.5.1-support.md` 6. Results not recorded unless said.

### Ruled out

- The "Follow the FM-1's screen" switch: it always follows (Scott, 2026-11-06, `TopBar.swift`).
- Lines that only report (what's playing, the audio route): the top bar already says it (Scott, 2026-11-06, `SettingsSheet.swift`).
- Labs as a second settings menu: each item becomes the default or goes (Scott, 2026-11-09).
- Hold before a menu and Slide for a full turn as Labs trials: in Settings › Touch for good, same keys (Scott, 2026-11-10).
- The divider's two springs as two sliders: one feel, three choices; menus' open and close as two values: one speed (2026-11-10).
- The track-controls gap, the grid's pan start and the flick speed as Labs values: cut and fixed (2026-11-10).
- The sound buttons' rail on by default: off, so the page gets the whole width (Scott, 2026-11-08).

### Out of scope

- The FM-1 menu that opens it: see `connection-states.md`.
- What each setting changes, in those components: the pad's clear confirm (`pattern-pad.md` B20), the hold menus' side (`hold-menus.md`), the value loupe, the sound panel's keys (`sound-panel.md`).

## 2. Design

No iPad board; it's a system form. Phone row "Settings": `design/boards/phone-consolidation.html` (Android's sheet, board 67 in `design/boards/phone-portrait-2.html`).

### Decision log

- 2026-11-06: what's set once and left moves out of the FM-1 menu into Settings (Scott).
- 2026-11-08: Handedness, right by default (Scott).
- 2026-11-09: Labs, values set from Settings rather than asked for a round at a time (Scott).
- 2026-11-10: Touch, out of Labs for good (Scott).
- 2026-11-14: both phones get Android's grouped sheet with the union of options (Scott, decision 33).

## 3. Build notes

- `.android` hybrid look (branch `hybrid-ui-android`, 2026-11-17; spec 3.6, 3.8): every sheet (`LupeSheet`) sits below the header (top 60) at a 24 top radius, rises on the spring (Labs › Hybrid · sheets and panels), with a 36 × 4 `primaryEdge` handle and a 40 round close key; 24 each side. The switch is 52 × 32: on, a `text` track with a 24 dark thumb; off, `control` with a 2 dp `primaryEdge` edge and a 16 thumb (the thumb's size is the second channel). Segments are the connected group. **Not built:** the two-column landscape layout and the list-and-detail rail (spec 3.8); the sheet's upward shadow (depth comes from the surface step).

- The sheet is shared with the iPhone, where its toggle still reads "Play through the iPad" (the iPhone's menu says "Play through the iPhone").
- `LabsSection` redraws on a counter because UserDefaults isn't observed.
- Android today (branch `claude/android-p2-shell-02c86f`): sections FM-1 (status, theme), Turning values (Slide to turn, Magnifier, Haptics, Show graphics) and Labs (switches marked TRIAL, and feel sliders). No handedness and no Sound keys yet.

### Decision log

- 2026-11-10: Labs keys merged without losing what was set (`Labs.migrate`).
- 2026-11-18: **Offer played phrases**: Chip (default), Pop-up, Off, under Touch after Haptics (Scott: the FREE TAKE strip kept blocking the page).
- 2026-11-18: **Settings cleaned up** (Scott). Audio keeps Play through the phone, Needs a hand and the Bluetooth note (only while the output is Bluetooth: it explains the lag); Output, Delay and Details are gone. "Slide to turn" is "Slider gesture" (label and TalkBack name; the subtitle stays). Menus open is gone: hold menus and pop-outs open to the right of the finger and flip left only when there's no room (the standing rule that menus open beside the touch point); its pref is cleared. Sound keys moved into Touch, directly above Sound keys side, which is dimmed, takes no touch and tells TalkBack "Turn on Sound keys first" while the keys are off. **Labs is gone**: Pause following after a touch is built in on and Pin the sound page off, as Scott had them (read from his phone); Piano under the grid and Timeline: time across were never built and are in `design/backlog.md`; their prefs are cleared on start. Sound pages keeps Show graphics. The Magnifier is untouched (a redesign is being mocked). Device check 165.
- 2026-11-18: **Following is back, the column narrows, the magnifier is rebuilt** (Scott). Pause following after a touch (on) and Pin the sound page (off) are ordinary switches again in a **Following** section after Sound pages, with their old subtitles, no TRIAL mark and no Labs heading; they keep Scott's values under new keys (`pause_following`, `pin_bottom`). Piano and Timeline across stay in the backlog. **The content column is capped at 560 dp and centred; the sheet's surface stays full width** (my call: the sheet keeps its edge-to-edge rise and handle, and only the rows narrow). Segmented options size to their label plus 16 dp each side (at least 72 × 44), left-aligned under the label; when the group can't fit the column (200 % font on the portrait phone) it falls back to full width and labels wrap to two lines instead of truncating (`segmentedFits`, unit-tested; Robolectric layout tests at the Pixel's width both ways and at large font). Switch rows keep the switch at the column's right edge. **Magnifier** (Figma 141:9654): the held control lifted at 1.6× on `held`, corner 16, a 2 dp inside edge in the track colour, no shadow; a label row with the knob badge, the value at 42, and a 6 dp track (bipolar from the centre) or a 64 dp flat arc dial. It grows from the finger on a spring (damping 0.75, stiffness 700: about 3 % overshoot) and leaves on a 120 ms ease-in; Remove animations fades only. **Contrast:** `text2` on `held` measures 4.13:1, under 4.5, so the label uses `text` (9.07:1). The label is Barlow Regular, since Medium isn't shipped. The Magnifier switch behaves as before. Device check 166.

## 4. Usage

- A new feel value goes into Labs first, with its dates (repo rule 3), and leaves it as a default or a setting by its review.
- A new setting gets a footer that says what changes, in the user's terms.
- Something the FM-1 holds appears here only when the FM-1 offers it, as Keep sends does.
