# Structure map: proposed changes for the phone (2026-11-17)

For Scott to agree before any screen is built (repo `CLAUDE.md` rule 4). When agreed, these lines replace the matching parts of `design/structure-map.md`. Nothing here changes the iPad (still Pads · Timeline · Mix).

## What changes and why

| Today (map and decisions) | Proposed | Why |
|---|---|---|
| Phone tabs: Pads · Edit · Timeline (decision 28, 2026-11-14); Mix as a pop-up from GLO or the project menu | **Pads · Edit · Timeline · Mix** | Scott, 2026-11-17: "I think the mix tab needs to come back. I think most people want it more accessible." Decided. |
| The map's phone section (2026-11-10) also lists a **Sounds** tab | **Sounds stays a sheet** (from the track head's hold menu, SAVE and the panel's Sounds ⌄) | Five tabs don't fit the header at the iPhone's width. The sheet already holds the whole browser. Proposal |
| Edit with the sound panel docked: board 75's A or B (`[open]`) | **8-step pages:** the grid shows steps 1–8 or 9–16 at about 65 pt beside a 280-wide panel, with a 16-cell minimap under it that shows the other page's notes and pages on a tap | Decided, Scott 2026-11-17. The other options (bottom panel, slim panel) were drawn and ruled out (vault `figma-ui-kit.md`, "Edit squeeze") |
| GLO on the FM-1 opens the Mix pop-up | **GLO opens the Mix tab**, then steps its pages (Mixer, Delay, Reverb, Chorus, Global) | Follows from the tab |

## The phone's tabs, as the map would read

| Tab | What's on it |
|---|---|
| **Pads** | The grid of every track's entries, row heads (badge, name, Mute), the scenes toolbar (Store and 16). Hold menus as today. |
| **Edit** | The selected pad's pattern. Panel shut: all 16 steps. Panel docked (FX, SEL, ENV, LFO, EDIT, ARP): **8 steps a page** with the minimap. |
| **Timeline** | The song's lanes and blocks, zoom, the ruler. A refusal ("Stop to change the song") shows in the app strip. |
| **Mix** | Six strips (level fader with meter, dB, Mute and Solo, reverb send), and the Global pages as sub-pages: Mixer · Delay · Reverb · Chorus · Global. |

**Header, one row:** Song menu, the four tabs, then flush right: Launch at (Bar ⌄), the readout (opens the tempo popup), Record, Stop or Play. At narrow widths, things give way in the order in `spec.md` 4.1; the tabs, Record and Play never go.

**Over any tab:** the Sounds sheet, Projects, Settings, the Launch at menu and the tempo popup. Messages show in the app strip, bottom centre.

## The FM-1's buttons on the phone (changes only)

| FM-1 button | On the phone |
|---|---|
| GLO | The Mix tab; pressed again, its next page |
| FX, SEL, ENV, LFO, EDIT, ARP | On Edit: dock the sound panel, with the grid paging 8 steps. On other tabs: as today |
