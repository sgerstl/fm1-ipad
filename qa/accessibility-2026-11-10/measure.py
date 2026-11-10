#!/usr/bin/env python3
"""Second opinion on the audit's contrast lines: the contrast measured in the screenshot itself, within each flagged
element's frame, between its text (the 97th percentile of luminance, the light end on Lupe's dark page) and its
background (the median). Screens are captured portrait (the device's own orientation) while Lupe runs in landscape:
a landscape point (x, y) is the portrait pixel (W - ky, kx), k = 2 on the iPads, 3 on the phones.
Run: python3 measure.py <audit dir>   (writes contrast-measured.tsv there and prints a summary). 2026-11-10."""
import sys, os, csv
from PIL import Image

def lin(v):
    v /= 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

def L(p): return 0.2126 * lin(p[0]) + 0.7152 * lin(p[1]) + 0.0722 * lin(p[2])

d = sys.argv[1]
out = []
for f in sorted(os.listdir(d)):
    if not f.endswith(".tsv") or f.startswith(("all", "contrast")): continue
    img = None
    for row in csv.reader(open(os.path.join(d, f)), delimiter="\t"):
        if len(row) < 7 or row[1] != "contrast" or not row[5]: continue
        if img is None:
            img = Image.open(os.path.join(d, row[0] + ".png")).convert("RGB")
            W, H = img.size
            land = W < H          # portrait capture of a landscape app
            k = 3 if row[0].startswith("iPhone") else 2      # pixels a point: the phones here are @3x, the iPads @2x
        xy, wh = row[5].rsplit(",", 1)[0], row[5].rsplit(",", 1)[1]
        x, y = map(int, row[5].split(",")[:2]); w, h = map(int, wh.split("x"))
        if land: box = (W - k * (y + h), k * x, W - k * y, k * (x + w))
        else: box = (k * x, k * y, k * (x + w), k * (y + h))
        box = tuple(max(0, v) for v in box)
        px = sorted(L(p) for p in img.crop(box).getdata())
        if not px: continue
        bg, fg = px[len(px) // 2], px[int(len(px) * 0.97)]
        lo = px[int(len(px) * 0.03)]
        r = max((fg + 0.05) / (bg + 0.05), (bg + 0.05) / (lo + 0.05))
        out.append([row[0], row[2], row[5], row[6], f"{r:.2f}"])
with open(os.path.join(d, "contrast-measured.tsv"), "w") as o:
    o.write("screen\tlabel\tframe\taudit\tmeasured\n")
    for r in out: o.write("\t".join(r) + "\n")
under = [r for r in out if float(r[4]) < 4.5]
print(f"{len(out)} flagged; measured under 4.5:1 in the screenshot: {len(under)}; under 3:1: {sum(float(r[4]) < 3 for r in out)}")
