# Testing Jib

Jib is an iPad app that works alongside an M-VAVE FM-1 running SLOOP. The FM-1 still makes the sound and stores everything. The iPad shows all four tracks at once, edits them, and arranges sections into songs. It talks to the FM-1 over USB MIDI using SLOOP's editor protocol.

This guide gets it running on your FM-1 and iPad. Allow about 30 minutes.

## What you need

- An FM-1 and a USB-C cable to the iPad (or to the Mac, see step 3)
- A Mac with Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An iPad on iPadOS 18 or later. The layout is drawn for a 13-inch iPad in landscape and scaled to fit smaller ones
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

Pick your iPad as the destination and run. On the first launch, allow the microphone. iOS counts the FM-1's USB audio as a microphone, and the sampler records from the iPad's own mic.

You can also run it on the Mac: pick **My Mac (Designed for iPad)** and plug the FM-1 into the Mac.

**Without the FM-1:** add `-demo` as a launch argument (Product › Scheme › Edit Scheme › Arguments), or pick "Demo FM-1" from the connection menu at the top left. The demo edits a step every 6 seconds so there's something moving.

**Close SLOOP's web editor while the app runs.** Both use the FM-1's one MIDI port, and the FM-1 handles one request at a time.

**Tests:** `cd ios/SloopKit && swift test` runs 63 tests against a pretend FM-1 in about 25 seconds.

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
- **Sampler:** from Browse, or a track on the SAMPLE engine, record a take with the iPad's mic, trim it, upload it to a USR slot, then put it on a track
- **iPad audio:** the FM-1's sound can play through the iPad (its speaker or Bluetooth), with the FM-1's own speaker muted
- **Projects:** the folder icon saves the FM-1's loop, sections and song order on the iPad, and exports a project as a SLOOP song file. They show in Files under On My iPad › Jib

## 5. Known gaps

- Accessibility (VoiceOver, keyboard, largest text, Reduce Motion) hasn't been checked yet
- No UI tests. The gestures are checked by hand on my FM-1, and the full hardware pass (`qa/TEST-PLAN.md`) was on 2026-11-02
- The sampler is the newest part. It's been tried on hardware once
- Under heavy CPU load, `aLoopSavedToASectionComesBack` occasionally fails. It's a timing problem in the test, not something you'll see in the app

## 6. Going back

- **To stock SLOOP 2.8.4:** the same installer steps with `vendor/sloop-2.8.4/sloop-2.8.4.fwsc`, or SLOOP's own installer for the current version
- **To M-VAVE's firmware:** M-VAVE's own firmware update, from their site

## Telling me what broke

Anything is useful: what you did, what you expected, what happened. The firmware version (tap the dot at the top left) helps. A screen recording is even better. Message me or open an issue here.
