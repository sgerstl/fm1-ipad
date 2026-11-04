#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# skiff-sim: Skiff's firmware built for the Mac, behind a virtual MIDI port.
#   skiff-sim/build.sh            -> skiff-sim/build/skiff-sim
# SKIFF_SRC: a Skiff checkout (default ~/code/skiff-src). Its generated headers (build/gen) are made here the first
# time, with Python 3.12 through uv and Pillow; the font needs Homebrew's libraqm (brew install libraqm).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SKIFF="${SKIFF_SRC:-$HOME/code/skiff-src}"
OUT="$HERE/build"
[ -f "$SKIFF/web/emu/felucca_web.c" ] || { echo "skiff-sim: no Skiff checkout at $SKIFF (set SKIFF_SRC)"; exit 1; }

if [ ! -f "$SKIFF/build/gen/ui_fonts.h" ] || [ ! -f "$SKIFF/build/gen/felucca_tables.h" ]; then
    echo "skiff-sim: generating Skiff's headers (build/gen)"
    (cd "$SKIFF" && DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib uv run --quiet --python 3.12 --with pillow python -c \
        "import sys; sys.argv=['build.py']; sys.path.insert(0,'tools'); import build; build.generate()")
fi

# felucca_sim.c: the browser build with the editor on (FELUCCA_OTA 1 brings usb.c's SysEx rings and main.c's
# ed_service), sim_hooks.h and editor.c after the pattern bank, as felucca.c orders them. It sits two folders down in
# the Skiff checkout so its own includes (../../tests, ../../firmware) still resolve.
mkdir -p "$SKIFF/build/sim" "$OUT"
sed -e 's|^#define FELUCCA_OTA 0$|#define FELUCCA_OTA 1|' \
    -e 's|^#include "../../firmware/src/bank.c".*$|&\
#include "sim_hooks.h"\
#include "../../firmware/src/editor.c"|' \
    "$SKIFF/web/emu/felucca_web.c" > "$SKIFF/build/sim/felucca_sim.c"
grep -q '^#define FELUCCA_OTA 1$' "$SKIFF/build/sim/felucca_sim.c" &&
    grep -q '^#include "sim_hooks.h"$' "$SKIFF/build/sim/felucca_sim.c" ||
    { echo "skiff-sim: felucca_web.c changed shape; update the sed lines in build.sh"; exit 1; }

VERSION=$(sed -n 's/^#define FELUCCA_VERSION "\([^"]*\)".*/\1/p' "$SKIFF/firmware/src/felucca.c")
cc -O2 -ffp-contract=off -std=gnu99 -w "-DFELUCCA_VERSION=\"$VERSION\"" \
    -I"$SKIFF/build/sim" -I"$SKIFF/build/gen" -I"$SKIFF/firmware/src" -I"$HERE" \
    -c "$HERE/sim_core.c" -o "$OUT/sim_core.o"
cc -O2 -Wall -Wno-deprecated-declarations -c "$HERE/sim_main.c" -o "$OUT/sim_main.o"
cc -o "$OUT/skiff-sim" "$OUT/sim_core.o" "$OUT/sim_main.o" -framework CoreMIDI -framework CoreFoundation
echo "skiff-sim: $OUT/skiff-sim (Skiff $VERSION, $(git -C "$SKIFF" rev-parse --short HEAD))"
