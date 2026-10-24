#!/usr/bin/env python3
"""Cuts the illustration crops the HTML uses (reference JPEG + viewBox rectangle) into PNG assets in the app's asset catalogue
(app/Parchi/Assets.xcassets/WebArt/<asset>.imageset) and writes the asset name into each `art` entry of frontend/specs/web/<route>.json
(field "asset"). Run from the repo root after web_render.mjs:  /usr/bin/python3 tools/fidelity/make_art_assets.py
Swift side:  Image("art_home_465_391_337_277").resizable().scaledToFit().frame(width: wu*u, height: hu*u)   (wu/hu from the spec)."""
import glob, json, os
from PIL import Image

ROOT = os.getcwd()
SPECS = os.path.join(ROOT, "frontend/specs/web")
CAT = os.path.join(ROOT, "app/Parchi/Assets.xcassets/WebArt")
os.makedirs(CAT, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(CAT, "Contents.json"), "w"))
made = {}
for path in sorted(glob.glob(os.path.join(SPECS, "*.json"))):
    if path.endswith("art_manifest.json"):
        continue
    spec = json.load(open(path))
    for art in spec.get("art", []):
        href = art["href"]
        ref = os.path.join(ROOT, "frontend", href) if not os.path.isabs(href) else href
        x, y, w, h = [round(float(v)) for v in art["viewBox"].split()]
        base = os.path.splitext(os.path.basename(href))[0].replace("-", "")
        name = f"art_{base}_{x}_{y}_{w}_{h}"
        art["asset"] = name
        if name not in made:
            im = Image.open(ref).convert("RGB")
            x0, y0 = max(0, x), max(0, y)
            crop = im.crop((x0, y0, min(im.width, x + w), min(im.height, y + h)))
            d = os.path.join(CAT, name + ".imageset")
            os.makedirs(d, exist_ok=True)
            crop.save(os.path.join(d, name + ".png"))
            json.dump({"images": [{"filename": name + ".png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
                      open(os.path.join(d, "Contents.json"), "w"))
            made[name] = {"source": href, "crop": [x, y, w, h], "size": list(crop.size)}
    json.dump(spec, open(path, "w"), indent=1)
json.dump(made, open(os.path.join(SPECS, "art_manifest.json"), "w"), indent=1)
print(len(made), "art assets written to", os.path.relpath(CAT, ROOT))
