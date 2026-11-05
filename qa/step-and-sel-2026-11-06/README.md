# Repeat presses step and reveal; SEL's graphs, 2026-11-06

## 1. The same button again steps its pages, and the page's card comes forward

- **Sound panel (Song and Mixer):** a rail key pressed again, a pad on the Mixer, or the FM-1's own button steps through that button's pages, round and round. The rail key no longer closes the panel; ✕, HOME, Escape, a tap outside (Song tab) or another tab do.
- **Shape tab:** the pads pressed again do the same. Unlinked they now step too; before, only a linked FM-1 did.
- **The page's card:**
  - it scrolls to the top of the panel or the tab, or as far as the scroll goes for the last cards;
  - it gets the lit top edge (the FM-1's page when linked; the focused page when not) and a lift (a soft shadow, 0.45 at 12 pt);
  - it moves in 200 ms ease-out, instantly with Reduce Motion.
- **One focused page** (`EditorUI.focusedPage`) drives both:
  - every press here sets it, and sends the page to the FM-1 when linked;
  - every page change on the FM-1 sets it (AppView, before the button map).
  So the two screens stay in step both ways.
- Checked: three presses on the LFO rail key, LFO → LFO 2 (the same card) → MOD (`lfo-pressed-to-mod.jpg`). MOD reads "On the FM-1 · 3/3", lit and lifted. It's the last card, so it rises as far as the scroll allows.
- **Skiff's timing:** I couldn't find a scroll or animation constant in Skiff's UI code to match, so this uses the app's 200 ms.

## 2. SEL's graphs: SCALE, CHORD, FOLLOW (ui_graph.c graph_scale, graph_chord, graph_follow)

- **SCALE:** the 12 keys as bars, black high and white low. Notes in the scale are in the track's colour, the root white (Skiff's accent), notes out of the scale grey. The scale masks are ported from seq.c `SCALE_MASK`.
- **CHORD:** the chord's name ("Cm7") over two or three octaves of keys from the C below it. The chord's notes are coloured, its root white.
  - **The chord is the one on the track's ROOT from C4**, as Skiff shows before a chord is played. The chord last played isn't sent to an editor.
  - The caption reads ON ROOT, or ROOT ONLY for a one-voice track (MONO, LEG, UNI with the ARP off), as on the FM-1.
  - OFF says "CHORD KEYS OFF / K1 DIA3: IN-KEY CHORDS"; a kit says "NO CHORDS ON KITS".
  - Built with **`SkiffChord`**, a port of chord.c's `chord_make` and `chord_name` with tests: DIA3/DIA7 in key, the note below for a key outside the scale, CHR on major, every shape, every voicing, the names.
- **FOLLOW:** OFF, "T*n* PLAYS A KIT", or "FOLLOWS T2 · KEY BY ITS ROOT" in that track's colour. **The chord the followed track plays live isn't sent to an editor**, so its keys can't be drawn; the second line says it shows on the FM-1.
- Checked: SEL with CHORD OFF and FOLLOW OFF (`sel-pages.jpg`). CHORD set to DIA7 on a LEG track reads "Cmaj7, ROOT ONLY", with the root alone lit (`chord-dia7.jpg`). The package suite passes (221 tests).
- Not checked: side by side with skiff-sim's SEL screens (no sim screenshots were taken this round).

## Lupe's chord display (the key strip above SEL)

"What the FM-1's keys play" is SLOOP's logic. Its chord mode uses SLOOP's chord names (TRIAD, 7TH, 9TH…), not Skiff's DIA3, DIA7, MAJ…POW and VOICING. So on Skiff, with CHORD on, it would light the wrong notes. My recommendation: keep Skiff's CHORD graph as the card, and fold Lupe's strip in by rebuilding its chord mode on `SkiffChord`. Then each key's chord, which the FM-1 can't show all at once, is right. That's a small follow-up, not done here.

## Design pre-flight

Ran it. There are no new components: the cards' existing lit edge, plus a shadow for the lift. The graphs use Skiff's layout in the track's colour, with white for Skiff's accent. Motion is 200 ms or none under Reduce Motion. The FOLLOW and CHORD notes are 13/11 pt in the graph wells.

## 3. ARP and ARP 2 as one card

ARP and ARP 2 are now one card, like LFO and INSERT: two rows labelled with their page names over the one arpeggio graph (`arp-merged.jpg`). Tapping a row's label focuses it and, linked, sends the FM-1 to that page. Repeat presses of ARP step between the rows, and the card keeps the highlight.

**Skiff's other pairs on one graph** (params.c PAGES):
- LFO and LFO 2 (`GR_LFO`) and INSERT and INSERT 2 (`GR_INS`), already merged;
- ARP and ARP 2 (`GR_ARP` and `GR_ARP2`, both `graph_arp`), now merged.

ENV and ENV 2 are both `GR_ADSR`, but each draws its own envelope, so they stay two cards. OP1–OP4 ENV share `GR_ADSR` too, but Skiff 2.2 never shows them.

## 4. The Mixer full width; the highlight's move

- **No left column on the Mixer, and no track box over it.** A strip's name selects its track. The strips and the shared-card carousel span the window beside the rail.
- **A button's panel pushes the Mixer:** the strips and the carousel narrow beside it, then get the width back when it closes (`mixer-full-width-and-pushed.jpg`).
- **The highlight's move:** the lit edge followed the FM-1's page and the lift followed the focused page, each on its own animation, so they could change on different frames and read as a jump. Both now follow one value, the card brought forward (the FM-1's page when linked, the focused page when not), in one 180 ms ease-out crossfade. It runs beside the carousel's 0.4 s spring rather than inside it, and is instant under Reduce Motion. The sound panel's stepping and Shape use the same card, so the same move.
- Not checked: the crossfade watched frame by frame on a device. The screenshots can't show motion.
