# SLOOP 2.8.4, pinned

The iPad app is written against SLOOP 2.8.4 (protocol v12). SLOOP releases every few days, so these files are kept here in case the FM-1 needs reflashing to this exact version. Downloaded 2026-10-31 from [isod89/sloop-fm1](https://github.com/isod89/sloop-fm1), release and tag `v2.8.4` (published 2026-10-30).

| File | What | SHA-256 |
|---|---|---|
| `sloop-2.8.4.fwsc` | firmware, from the release | `5a6a0843c868650dba6718cf85e43e719aec18c3dc5cc803c57c38b382158d4e` |
| `sloop-editor-2.8.4.html` | the web editor, from the release (reference only; Chrome or Edge for Web MIDI) | `25fe6043084b6d6bdd0529699e2b8cf6f4ba186f7d04801c2564882dabb76f03` |
| `EDITOR_PROTOCOL.md` | `web/EDITOR_PROTOCOL.md` at the tag | `24cb1a3009633ff24e7b9d5cee68f2f521022e5580d7de4d42ed4e34e0908f25` |
| `LICENSE`, `LICENSING.md` | SLOOP's licences at the tag (GPL-3.0 code, assets as listed) | |

The app itself is written from `EDITOR_PROTOCOL.md`, not from the editor's code.

To reflash: the firmware hub or SLOOP's own installer, choosing this file. On connect, the app checks that `INFO` reports `FELUCCA SLOOP 2.8.4`, protocol 12.
