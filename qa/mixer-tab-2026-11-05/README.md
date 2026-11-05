# The Mixer tab, 2026-11-05

Scott: "we might want a mixer tab, so we should do that." Skiff's tabs are now **Song · Shape · Mixer · Browse**. The bottom mixer panel and the mixer key beside the tempo are gone.

- **The page:** the FM-1's pads on the left, as on Shape and Browse. On the right, MIXER: the six strips (track number and the sound's first word, the LEVEL fader with its dB, PAN, the REVERB send, MUTE), in one panel 452 pt tall. Below it, SHARED: Delay, Reverb, Chorus and Global as Shape's own cards (columns over the graph), two to a row.
- **GLO:** on the FM-1 or its pad here, GLO lands on the Mixer tab, and pressing it again steps the sections (MIXER, DELAY … GLOBAL), scrolling each to the top. Linked, a section touched here (the strips' panel, a card) shows its page on the FM-1. The section on the FM-1 gets the lit top edge Shape's cards have. The GLO pad is lit while the tab is open.
- **SLOOP** keeps its four tabs: GLO is Shape's there.

Checked: the app builds; `-demo -demo-skiff -demo-link -page mixer` (`mixer.jpg`) at 1366 × 1024.

Not checked: GLO stepping with the link against a sim (the button map's tests cover the place mapping, unchanged); the iPhone, which reaches the page only by following GLO; VoiceOver order.

Design pre-flight: ran. The strips and cards are the existing components. A first try at 52 pt pan and reverb knobs made each strip 196 pt wide (KnobDial is 88 pt wide above size 40) and pushed the page off screen, so they stay at 40.

**For the polish pass (cramped or uncertain):**
- The pan and reverb knobs are small for the room the strip now has. A larger dial needs KnobDial's width rule changed.
- The strips show the sound's first word only.
- LANE MIX (a drum kit's lane levels and pans) could open from a drum strip once the EDIT pages land.
- Global's card has two empty columns.
