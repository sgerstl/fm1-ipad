# Testing Lupe

Lupe is an iPad and iPhone app that works alongside an M-VAVE FM-1 running SLOOP. The FM-1 still makes the sound and stores everything. The iPad shows all four tracks at once, edits them, and arranges sections into songs; an iPhone does the same jobs one screen at a time. It talks to the FM-1 over USB MIDI using SLOOP's editor protocol.

This guide gets it running on your FM-1 and your iPad or iPhone. Allow about 30 minutes.

## What you need

- An FM-1 and a USB-C cable to the iPad or iPhone (or to the Mac, see step 3)
- A Mac with Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An iPad on iPadOS 18 or later. The layout is drawn for a 13-inch iPad in landscape and scaled to fit smaller ones
- Or an iPhone on iOS 18 or later, used in landscape. An iPhone 15 or later plugs straight into the FM-1 over USB-C; an older one needs Apple's Lightning to USB camera adapter
- Chrome, for SLOOP's installer and backup (Web MIDI)
- A free Apple developer account is enough to sign the app

## 1. Back up the FM-1

The app writes to the FM-1's flash: sections, the song order, user presets and samples. Back up first.

- **Already on SLOOP:** open SLOOP's web editor, Connect, then Song & sections, then Save a backup.
- **Still on M-VAVE's firmware:** your patterns aren't in SLOOP's format anyway. Note anything you want to keep before installing.

## 2. Install SLOOP 2.8.4 with the screen link

The app needs SLOOP 2.8.4 exactly (protocol 12). It refuses other versions on connect.

`sloop/sloop-2.8.4-screen-link.fwsc` is stock SLOOP 2.8.4 plus a 47-line patch (`sloop/0001-screen-link.patch`) that lets the app and the FM-1 follow each other's screen. With stock 2.8.4 the app still works, but the tabs no longer follow the FM-1's buttons. `sloop/README.md` covers what the patch adds to the protocol and how to rebuild the package from source.

SLOOP's installer is a web page that pins the package it installs, so you generate it locally around this file:

```sh
git clone --branch v2.8.4 https://github.com/isod89/sloop-fm1.git sloop-src
cd sloop-src
python3 web/make_site.py ../fm1-ipad/sloop/sloop-2.8.4-screen-link.fwsc 2.8.4-screen-link OUT
cd OUT && python3 -m http.server 8766 --bind 127.0.0.1
```

Then in Chrome open `http://localhost:8766/webapp/installer/` and follow it. SLOOP keeps projects, presets, samples and settings across installs.

If anything goes wrong, hold **OCT−** while powering on for USB rescue mode.

### Or install it from Lupe (new, not yet tried on a real FM-1)

Lupe now carries the two firmwares it speaks, each with Lupe's screen link (Skiff 2.2 and SLOOP 2.8.4), plus M-VAVE's stock V15, and can install any of them over the same USB cable. `FIRMWARE.md` lists the exact files and their SHA-256. **Until Scott has run it on his FM-1, use the Chrome installer above.** This is how it works once it's cleared:

