# Navigation: Song · Mix · Sounds, the panel everywhere, 2026-11-06

Scott's decision, for Skiff on the iPad; the iPhone and SLOOP are unchanged.

1. **No Shape tab.** The tabs are **Song · Mix · Sounds** (Mixer is now Mix, Browse is now Sounds).
   - **ENV, LFO, FX, SEL, EDIT and ARP** bring in the sound panel on whichever tab is up. That applies to the FM-1's buttons, the rail and the pads on Mix and Sounds. Anything else that used to open Shape (the track list's chord or arp tag, SEL held on the FM-1) does the same: a request for the Shape page now opens the panel over the tab that's up. ShapeSection is the panel's content, as before.
   - **GLO** goes to Mix and steps its sections. **SAVE's PRESETS and USER** go to Sounds (the other SAVE pages are still being settled). **HOME** closes the panel.
2. **The rail follows the FM-1, top to bottom: FX, SEL, ENV, LFO, EDIT, ARP, then SEQ** (`song-with-lfo.jpg`). The labels are the FM-1's.
   - **SEQ** on the Song tab steps SEQ's pages as the tab's own places, as an FM-1 SEQ press does:
     - NOTES and FEEL: the step inspector, flashed;
     - PATTERN: the whole-track popover;
     - AUTOMATION: the motion lanes, shown and flashed;
     - SONG: the lanes.
   - Linked, the FM-1 goes to each page too. From Mix or Sounds, SEQ goes to the Song tab first, on NOTES. It closes the panel. The SEQ pad on Mix and Sounds does the same.
3. **Stepping by touch:** the panel's header shows the button's pages as chips (LFO · LFO 2 · MOD). A tap brings that page's card forward and sends the FM-1 there; the current one is lit (`chip-to-mod.jpg`). Pressing the key again still steps them too.

Checked: the app builds; the simulator, Song tab with LFO open, then the MOD chip tapped (MOD lit, the FM-1 on MOD 3/3, its card forward).

Not checked: SEQ's steps against the linked fake on screen; the FM-1's SEL-held keys layer landing in the panel; VoiceOver through the chips.

Design pre-flight: ran. The chips are 32 pt capsules with 40 pt targets, using the selected-key colours. The rail keys are 48 pt.
