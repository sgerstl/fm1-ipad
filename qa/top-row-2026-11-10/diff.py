# The before/after check for the one-row top bar (2026-11-10). Everything under the top bar is compared with the
# before picture moved up 52 pt (104 px at 2x): the pads, heads, lanes and track controls should match exactly; what
# differs is listed as horizontal bands (pt from the screen's top) and drawn red in diff/<scene>.png.
import sys, os, glob
from PIL import Image, ImageChops
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, 'diff'), exist_ok=True)
SHIFT = 104                       # 52 pt at 2x
TOP = (24 + 64 + 16) * 2          # under the top bar, at the page's top (px)
for f in sorted(glob.glob(os.path.join(here, 'before', '*.png'))):
    n = os.path.basename(f)
    a = Image.open(f).convert('RGB'); b = Image.open(os.path.join(here, 'after', n)).convert('RGB')
    w, h = a.size
    bef = a.crop((0, TOP + SHIFT, w, h)); aft = b.crop((0, TOP, w, h - SHIFT))
    d = ImageChops.difference(bef, aft).convert('L').point(lambda v: 255 if v > 24 else 0)
    rows = [y for y in range(d.height) if d.crop((0, y, w, y + 1)).getbbox()]
    bands, start, prev = [], None, None
    for y in rows:
        if start is None: start = prev = y
        elif y > prev + 6: bands.append((start, prev)); start = prev = y
        else: prev = y
    if start is not None: bands.append((start, prev))
    pt = lambda y: (y + TOP) // 2      # in the after picture's points
    vis = aft.copy(); red = Image.new('RGB', vis.size, (255, 0, 0)); vis.paste(red, (0, 0), d)
    full = b.copy(); full.paste(vis, (0, TOP)); full.resize((w // 2, h // 2)).save(os.path.join(here, 'diff', n))
    print(f'{n:26s}', 'identical' if not bands else ' '.join(f'{pt(s)}–{pt(e)}pt' for s, e in bands))
