#!/bin/sh
# Rebuild these pictures from Skiff 2.5.1's own UI code (tests/ui_render.c's stubs and scenes), without touching
# ~/code/skiff-src's checkout: the tag is exported to a temporary folder and built there.
#   design/boards/fm1-screens/tools/regenerate.sh
# Needs uv (Python 3.12 + Pillow + fontTools for Skiff's header generators) and Homebrew's libraqm.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; OUT="$(dirname "$HERE")"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
git -C "${SKIFF_SRC:-$HOME/code/skiff-src}" archive v2.5.1 | tar -x -C "$W"
cd "$W"
DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib uv run --quiet --python 3.12 --with pillow --with fonttools python -c \
    "import sys; sys.argv=['build.py']; sys.path.insert(0,'tools'); import build; build.generate()"
sed 's/^int main(int argc, char \*\*argv)$/int ui_render_main(int argc, char **argv)/' tests/ui_render.c > tests/ui_render_lib.c
cp "$HERE/fm1shots.c" tests/
cc -O1 -w '-DFELUCCA_VERSION="v2.5.1"' '-D__DATE__="Jan  1 2026"' -Ibuild/gen -Ifirmware/src -Itests -o fm1shots tests/fm1shots.c -lm
mkdir -p shots/ppm && ./fm1shots shots all
uv run --quiet --with pillow python - "$W/shots/ppm" "$OUT" <<'PY'
import sys, glob, os
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
os.makedirs(f"{out}/themes", exist_ok=True)
for f in sorted(glob.glob(f"{src}/*.ppm")):
    pal, name = os.path.basename(f)[:-4].split("_", 1)
    big = Image.open(f).convert("RGB").resize((960, 960), Image.NEAREST)
    big.save(f"{out}/{name}.png" if pal == "SKIFF" else f"{out}/themes/{pal}_{name}.png")
PY
echo "regenerated into $OUT (contact sheets not rebuilt)"
