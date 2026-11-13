#!/bin/bash
# Rebuilds, from Skiff's own code at the v2.5.1 tag:
# - android/fixtures/skiff/skiff-2.5.1-pages.json: what the FM-1 draws on each sound page (labels, which pages a
#   family reaches, every value's text), printed by android/tools/skiff-pagedump/pagedump.c over Skiff's
#   tests/ui_test.c. PageParityTests compares PhoneCore with it (decision 22).
# - ios/SloopKit/Sources/SloopKit/Resources/skiff-2.5.1-engines.json: every engine's EDIT descriptors and presets, as
#   Skiff's tests/descdump.c prints them. FakeSkiff answers DESC for the engine's parameters and loads PRESET's values
#   from it (CLAUDE.md rule 5: taught from the firmware's own tables).
# Needs a clone of Skiff (SKIFF_SRC, default ~/code/skiff-src) with the v2.5.1 tag, python3 with PIL, and cc. Nothing
# in the Skiff clone is changed: the tag is exported to a temporary folder and built there.
set -euo pipefail
SKIFF=${SKIFF_SRC:-$HOME/code/skiff-src}
TAG=${SKIFF_TAG:-v2.5.1}
ANDROID=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ANDROID/fixtures/skiff/skiff-2.5.1-pages.json"
ENGINES="$ANDROID/../ios/SloopKit/Sources/SloopKit/Resources/skiff-2.5.1-engines.json"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

git -C "$SKIFF" archive "$TAG" | tar -x -C "$W"
cd "$W"
mkdir -p build/gen build/host
# Python 3.9 (macOS's) has no write_text(newline=): the generators' output is the same without it
sed -i.bak 's/, newline="\\n")/)/' tools/*.py
gen() { python3 "tools/$1" "${@:2}" >/dev/null; }
gen gen_aa_icons.py build/gen/ui_icons.h
gen gen_aa_keycaps.py build/gen/ui_keycaps.h
gen gen_ui_palettes.py build/gen/ui_palettes.h
gen gen_pixel_font.py build/gen/ui_pixfont.h
gen gen_sprites.py build/gen/ui_sprites.h
gen gen_tables.py build/gen/felucca_tables.h
gen gen_fm6_patches.py build/gen/felucca_fm6.h
gen gen_samples.py build/gen/felucca_samples.h
# the UI's font: its glyphs only (no label or value text comes from it). Without libraqm, PIL can't run the
# generator; then Skiff's own build of it is used.
if ! gen gen_aa_font.py build/gen/ui_fonts.h --preset barlow-condensed 2>/dev/null; then
    cp "$SKIFF/build/gen/ui_fonts.h" build/gen/ui_fonts.h
fi
cc -O1 -w -Ibuild/gen -Ifirmware/src -Itests -o build/host/pagedump "$ANDROID/tools/skiff-pagedump/pagedump.c" -lm
./build/host/pagedump > "$OUT"
echo "wrote $OUT ($(wc -c < "$OUT") bytes)"
cc -w -Ibuild/gen -Ifirmware/src -o build/host/descdump tests/descdump.c -lm
./build/host/descdump > build/host/desc.json
python3 - build/host/desc.json "$ENGINES" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
out = {"firmware": "FELUCCA v2.5.1",
       "note": "Every engine's EDIT descriptors and presets, from Skiff's tests/descdump.c at v2.5.1 "
               "(android/scripts/skiff-page-dump.sh); don't edit by hand.",
       "P_E0": d["P_E0"],
       "engines": [{"name": e["name"], "edit": e["edit"], "presets": e["presets"]} for e in d["ENG"]]}
json.dump(out, open(sys.argv[2], "w"), separators=(",", ":"))
PY
echo "wrote $ENGINES ($(wc -c < "$ENGINES") bytes)"
