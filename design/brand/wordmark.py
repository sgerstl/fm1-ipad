"""Lupe's wordmark: "lupe" in Michroma (OFL, design/brand/fonts) with the e's crossbar tilted up to the right (Scott,
2026-11-08: Michroma, keeping the tilted e). Writes white-on-transparent PNGs for the launch intro.

  python3 wordmark.py TILT_DEGREES OUT.png
"""
import math, sys
from PIL import Image, ImageDraw, ImageFont

FONT = __file__.rsplit("/", 1)[0] + "/fonts/Michroma-Regular.ttf"
SIZE = 400                                   # measured at this size: the e's box, stroke and bar below are for it

def wordmark(tilt, scale=3):
    f = ImageFont.truetype(FONT, SIZE * scale)
    im = Image.new("L", (2200 * scale, 700 * scale), 0)
    d = ImageDraw.Draw(im)
    d.text((50 * scale, 0), "lupe", font=f, fill=255)
    ex = d.textlength("lup", font=f) + 50 * scale       # where the e starts
    k = scale
    # Michroma's e at 400 px (from its draw origin): box x 18..283, y 233..468; stroke 31; bar y 331..361
    left, right = ex + (18 + 31) * k, ex + 283 * k
    top, bot = 331 * k, 362 * k
    d.rectangle([left, top - 1 * k, right, bot], fill=0)  # the level bar out
    # the tilted bar: from the inner left stroke, its lower edge on the old bar's, rising to the right edge
    rise = math.tan(math.radians(tilt)) * (right - left)
    t = 30 * k / math.cos(math.radians(tilt))              # the same stroke, measured upright
    # the right stroke below the bar's raised end goes, so the bowl closes onto the bar
    d.rectangle([right - 31 * k, bot - rise - 1 * k, right + 4 * k, bot], fill=0)
    d.polygon([(left - 2 * k, bot), (right, bot - rise), (right, bot - rise - t), (left - 2 * k, bot - t)], fill=255)
    box = im.getbbox()
    out = Image.new("RGBA", im.size, (255, 255, 255, 0))
    out.putalpha(im)
    return out.crop(box)

if __name__ == "__main__":
    wordmark(float(sys.argv[1])).save(sys.argv[2])
