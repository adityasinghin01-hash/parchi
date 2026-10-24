#!/usr/bin/env python3
"""Score how close an app screenshot is to the HTML render.   compare.py <web.png> <app.png> [out_prefix] [--min 0.90]
Compares the content area (status bar and home-indicator strips are ignored), grayscale SSIM (7x7 box window) overall and in 8 bands
top to bottom, plus the share of pixels that differ strongly. Writes <out_prefix>_sbs.png = web | app | diff. Exit code 1 if SSIM < --min."""
import sys
import numpy as np
from PIL import Image

args = [a for a in sys.argv[1:] if not a.startswith("--")]
minimum = float(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 0.0
if "--min" in sys.argv:
    args.remove(sys.argv[sys.argv.index("--min") + 1])
web, app = Image.open(args[0]).convert("RGB"), Image.open(args[1]).convert("RGB")
prefix = args[2] if len(args) > 2 else None
if app.size != web.size:
    app = app.resize(web.size, Image.LANCZOS)
W, H = web.size
top, bottom = int(54 * W / 390), int(H - 34 * W / 390)          # ignore the status bar and the home-indicator strip

def gray(im): return np.asarray(im.convert("L"), dtype=np.float64)[top:bottom]
def box(x, k):
    c = np.cumsum(np.cumsum(np.pad(x, ((1, 0), (1, 0))), 0), 1)
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)
def ssim(a, b, k=7):
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    ma, mb = box(a, k), box(b, k)
    va, vb, cov = box(a * a, k) - ma * ma, box(b * b, k) - mb * mb, box(a * b, k) - ma * mb
    return ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))

a, b = gray(web), gray(app)
s = ssim(a, b)
overall = float(s.mean())
bands = [float(x.mean()) for x in np.array_split(s, 8, axis=0)]
strong = float((np.abs(a - b) > 48).mean())
print(f"SSIM {overall:.3f}   strong-diff pixels {strong * 100:.1f}%   bands (top->bottom): " + " ".join(f"{x:.2f}" for x in bands))
if prefix:
    diff = np.abs(np.asarray(web.convert("L"), dtype=np.int16) - np.asarray(app.convert("L"), dtype=np.int16)).clip(0, 255).astype(np.uint8)
    d = Image.merge("RGB", (Image.fromarray(255 - diff // 2 * 0 - 0 + 0 * diff).point(lambda v: 255), Image.fromarray(255 - diff), Image.fromarray(255 - diff)))
    parts = [im.resize((W // 2, H // 2), Image.LANCZOS) for im in (web, app, d)]
    sbs = Image.new("RGB", (3 * (W // 2) + 20, H // 2), (255, 255, 255))
    for i, p in enumerate(parts):
        sbs.paste(p, (i * (W // 2 + 10), 0))
    sbs.save(prefix + "_sbs.png")
sys.exit(1 if overall < minimum else 0)
