# Testing Lupe

Lupe is an iPad and iPhone app that works alongside an M-VAVE FM-1 running Skiff (Skiff-Lupe 2.2 or 2.5.1: Skiff with Lupe's screen link). The FM-1 still makes the sound and stores everything. The iPad shows all six tracks at once, edits them, and arranges each track's patterns into a song; an iPhone does the same jobs one screen at a time. It talks to the FM-1 over USB MIDI using Skiff's editor protocol.

Lupe no longer works with SLOOP (decision 43, 2026-11-15). An FM-1 on SLOOP is offered Skiff-Lupe instead; see step 1 about its projects.

This guide gets it running on your FM-1 and your iPad or iPhone. Allow about 30 minutes.

## What you need

- An FM-1 and a USB-C cable to the iPad or iPhone (or to the Mac, see step 3)
- A Mac with Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An iPad on iPadOS 18 or later. The layout is drawn for a 13-inch iPad in landscape and scaled to fit smaller ones
- Or an iPhone on iOS 18 or later, used in landscape. An iPhone 15 or later plugs straight into the FM-1 over USB-C; an older one needs Apple's Lightning to USB camera adapter
- Chrome, for SLOOP's web editor if your FM-1 runs SLOOP now (its backup, Web MIDI)
- A free Apple developer account is enough to sign the app

## 1. Back up the FM-1

The app writes to the FM-1's flash: projects, patterns, user presets and samples. Back up first.

- **Already on Skiff:** Lupe backs up before it installs anything (below), or use Skiff's web editor.
- **On SLOOP:** open SLOOP's web editor, Connect, then Song & sections, then Save a backup. Lupe can't read SLOOP any more, so it can't take this backup for you. Installing Skiff leaves SLOOP's projects in the FM-1's memory, but Skiff 2.x doesn't open them: it shows them as OLD FORMAT. Skiff's web editor can convert them (take a backup there and restore it; Skiff's README, "Updating to 2.0").
- **Still on M-VAVE's firmware:** your patterns aren't in Skiff's format anyway. Note anything you want to keep before installing.

## 2. Install Skiff-Lupe

Lupe installs Skiff-Lupe (Skiff with Lupe's screen link, downloaded from Lupe's GitHub release when chosen) and puts M-VAVE's stock V15 back, over the same USB cable. `FIRMWARE.md` lists the exact files and their SHA-256. Not yet tried on a real FM-1 by anyone but Scott; Skiff's own installer (its README) is the alternative. How it works:

