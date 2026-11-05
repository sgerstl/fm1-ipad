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
