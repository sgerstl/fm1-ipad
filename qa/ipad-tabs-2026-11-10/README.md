# The iPad's tabs: Pads · Timeline · Mix (2026-11-10)

Scott: build the iPad tabs as Pads · Timeline · Mix; the Pads/Timeline switch goes; keep the slide with the editor staying put; the tools follow the tab; the phone's wording.

- `TopBar.songTabs` (Skiff with performs): the same tab-on-a-line look (TabRise). Pads and Timeline set `ui.page = .song` and `ui.songView`, so SongTab's existing Pads ↔ Timeline slide runs unchanged; Mix sets `.mixer`. `SongViewSwitch` is no longer in the row (its hidden copy in SkiffArrange's tool row, measured for spacing, stays).
- SLOOP's top bar keeps its own tabs: a follow-up.

Diff (before = the bf87863 after captures): every scene changes only in the top row (y 32–79 pt). The full-size Timeline also differs in its blocks' pattern pictures: those before shots were taken before bf87863's thumbnail-ink fix, not a change made here.