- **On connect.** If the FM-1 runs something Lupe doesn't speak (M-VAVE's firmware, SLOOP, another Skiff version), Lupe says so and offers Skiff-Lupe. If an earlier install was cut off and the FM-1 waits in update mode (USB name "Felucca Update", UPDATE MODE on its screen), Lupe offers to finish it. If a restore of stock V15 was cut off (M-VAVE's update mode, `ota-FM-1_015`), Lupe offers to finish that, with V15 only. Any other update mode is left to its own updater.
- **On purpose.** Debug builds: tap the connection dot (the ⋯ menu on an iPhone), then Developer › Install firmware…, and pick a Skiff-Lupe build, or **Restore stock V15** under Back to stock. V15 goes on only if the FM-1 shipped with V15: a unit that ever ran V16 is refused before anything is written. Lupe can't talk to stock firmware, so after a restore it offers Skiff-Lupe the next time you plug in. V15 can't go on a V16 unit. There's no "install through stock": switching directly is what the sources support (`FIRMWARE.md`, "Going through stock V15").
- **Before writing.** When the FM-1 is connected, Lupe backs up every object the running firmware lists (projects, the music now, settings, presets, samples) to Files › On My iPad › Lupe › Skiff › Backups, in Skiff's own backup format, so its web editor can restore it. An install writes only the firmware and keeps the store. Over SLOOP there's no backup from Lupe (step 1).
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

**Without the FM-1:** add `-demo` as a launch argument (Product › Scheme › Edit Scheme › Arguments), or pick "Demo FM-1" from the connection menu at the top left (on an iPhone, the ⋯ menu at the top right). The demo is a pretend Skiff 2.2 (`-demo-fw 2.5.1` for 2.5.1), with six tracks and a song.

**Close any other FM-1 editor (Skiff's web editor) while the app runs.** Both use the FM-1's one MIDI port, and the FM-1 handles one request at a time.

**Tests:** `cd ios/SloopKit && swift test` runs about 300 tests against pretend FM-1s, in about two minutes.

## 4. What to try

Plug the FM-1 into the iPad with headphones in the FM-1. A lit dot at the top left means it's connected. Tap it to see the firmware version and whether the screen link is on.

Lupe's tabs on the iPad are Song and Mix: the Song tab has the pads or the Timeline over the pattern editor, Mix the six tracks' levels and the shared effects. A button pressed on the FM-1 opens its page in Lupe (the screen link).

Also worth trying:

- **Screen link:** press buttons on the FM-1 and Lupe follows. Change tabs in Lupe and the FM-1 follows
- **Sampler:** from a track's menu, record a take with the device's mic, trim it, upload it to a user sample slot (USR1–3), then put it on a track
- **iPad audio:** the FM-1's sound can play through the iPad (its speaker or Bluetooth); turn the FM-1's MASTER down to quiet its own speaker
- **Projects:** the FM-1 menu › Projects… saves the FM-1's music and its patterns on the iPad. They show in Files under On My iPad › Lupe › Skiff

### On an iPhone

The same four jobs, one at a time, in landscape. These work differently from the iPad.

- **Tracks:** the chips at the top left select a track; hold one for its menu (Presets…, Record sample…, Clear all steps)
- **Sequence:** a whole bar across the screen. **Step** opens the selected step's panel over the grid; **Velocity** shows the velocity lane
- **Shape:** the active page sits in the middle and is the one the FM-1 shows. Swipe in the gaps between knobs, or across a page's title, to move to the next one
- **Arrange:** the page scrolls. Tap a block for its menu; delete is in the menu (no flick-to-delete on the phone)

### On Skiff 2.2

**The screen link.** Lupe carries Skiff with a small patch that links the two screens. Press a button on the FM-1 and Lupe opens that page, and pick a tab in Lupe and the FM-1 goes there too, with "Follow the FM-1's screen" on in the connection menu. On MOD it follows the cursor too: turn KNOB 1 on the FM-1 and Lupe shows the same route, pick a route in Lupe and the FM-1's highlight moves there. An FM-1 on plain Skiff 2.2, or on the link's first build (no cursor), gets an offer to update; everything else works the same without it.

Lupe also runs on [Skiff](https://github.com/illuminus5/skiff) 2.2, a Felucca-based firmware with six tracks and a song made of each track's list of patterns. Install it with Skiff's own installer, which backs up first. Lupe checks on connect that the FM-1 reports `FELUCCA v2.2`.

- **Sequence:** six tracks in the track box. A track on DRUM or DRUM-X shows the drum grid, with Skiff's 8 lanes
- **Arrange (iPad only):** a lane per track, a block per list entry, as long as it plays, in the track's colour. Tap a block for its details, drag its right edge to set how many times it plays, or hold it: let go for its menu, or drag to move it along its track. Dropped past the end, it gets a rest before it so it plays where you let go. Delete entry is in the panel under the lanes, and Undo is in the row above them. Drag a pattern from the list on the right onto a lane, or drag along the bar numbers to pick bars across every track (Duplicate after, Clear). The squares under each track's name show how many of its 16 entries it uses. While the FM-1 plays, changes that would cut in say "Stop to rearrange" with a Stop button

### The look

Buttons are flat keys that stand on a thin edge and drop onto it when pressed; a key that's on stays down. What's selected is lifted, with a white ring.

## 5. Known gaps

- Accessibility (VoiceOver, keyboard, largest text, Reduce Motion) hasn't been checked yet
- No UI tests. The gestures are checked by hand on my FM-1, and the full hardware pass (`qa/TEST-PLAN.md`) was on 2026-11-02
- The sampler is the newest part. It's been tried on hardware once
- The iPhone layout has only run in the simulator. You're the first to try it on a real iPhone, so touch size and feel are the things to report. Also rough: Arrange needs a scroll to reach the song, the step panel runs under the home bar, and SEL's key map isn't on the phone yet
- Installing firmware from Lupe is tested only against a pretend FM-1 (`FakeFM1`, which plays both update steps as Skiff's firmware does) and in the simulator. The first real install needs Scott with the device

## 6. Going back

- **To SLOOP:** SLOOP's own installer (Chrome). Lupe won't connect to it
- **To M-VAVE's firmware:** M-VAVE's own firmware update, from their site

## Telling me what broke

Anything is useful: what you did, what you expected, what happened. The firmware version (tap the dot at the top left) helps. A screen recording is even better. Message me or open an issue here.
