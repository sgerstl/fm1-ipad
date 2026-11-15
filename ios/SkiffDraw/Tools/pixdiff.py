# pixdiff (spike, decision 45): SkiffDraw's frames (240 x 240 PPM) against design/boards/fm1-screens (960 x 960 PNG,
# 4x nearest). Per frame: pixels that differ over the whole screen, outside the header's battery icon (x 216-236,
# y 7-17, which NOTES.md says depends on the scene before), and in the panel (screen y 76-213) alone.
#   uv run --with pillow python ios/SkiffDraw/Tools/pixdiff.py FRAMES_DIR design/boards/fm1-screens [DIFF_DIR]
import sys, os, glob
from PIL import Image
frames, ref = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else None
tot = [0, 0, 0]
for f in sorted(glob.glob(f"{frames}/*.ppm")):
    name = os.path.basename(f)[:-4]
    r = f"{ref}/{name}.png"
    if not os.path.exists(r):
        continue
    a = Image.open(f).convert("RGB")
    b = Image.open(r).convert("RGB").resize((240, 240), Image.NEAREST)
    pa, pb = a.load(), b.load()
    d = [(x, y) for y in range(240) for x in range(240) if pa[x, y] != pb[x, y]]
    nb = [p for p in d if not (216 <= p[0] <= 236 and 7 <= p[1] <= 17)]
    pn = [p for p in d if 76 <= p[1] <= 213]
    for i, v in enumerate((d, nb, pn)): tot[i] += len(v)
    box = "" if not nb else f"  first {nb[0]}, box x {min(p[0] for p in nb)}-{max(p[0] for p in nb)} y {min(p[1] for p in nb)}-{max(p[1] for p in nb)}"
    print(f"{name:40s} all {len(d):5d}  not battery {len(nb):5d}  panel {len(pn):5d}{box}")
    if out and d:
        os.makedirs(out, exist_ok=True)
        m = a.copy(); pm = m.load()
        for p in d: pm[p] = (255, 0, 255)
        m.resize((480, 480), Image.NEAREST).save(f"{out}/{name}_diff.png")
print(f"TOTAL all {tot[0]}  not battery {tot[1]}  panel {tot[2]}  (of {240*240} a frame)")
