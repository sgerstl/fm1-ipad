# The before/after check for the Timeline's open tab (2026-11-10): whole frames compared unshifted. The tab should be
# the only difference, on the "-shut" Timeline scenes at Half; every other scene should be identical.
import os, glob
from PIL import Image, ImageChops
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, 'diff'), exist_ok=True)
for f in sorted(glob.glob(os.path.join(here, 'before', '*.png'))):
    n = os.path.basename(f)
    a = Image.open(f).convert('RGB'); b = Image.open(os.path.join(here, 'after', n)).convert('RGB')
    d = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v > 24 else 0)
    box = d.getbbox()
    vis = b.copy(); vis.paste(Image.new('RGB', vis.size, (255, 0, 0)), (0, 0), d)
    vis.resize((vis.width // 2, vis.height // 2)).save(os.path.join(here, 'diff', n))
    print(f'{n:24s}', 'identical' if not box else 'differs in x %d–%d, y %d–%d pt' % tuple(v // 2 for v in (box[0], box[2], box[1], box[3])))