- **On connect.** If the FM-1 runs something Lupe doesn't speak (M-VAVE's firmware, another SLOOP or Skiff version), Lupe says so and offers the install. If an earlier install was cut off and the FM-1 waits in update mode (USB name "Felucca Update", UPDATE MODE on its screen), Lupe offers to finish it. If a restore of stock V15 was cut off (M-VAVE's update mode, `ota-FM-1_015`), Lupe offers to finish that, with V15 only. Any other update mode is left to its own updater.
- **On purpose.** Debug builds: tap the connection dot (the ⋯ menu on an iPhone), then Developer › Install firmware…, and pick Skiff or SLOOP, or **Restore stock V15** under Back to stock. V15 goes on only if the FM-1 shipped with V15: a unit that ever ran V16 is refused before anything is written. Lupe can't talk to stock firmware, so after a restore it offers Skiff or SLOOP the next time you plug in. A new FM-1 on stock V16 gets Skiff 2.2 only: SLOOP 2.8.4 can't install on the newer flash chip such units most likely have (fixed in SLOOP 2.8.5, not carried yet), and V15 can't go on a V16 unit. There's no "install through stock": switching directly is what the sources support (`FIRMWARE.md`, "Going through stock V15").
- **Before writing.** When the FM-1 is connected, Lupe backs up every object the running firmware lists (projects, the music now, settings, presets, samples) to Files › On My iPad › Lupe › Backups, in the firmware's own backup format, so its web editor can restore it. An install writes only the firmware and keeps the store, but SLOOP doesn't read Skiff's projects, so the backup is how you get them back.
- **While it writes**, about a minute: keep Lupe open and the FM-1 plugged straight in. The screen stays on and a full-screen view shows the progress. Lupe won't start below 30% battery unless the iPad or iPhone is charging, because it powers the FM-1.
- **If it's cut off.** Nothing is lost: the FM-1 waits in update mode at every power-on until a write finishes. Plug it straight in (no hub) and tap Run the install again; it finishes the write. Skiff's README, "If the FM-1 does not start", covers the computer-side ways back.

To see the screens without an FM-1: launch with `-demo -demo-firmware picker` (or `loader`, `stock`, `foreign`, `installing`, `done`, `failed`, and for stock V15 `picker-stock`, `stock-loader`, `restoring`, `restored`, `v16`, and a new unit on V16 `v16-new`, `v16-picker`). That uses a pretend FM-1 and never touches MIDI. Screenshots: `qa/firmware-install-2026-11-05/`.

## 3. Build and run the app

Signing is set to my team, so change two lines in `ios/project.yml` first:

- `DEVELOPMENT_TEAM: K3CNX79952` → your team ID (Xcode › Settings › Accounts)
- `PRODUCT_BUNDLE_IDENTIFIER: com.scottgerstl.fm1ipad` → anything of yours, such as `com.yourname.jib`

Then:

```sh
cd ios
xcodegen generate
open FM1.xcodeproj
```

Pick your iPad or iPhone as the destination and run. On the first launch, allow the microphone. iOS counts the FM-1's USB audio as a microphone, and the sampler records from the device's own mic.

You can also run it on the Mac: pick **My Mac (Designed for iPad)** and plug the FM-1 into the Mac.

**Without the FM-1:** add `-demo` as a launch argument (Product › Scheme › Edit Scheme › Arguments), or pick "Demo FM-1" from the connection menu at the top left (on an iPhone, the ⋯ menu at the top right). The demo edits a step every 6 seconds so there's something moving. Add `-demo-skiff` as well for a pretend Skiff 2.2, with six tracks and a song in Arrange.

**Close SLOOP's web editor while the app runs.** Both use the FM-1's one MIDI port, and the FM-1 handles one request at a time.

**Tests:** `cd ios/SloopKit && swift test` runs 66 tests against a pretend FM-1 in about 25 seconds.

## 4. What to try

Plug the FM-1 into the iPad with headphones in the FM-1. A lit dot at the top left means it's connected. Tap it to see the firmware version and whether the screen link is on.

| Tab | What it does |
|---|---|
| **Sequence** | All four tracks' steps. Tap or slide to add and remove notes, drag the grip for note length, select a step to edit its velocity and ratchets. The drum track has 16 lanes |
| **Shape** | The selected track's sound: engine, preset and every parameter, with envelope and LFO graphs |
| **Arrange** | The four sections (A–D) and the song. Store the loop in a section, build a song from blocks (tap, drag, flick up to delete, drag an edge for bars), play it, SONG REC |
| **Browse** | Presets, user presets, and the four user sample slots (USR1–USR4) |

Also worth trying:

- **Screen link:** press buttons on the FM-1 and the tabs follow. Change tabs on the iPad and the FM-1 follows
- **Sampler:** from Browse, or a track on the SAMPLE engine, record a take with the device's mic, trim it, upload it to a sample slot (SMPL1–4), then put it on a track
- **iPad audio:** the FM-1's sound can play through the iPad (its speaker or Bluetooth), with the FM-1's own speaker muted
- **Projects:** the folder icon saves the FM-1's loop, sections and song order on the iPad, and exports a project as a SLOOP song file. They show in Files under On My iPad › Lupe

### On an iPhone

The same four jobs, one at a time, in landscape. These work differently from the iPad.

- **Tracks:** the chips at the top left select a track; hold one for its menu (Presets…, Record sample…, Clear all steps)
- **Sequence:** a whole bar across the screen. **Step** opens the selected step's panel over the grid; **Velocity** shows the velocity lane
- **Shape:** the active page sits in the middle and is the one the FM-1 shows. Swipe in the gaps between knobs, or across a page's title, to move to the next one
- **Arrange:** the page scrolls. Tap a block for its menu; delete is in the menu (no flick-to-delete on the phone)

### On Skiff 2.2

**The screen link.** Lupe carries Skiff 2.2 with a small patch that links the two screens, as SLOOP's does. Press a button on the FM-1 and Lupe opens that page, and pick a tab in Lupe and the FM-1 goes there too, with "Follow the FM-1's screen" on in the connection menu. An FM-1 on plain Skiff 2.2 gets an offer to update; everything else works the same without it.

Lupe also runs on [Skiff](https://github.com/illuminus5/skiff) 2.2, a Felucca-based firmware with six tracks and a song made of each track's list of patterns. Install it with Skiff's own installer, which backs up first. Lupe checks on connect that the FM-1 reports `FELUCCA v2.2`.

- **Sequence:** six tracks in the track box. A track on DRUM or DRUM-X shows the drum grid, with Skiff's 8 lanes
- **Arrange (iPad only):** a lane per track, a block per list entry, as long as it plays, in the track's colour. Tap a block for its details, drag its right edge to set how many times it plays, or hold it: let go for its menu, or drag to move it along its track. Dropped past the end, it gets a rest before it so it plays where you let go. Delete entry is in the panel under the lanes, and Undo is in the row above them. Drag a pattern from the list on the right onto a lane, or drag along the bar numbers to pick bars across every track (Duplicate after, Clear). The squares under each track's name show how many of its 16 entries it uses. While the FM-1 plays, changes that would cut in say "Stop to rearrange" with a Stop button
- **Not on Skiff yet:** projects, the sampler and the screen link (SLOOP features), and Arrange on the iPhone

### The look

Buttons are flat keys that stand on a thin edge and drop onto it when pressed; a key that's on stays down. What's selected is lifted, with a white ring. The earlier, more physical look is under the connection menu › Developer in debug builds, if you want to compare.

## 5. Known gaps

- Accessibility (VoiceOver, keyboard, largest text, Reduce Motion) hasn't been checked yet
- No UI tests. The gestures are checked by hand on my FM-1, and the full hardware pass (`qa/TEST-PLAN.md`) was on 2026-11-02
- The sampler is the newest part. It's been tried on hardware once
- The iPhone layout has only run in the simulator. You're the first to try it on a real iPhone, so touch size and feel are the things to report. Also rough: Arrange needs a scroll to reach the song, the step panel runs under the home bar, and SEL's key map isn't on the phone yet
- Installing firmware from Lupe is tested only against a pretend FM-1 (`FakeFM1`, which plays both update steps as Skiff's firmware does) and in the simulator. The first real install needs Scott with the device
- Under heavy CPU load, `aLoopSavedToASectionComesBack` occasionally fails. It's a timing problem in the test, not something you'll see in the app

## 6. Going back

- **To stock SLOOP 2.8.4:** the same installer steps with `vendor/sloop-2.8.4/sloop-2.8.4.fwsc`, or SLOOP's own installer for the current version
- **To M-VAVE's firmware:** M-VAVE's own firmware update, from their site

## Telling me what broke

Anything is useful: what you did, what you expected, what happened. The firmware version (tap the dot at the top left) helps. A screen recording is even better. Message me or open an issue here.
