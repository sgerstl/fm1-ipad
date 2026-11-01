# SLOOP 2.8.4 + screen link

A small addition to [SLOOP](https://github.com/isod89/sloop-fm1) 2.8.4 (GPL-3.0, by Leo Kuroshita) so the iPad app and the FM-1 can follow each other's screen. Everything else is stock 2.8.4.

| File | What |
|---|---|
| `0001-screen-link.patch` | The change: 47 lines in `firmware/src/editor.c` |
| `sloop-2.8.4-screen-link.fwsc` | The built package, SHA-256 `97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110`. Installed on my FM-1 on 2026-11-01 |

## What it adds to the editor protocol

| cmd | Request | Reply |
|---|---|---|
| 90 UI | — | home (0/1), page (index into SLOOP's `PAGES` table in `params.c`), layer (`LY_*`, 0 none), menu (0 off) |
| 91 UI_GOTO | page | opens that page as its button would; the reply is the state, as UI. No reply for a page that isn't shown on the selected track |

While `WATCH` is sent with bit 2 (`WATCH 7`), the FM-1 also **pushes 90 UI whenever the screen changes** (a button pressed, a page walked, a layer held, the menu). Stock editors never send bit 2, 90 or 91, so SLOOP's own web editor sees no difference. `INFO` still says `FELUCCA SLOOP 2.8.4`, protocol 12: the app tells the two firmwares apart by asking 90 UI (stock SLOOP doesn't answer).

## Building it (Blue Lion)

As SLOOP's `BUILDING.md`: Docker Desktop, Python with Pillow, JieLi's Linux toolchain (`tools/get_toolchain.sh` into `~/.jieli`) and three files of JieLi's AC79 SDK (a sparse clone of `gitee.com/Jieli-Tech/fw-AC79_AIoT_SDK` at `AC79NN_SDK_V1.2.1_2023-12-13`, 2.9 MB).

```
git clone --branch v2.8.4 https://github.com/isod89/sloop-fm1.git sloop-src
cd sloop-src && git apply ../fm1-ipad/sloop/0001-screen-link.patch
bash ./build.sh                       # build/felucca.fwsc
```

Unpatched, this build matches the official 2.8.4 package to 19 bytes of 610,052 (a build stamp and the checksums over it).

## Installing it

SLOOP's site generator wraps the installer around a package and pins its SHA-256:

```
python3 web/make_site.py build/felucca.fwsc 2.8.4-screen-link OUT
cd OUT && python3 -m http.server 8766 --bind 127.0.0.1
```

Then in Chrome: back up first (`http://localhost:8766/webapp/editor/`, Connect, Song & sections, Save a backup), then install (`http://localhost:8766/webapp/installer/`). SLOOP keeps projects, presets, samples and settings across installs. USB rescue: hold OCT− while powering on. Back to stock: the same steps with `vendor/sloop-2.8.4/sloop-2.8.4.fwsc`.

## Licence

The patch and the package are GPL-3.0, as SLOOP is. The iPad app only speaks the protocol; it contains no SLOOP code.
