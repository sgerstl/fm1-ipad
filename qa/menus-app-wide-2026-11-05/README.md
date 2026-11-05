# Every system menu is Jib's own (2026-11-05)

Scott: the connection dot's menu and its Developer submenu were "super squished and tight and small". Every menu now uses Jib's menu panel, the same as Arrange's hold menu: 52 pt rows, 8 pt between groups, submenus opening in place with a Back row, status lines as smaller text, one level-3 shadow. Keys: ↑ ↓ → ← Return Escape.

## Converted

| Where | Was | Now |
|---|---|---|
| iPad: the connection dot (01) | system `Menu`, with a `Picker` (source), `Toggle`s (follow the screen, play through the iPad), `Section`s of text | Jib's menu: the source as two ticked rows, the toggles as ticked rows, the audio and diagnostics lines as text rows |
| iPad and iPhone: Developer (02) | system submenu with two `Picker`s | a submenu: Install firmware…, Look (Flat / Physical), Knob tap (Arc / Slider), ticked |
| iPhone: the ⋯ key (03) | system `Menu` | Jib's menu: play through the iPhone, the source, Developer |
| Projects sheet: a row's ⋯ key and long press | system `Menu` and `contextMenu` | Jib's menu (its own layer, since the sheet covers the app): Rename, Duplicate, Export…, Delete. Export opens the system's share sheet, which is right |
| Browse: a recorded sample slot's long press | system `contextMenu` | Jib's menu at the finger: Record over, Clear (and both as VoiceOver actions) |

Already Jib's own: Arrange's menus, the track menu, the section menu, the firmware picker.

## Left as they are, and why

- **The Projects sheet's "Projects / Safety copies" switch:** a segmented control, not a menu.
- **Alerts and confirmations** (Delete project?, Clear sample?, Replace sample?, Open over unsaved work, SONG REC replaces the song, Erase pattern?, Clear unused patterns?): system dialogs, not menus.
- **The share sheet:** the system's, on purpose.

## Pre-flight (design-standards)

- Rows 52 pt, text rows 13 pt and wrapping, one shadow per panel, tokens only.
- Toggles are ticked rows with the state in the tick and in VoiceOver ("Current", selected); picking closes the menu.
- **Not checked:** keys and VoiceOver running; the Projects sheet's and Browse's menus on screen (built the same way, not opened here).
