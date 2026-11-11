#!/usr/bin/env python3
"""Contrast of Lupe's theme tokens (ios/FM1/Theme.swift, SloopKit DeviceShape colours), WCAG 2.x relative luminance.
Run: python3 qa/accessibility-2026-11-10/contrast.py  (prints a Markdown table). Alpha colours are composited onto
their background first. 2026-11-10."""

def lum(c):
    r, g, b = [(c >> s & 0xFF) / 255 for s in (16, 8, 0)]
    f = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)

def over(fg, alpha, bg):
    ch = lambda s: round((fg >> s & 0xFF) * alpha + (bg >> s & 0xFF) * (1 - alpha)) << s
    return ch(16) | ch(8) | ch(0)

T = dict(page=0x0D0D0F, well=0x111114, stepEmpty=0x2A2A30, stepOutside=0x18181C, ledOff=0x45454D, panel=0x1A1A1E,
         control=0x26262B, primaryEdge=0x8A8A92, disabledOutline=0x4A4A52, laneEdge=0x7C7C85,
         tone2=0x34343B, tone3=0x3E3E46, tone4=0x48484F,
         text=0xEDEDF0, textSecondary=0xA1A1AA, textSecondaryRaised=0xC4C4CC, textTertiary=0x71717A,
         onColour=0x101012, rec=0xFF2C34, recText=0xFF8A8D, caution=0xFFB54A)
SKIFF = dict(t1=0xFF5A36, t2=0x22C3B4, t3=0xFFBF00, t4=0x9580FF, t5=0xFF6FAE, t6=0xA3E635)
SLOOP = dict(s1=0x287CFF, s2=0x1ECC70, s3=0xFFC618, s4=0xFF621A)

rows = []
def check(what, fg, bg, need, note=""):
    r = ratio(fg, bg)
    rows.append((what, f"#{fg:06X}", f"#{bg:06X}", f"{r:.2f}", str(need), "pass" if r >= need else "**FAIL**", note))

# text
for bgn in ("page", "panel", "control", "tone2", "tone3"):
    for fgn, need in (("text", 4.5), ("textSecondary", 4.5), ("textSecondaryRaised", 4.5), ("textTertiary", 4.5)):
        check(f"{fgn} on {bgn}", T[fgn], T[bgn], need, "text")
# track colours as text or icons on the page and panels, and text on them
for pal, cols in (("Skiff", SKIFF), ("SLOOP", SLOOP)):
    for n, c in cols.items():
        check(f"{pal} {n} as text on page", c, T["page"], 4.5, "track name / number as text")
        check(f"{pal} {n} as text on panel", c, T["panel"], 4.5, "")
        check(f"onColour text on {pal} {n} fill", T["onColour"], c, 4.5, "pad number on a playing pad")
        check(f"text (white) on {pal} {n} fill", T["text"], c, 4.5, "")
        check(f"onColour@0.6 on {pal} {n} (pad thumb)", over(T["onColour"], 0.6, c), c, 3.0, "graphic, 3:1")
        check(f"{pal} {n} fill vs page (pad boundary)", c, T["page"], 3.0, "UI boundary")
        # the lane tint: a track colour at low alpha over the page (see PadsPage lanes)
        for a in (0.12, 0.18):
            tint = over(c, a, T["page"])
            check(f"text on {pal} {n} tint@{a}", T["text"], tint, 4.5, "row head text on the lane tint")
            check(f"textSecondary on {pal} {n} tint@{a}", T["textSecondary"], tint, 4.5, "")
            check(f"stepEmpty outline on {pal} {n} tint@{a}", T["stepEmpty"], tint, 3.0, "empty pad well edge")
            check(f"laneEdge on {pal} {n} tint@{a}", T["laneEdge"], tint, 3.0, "")
# UI boundaries
for fgn in ("stepEmpty", "ledOff", "disabledOutline", "laneEdge", "primaryEdge", "control", "tone2", "tone3", "tone4"):
    for bgn in ("page", "well", "panel"):
        check(f"{fgn} edge vs {bgn}", T[fgn], T[bgn], 3.0, "UI boundary / graphic")
# outline at alpha (the dashed waiting outline is text@0.8; the playing outline on a muted row is colour@0.3)
check("waiting outline text@0.8 on page", over(T["text"], 0.8, T["page"]), T["page"], 3.0, "")
for pal, cols in (("Skiff", SKIFF), ("SLOOP", SLOOP)):
    for n, c in cols.items():
        check(f"{pal} {n}@0.3 outline on page", over(c, 0.3, T["page"]), T["page"], 3.0, "muted playing pad outline")
check("song's next outline text@0.55 on page", over(T["text"], 0.55, T["page"]), T["page"], 3.0, "pad 'next' outline")
check("song's next outline text@0.55 on control", over(T["text"], 0.55, T["control"]), T["control"], 3.0, "pad 'next' outline on a filled pad")
check("selected-lane pad edge laneEdge on page", T["laneEdge"], T["page"], 3.0, "")
check("filled pad (control) vs page", T["control"], T["page"], 3.0, "filled pad face; identified by its number too")
for n in ("rec", "recText", "caution"):
    check(f"{n} on page", T[n], T["page"], 4.5, "")

print("| Pair | Fore | Back | Ratio | Needs | Result | Use |\n|---|---|---|---|---|---|---|")
for r in rows:
    print("| " + " | ".join(r) + " |")
