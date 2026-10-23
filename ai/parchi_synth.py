"""Parchi synthetic Indian prescription generator (v1, 23 Oct 2026).

Makes photo-like Indian OPD prescriptions with automatic labels:
real brand names from the Indian medicine catalogue, Indian layouts (letterhead in
regional scripts, Rx, Tab/Cap/Syp, 1-0-1, x 5 days, Adv: tests), handwriting fonts
with per-doctor messiness, trailing scrawl, phone-photo and WhatsApp effects.

Each synthetic doctor keeps one handwriting style and a personal brand list
(WHO "P-drugs"), so doctor-memory experiments are possible.

Usage:
  python -I parchi_synth.py fetch --assets ASSET_DIR
  python -I parchi_synth.py gen --assets ASSET_DIR --catalogue indian_medicine_data.csv \
      --out OUT_DIR --n 200 [--seed 1] [--doctors 400] [--workers 4]

Output: OUT_DIR/images/*.jpg and OUT_DIR/labels.jsonl (one JSON per image).
Never trained on MIRAGE-100 or the web test set; those stay test-only.
"""
import argparse, csv, json, math, os, random, re, sys, urllib.parse, urllib.request
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, features

GF = "https://raw.githubusercontent.com/google/fonts/main/"
HAND_LATIN = [
    "ofl/caveat/Caveat[wght].ttf", "apache/homemadeapple/HomemadeApple-Regular.ttf",
    "ofl/reeniebeanie/ReenieBeanie.ttf", "ofl/nothingyoucoulddo/NothingYouCouldDo.ttf",
    "ofl/zeyada/Zeyada.ttf", "ofl/cedarvillecursive/Cedarville-Cursive.ttf",
    "ofl/labelleaurore/LaBelleAurore.ttf", "ofl/dawningofanewday/DawningofaNewDay.ttf",
    "ofl/kalam/Kalam-Regular.ttf", "ofl/kalam/Kalam-Light.ttf", "ofl/indieflower/IndieFlower-Regular.ttf",
    "ofl/shadowsintolight/ShadowsIntoLight.ttf", "apache/rocksalt/RockSalt-Regular.ttf",
    "ofl/mrssaintdelafield/MrsSaintDelafield-Regular.ttf", "ofl/waitingforthesunrise/WaitingfortheSunrise.ttf",
    "ofl/justmeagaindownhere/JustMeAgainDownHere.ttf", "ofl/overtherainbow/OvertheRainbow.ttf",
    "ofl/gochihand/GochiHand-Regular.ttf", "apache/yellowtail/Yellowtail-Regular.ttf",
    "ofl/sueellenfrancisco/SueEllenFrancisco-Regular.ttf", "ofl/coveredbyyourgrace/CoveredByYourGrace.ttf",
    "ofl/gloriahallelujah/GloriaHallelujah.ttf", "ofl/architectsdaughter/ArchitectsDaughter-Regular.ttf",
    "ofl/patrickhand/PatrickHand-Regular.ttf", "ofl/marckscript/MarckScript-Regular.ttf",
    "ofl/kristi/Kristi-Regular.ttf", "ofl/meddon/Meddon.ttf", "ofl/qwigley/Qwigley-Regular.ttf",
    "ofl/herrvonmuellerhoff/HerrVonMuellerhoff-Regular.ttf", "ofl/allison/Allison-Regular.ttf",
]
HAND_DEVA = ["ofl/kalam/Kalam-Regular.ttf", "ofl/amita/Amita-Regular.ttf"]
PRINT_REGULAR = ["ofl/notosans/NotoSans[wdth,wght].ttf", "ofl/notoserif/NotoSerif[wdth,wght].ttf",
                 "ofl/hind/Hind-Medium.ttf", "ofl/mukta/Mukta-Bold.ttf"]
PRINT_BOLD = ["ofl/hind/Hind-Bold.ttf", "ofl/mukta/Mukta-ExtraBold.ttf"]
PRINT_SCRIPT = {
    "hi": "ofl/notosansdevanagari/NotoSansDevanagari[wdth,wght].ttf",
    "te": "ofl/notosanstelugu/NotoSansTelugu[wdth,wght].ttf",
    "bn": "ofl/notosansbengali/NotoSansBengali[wdth,wght].ttf",
    "ml": "ofl/notosansmalayalam/NotoSansMalayalam[wdth,wght].ttf",
    "ta": "ofl/notosanstamil/NotoSansTamil[wdth,wght].ttf",
}
ALL_FONTS = sorted(set(HAND_LATIN + HAND_DEVA + PRINT_REGULAR + PRINT_BOLD + list(PRINT_SCRIPT.values())))

REGIONAL = {
    "hi": ["क्लिनिक", "समय: सुबह 10 से दोपहर 2 बजे", "रविवार अवकाश", "शाम 5 से 8 बजे"],
    "te": ["క్లినిక్", "సమయం: ఉదయం 10 నుండి", "ఆదివారం సెలవు"],
    "bn": ["ক্লিনিক", "সময়: সকাল ১০টা", "রবিবার বন্ধ"],
    "ml": ["ക്ലിനിക്", "സമയം: രാവിലെ 10 മുതൽ", "ഞായറാഴ്ച അവധി"],
    "ta": ["கிளினிக்", "நேரம்: காலை 10 முதல்", "ஞாயிறு விடுமுறை"],
}
HINDI_HAND = ["खाने के बाद", "खाने से पहले", "सुबह-शाम", "रात को", "दिन में दो बार"]

FIRST_M = "Rahul Amit Suresh Ramesh Vikas Rajesh Sanjay Anil Manoj Deepak Arjun Rohit Karan Mohit Ajay Vijay Ravi Sunil Pankaj Nitin Gaurav Harish Mukesh Dinesh Ashok Prakash Abdul Imran Salim Joseph Thomas Srinivas Venkat Krishna Murali Gopal Sandeep Yogesh Lokesh Naveen".split()
FIRST_F = "Priya Neha Pooja Anita Sunita Kavita Rekha Meena Asha Geeta Nisha Shalini Ritu Sneha Divya Anjali Swati Komal Preeti Sarita Fatima Ayesha Mary Lakshmi Radha Savitri Usha Kiran Jyoti Seema".split()
SURNAMES = "Sharma Verma Gupta Singh Kumar Yadav Agarwal Jain Mishra Pandey Tiwari Chauhan Rawat Tyagi Saxena Srivastava Khan Ansari Qureshi Reddy Rao Naidu Nair Menon Pillai Iyer Das Ghosh Banerjee Mukherjee Patel Shah Joshi Kulkarni Deshmukh Gill Sandhu Bhatt Thakur Rathore".split()
CITIES = ["Ghaziabad", "Meerut", "Noida", "Delhi", "Lucknow", "Kanpur", "Agra", "Hapur", "Muzaffarnagar", "Patna",
          "Jaipur", "Hyderabad", "Vijayawada", "Kochi", "Chennai", "Kolkata", "Pune", "Indore", "Bhopal", "Dehradun"]
REG_PREFIX = ["UPMC", "DMC", "BMC", "RMC", "TSMC", "APMC", "TCMC", "TNMC", "WBMC", "MMC", "MPMC", "UKMC"]
QUALS = ["MBBS", "MBBS, MD (Medicine)", "MBBS, MS (Surgery)", "MBBS, DCH", "MBBS, MD (Paed)", "MBBS, DGO",
         "MBBS, MD, DM (Cardio)", "MBBS, DNB (Medicine)", "MBBS, MD (Derma)", "MBBS, MS (ENT)", "MBBS, MD (Chest)"]
SPECIALTY = ["General Physician", "Consultant Physician", "Child Specialist", "Gynaecologist", "Cardiologist",
             "Diabetologist", "Skin Specialist", "ENT Specialist", "Chest Physician", "Family Physician"]
COMPLAINTS = ["Fever x 3 days", "Cough & cold", "Body ache", "Headache", "Acidity", "Loose motions x 2 d",
              "Pain abdomen", "Sore throat", "Burning micturition", "Giddiness", "Joint pain", "Breathlessness",
              "Itching", "Weakness", "Vomiting", "Chest pain on exertion", "Back pain"]
DIAGNOSES = ["URTI", "AGE", "HTN", "T2DM", "APD", "UTI", "Viral fever", "LRTI", "Allergic rhinitis", "OA knee",
             "Dyslipidemia", "Hypothyroidism", "Asthma", "Migraine", "Anaemia"]
TESTS = [("CBC", ["CBC", "CBC", "Hb, TLC, DLC"]), ("ESR", ["ESR"]), ("CRP", ["CRP"]),
         ("FBS", ["FBS", "BSF"]), ("PPBS", ["PPBS", "BSPP"]), ("RBS", ["RBS"]), ("HbA1c", ["HbA1c", "HBA1C"]),
         ("LFT", ["LFT"]), ("KFT", ["KFT", "RFT"]), ("Serum Creatinine", ["S. Creatinine", "S.Cr"]),
         ("Lipid Profile", ["Lipid profile", "Lipid Profile", "LP"]), ("TSH", ["TSH"]),
         ("Thyroid Profile (T3 T4 TSH)", ["T3 T4 TSH", "TFT"]), ("Vitamin D", ["Vit D3", "25-OH Vit D"]),
         ("Vitamin B12", ["Vit B12", "B12"]), ("Urine Routine", ["Urine R/M", "Urine RE"]),
         ("Urine Culture", ["Urine C/S"]), ("Widal", ["Widal", "Typhidot"]), ("Dengue NS1", ["Dengue NS1", "NS1 Ag"]),
         ("Malaria Antigen", ["MP", "Malaria Ag"]), ("Chest X-ray", ["X-ray chest PA", "CXR PA"]),
         ("USG Abdomen", ["USG abdomen", "USG W/A"]), ("ECG", ["ECG"]), ("Serum Uric Acid", ["S. Uric acid"]),
         ("Serum Electrolytes", ["S. Electrolytes", "Na/K"])]

FORM_WORDS = {"Tablet": "Tab", "Capsule": "Cap", "Syrup": "Syp", "Injection": "Inj", "Suspension": "Syp",
              "Cream": "Cream", "Ointment": "Oint", "Gel": "Gel", "Drop": "Drops", "Drops": "Drops",
              "Lotion": "Lotion", "Solution": "Sol", "Expectorant": "Syp", "Inhaler": "Inhaler",
              "Powder": "Powder", "Sachet": "Sachet", "Granules": "Gran", "Liquid": "Syp",
              "Rotacap": "Rotacap", "Rotacaps": "Rotacap", "Respules": "Respules", "Spray": "Spray"}
FORM_ABBR = {"Tab": ["Tab", "Tab.", "T.", "tab", "TAB"], "Cap": ["Cap", "Cap.", "C.", "cap", "CAP"],
             "Syp": ["Syp", "Syp.", "Syr", "Syrup"], "Inj": ["Inj", "Inj."], "Drops": ["Drops", "E/D", "Gtt"],
             "Oint": ["Oint", "Oint."], "Cream": ["Cream", "Oint"], "Gel": ["Gel"], "Lotion": ["Lotion"],
             "Sol": ["Sol", "Sol."], "Inhaler": ["Inh", "MDI", "Inhaler"], "Powder": ["Powder", "Pwd"],
             "Sachet": ["Sachet", "Sach"], "Gran": ["Gran"], "Rotacap": ["Rotacap"], "Respules": ["Respules", "Neb"],
             "Spray": ["Spray", "Nasal spray"]}
FORM_QUALIFIERS = {"Dry", "Oral", "Eye", "Ear", "Nasal", "Eye/Ear"}
DOSES_ORAL = ["1-0-1", "1-0-1", "1-1-1", "1-0-0", "0-0-1", "1-0-0", "½-0-½", "OD", "BD", "TDS", "HS", "SOS", "1 OD", "1 BD"]
DOSES_SYRUP = ["5 ml TDS", "10 ml BD", "2 tsf TDS", "5ml SOS", "1 tsf BD"]
DOSE_BY_FORM = {"Syp": DOSES_SYRUP, "Cream": ["L/A BD", "L/A HS", "apply BD"], "Oint": ["L/A BD", "L/A HS"],
                "Gel": ["L/A TDS", "apply BD"], "Lotion": ["L/A BD", "apply HS"], "Drops": ["2 drops TDS", "1 drop QID", "2 drops BD"],
                "Inhaler": ["2 puffs BD", "2 puffs SOS"], "Rotacap": ["1 BD", "1 OD"], "Respules": ["Neb BD", "Neb TDS"],
                "Inj": ["stat", "IM stat", "IV OD x 3d", "1 amp IM"], "Spray": ["2 sprays BD", "1 spray OD"],
                "Sachet": ["1 OD", "1 in water OD"], "Powder": ["1 tsf OD", "1 scoop BD"], "Sol": ["10 ml TDS", "gargle TDS"],
                "Gran": ["1 sachet OD"]}
TIMINGS = ["", "", "AF", "BF", "after food", "before food", "p.c.", "a.c.", "empty stomach"]
DURATIONS = [("5 days", ["x 5 days", "x 5d", "x5 days", "— 5 days"]), ("3 days", ["x 3 days", "x 3d"]),
             ("7 days", ["x 7 days", "x 1 wk", "x 7d"]), ("10 days", ["x 10 days", "x 10d"]),
             ("15 days", ["x 15 days", "x 15d"]), ("1 month", ["x 1 month", "x 30 days", "x 1 mth"]),
             ("", [""])]


def fetch(assets):
    for p in ALL_FONTS:
        dst = os.path.join(assets, "fonts", os.path.basename(p))
        if os.path.exists(dst) and os.path.getsize(dst) > 1000:
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        url = GF + urllib.parse.quote(p)
        with urllib.request.urlopen(url, timeout=60) as r, open(dst, "wb") as f:
            f.write(r.read())
        print("fetched", p)


def fpath(assets, p):
    return os.path.join(assets, "fonts", os.path.basename(p))


# ---------------------------------------------------------------- catalogue
def load_catalogue(path):
    """Active allopathy products -> list of dicts with written name, form, strength, salts."""
    prods, salt_count = [], {}
    for r in csv.DictReader(open(path, encoding="utf8")):
        if r["Is_discontinued"].strip().upper() != "FALSE" or r["type"].strip() != "allopathy":
            continue
        words = r["name"].split()
        fi = next((i for i, w in enumerate(words) if w.capitalize() in FORM_WORDS), None)
        if fi is None or fi == 0:
            continue
        brand_words = words[:fi]
        while brand_words and brand_words[-1] in FORM_QUALIFIERS:
            brand_words = brand_words[:-1]
        if not brand_words or not re.match(r"[A-Za-z]", brand_words[0]) or len(brand_words[0]) < 3:
            continue
        mods = [w for w in words[fi + 1:] if w in {"SR", "DT", "ER", "MD", "PR", "CR", "XL", "MR", "XR", "DR"}]
        written = " ".join(brand_words + mods)
        salts = (r["short_composition1"].strip() + (" + " + r["short_composition2"].strip() if r["short_composition2"].strip() else ""))
        key = re.sub(r"\s*\(.*?\)", "", salts).lower()
        salt_count[key] = salt_count.get(key, 0) + 1
        strength = (re.findall(r"\d+(?:\.\d+)?", written) or [""])[0]
        prods.append({"written": written, "catalogue_name": r["name"], "form": FORM_WORDS[words[fi].capitalize()],
                      "strength": strength, "salts": salts, "salt_key": key})
    by_salt = {}
    for p in prods:
        by_salt.setdefault(p["salt_key"], []).append(p)
    keys = sorted(by_salt)
    # popularity proxy: salts with many brands are widely prescribed; sqrt keeps the long tail alive
    weights = [math.sqrt(salt_count[k]) for k in keys]
    return prods, by_salt, keys, weights


# ---------------------------------------------------------------- doctors
def make_doctor(i, seed, cat):
    rng = random.Random(seed * 7919 + i)
    _, by_salt, keys, weights = cat
    pdrugs = []
    for k in rng.choices(keys, weights=weights, k=rng.randint(20, 40)):
        pdrugs.append(rng.choice(by_salt[k]))
    messiness = rng.choices([0, 1, 2, 3], weights=[1, 2, 4, 4])[0]
    return {
        "id": f"d{i:04d}",
        "name": f"Dr. {rng.choice(FIRST_M + FIRST_F)} {rng.choice(SURNAMES)}",
        "quals": rng.choice(QUALS), "specialty": rng.choice(SPECIALTY),
        "reg": f"Reg. No. {rng.choice(REG_PREFIX)} {rng.randint(1000, 99999)}",
        "clinic": rng.choice(["", "City", "Shree", "Life Care", "Sai", "Jeevan", "New", "Arogya", "Family"]) + " " +
                  rng.choice(["Clinic", "Hospital", "Nursing Home", "Polyclinic", "Health Centre", "Medical Centre"]),
        "city": rng.choice(CITIES), "phone": f"{rng.randint(6, 9)}{rng.randint(100000000, 999999999)}",
        "lang": rng.choices(["en", "hi", "te", "bn", "ml", "ta"], weights=[45, 30, 7, 6, 6, 6])[0],
        "color": rng.choice([(20, 60, 140), (0, 100, 70), (150, 20, 30), (90, 20, 90), (30, 30, 30), (0, 90, 130)]),
        "font": rng.choice(HAND_LATIN), "size": rng.randint(34, 54), "messiness": messiness,
        "slant": rng.uniform(-0.05, 0.45), "case": rng.choices(["title", "upper", "lower"], weights=[6, 1, 3])[0],
        "ink": rng.choice([(25, 35, 120), (20, 30, 90), (30, 30, 35), (15, 15, 20), (40, 60, 150)]),
        "printed": rng.random() < 0.15, "hindi_notes": rng.random() < 0.25,
        "letterhead": rng.random() < 0.7, "pdrugs": pdrugs,
    }


# ---------------------------------------------------------------- handwriting
def elastic(mask, amp, rng):
    if amp <= 0:
        return mask
    w, h = mask.size
    gx, gy = max(2, w // 60), max(2, h // 25)
    nrng = np.random.default_rng(rng.randint(0, 2**31))
    dx = Image.fromarray((nrng.standard_normal((gy, gx)) * amp).astype(np.float32), "F").resize((w, h), Image.BICUBIC)
    dy = Image.fromarray((nrng.standard_normal((gy, gx)) * amp).astype(np.float32), "F").resize((w, h), Image.BICUBIC)
    a = np.asarray(mask)
    Y, X = np.mgrid[0:h, 0:w]
    xs = np.clip((X + np.asarray(dx)).round().astype(int), 0, w - 1)
    ys = np.clip((Y + np.asarray(dy)).round().astype(int), 0, h - 1)
    return Image.fromarray(a[ys, xs])


def hand_mask(text, font_path, size, m, slant, rng, scrawl_from=None):
    """Grey mask of handwritten text. m = messiness 0..3. scrawl_from = char index where the pen trails off."""
    font = ImageFont.truetype(font_path, size)
    ascii_only = all(ord(c) < 128 or c in "½—" for c in text)
    W = int(font.getlength(text) * 1.4 + size * 4)
    H = int(size * 2.6)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    base = int(size * 0.9)
    x = size * 0.5
    if not ascii_only:
        d.text((x, base), text, font=font, fill=255, anchor="ls")
        x += font.getlength(text)
    else:
        upto = len(text) if scrawl_from is None else scrawl_from
        for c in text[:upto]:
            if c == " ":
                x += font.getlength(" ") * rng.uniform(0.7, 1.3)
                continue
            sc = 1 + rng.uniform(-0.06, 0.06) * (1 + m)
            f = ImageFont.truetype(font_path, max(8, int(size * sc))) if abs(sc - 1) > 0.02 else font
            dy = rng.uniform(-0.03, 0.03) * size * (1 + m)
            d.text((x, base + dy), c, font=f, fill=255, anchor="ls")
            x += f.getlength(c) * rng.uniform(0.86 - 0.04 * m, 1.02)
        if scrawl_from is not None and scrawl_from < len(text):
            rest = font.getlength(text[scrawl_from:]) * rng.uniform(0.5, 0.9)
            n = max(2, len(text) - scrawl_from)
            amp = size * rng.uniform(0.12, 0.3)
            pts = [(x + rest * t / 40, base - amp * 0.6 - amp * math.sin(t / 40 * n * math.pi * rng.uniform(0.8, 1.2)) * 0.5)
                   for t in range(41)]
            d.line(pts, fill=255, width=max(2, size // 14), joint="curve")
            x += rest
    mask = mask.crop((0, 0, int(min(W, x + size * 0.6)), H))
    if slant:
        w, h = mask.size
        k = slant
        mask = mask.transform((int(w + abs(k) * h), h), Image.AFFINE,
                              (1, k, -k * h if k > 0 else 0, 0, 1, 0), resample=Image.BILINEAR)
    mask = elastic(mask, [0, 0.8, 1.6, 2.6][m], rng)
    if rng.random() < 0.35 + 0.1 * m:
        mask = mask.filter(ImageFilter.MaxFilter(3))
    mask = mask.rotate(rng.uniform(-1.5, 1.5) * (1 + m), resample=Image.BILINEAR, expand=True)
    return mask


def put_ink(page, mask, xy, ink, rng):
    nrng = np.random.default_rng(rng.randint(0, 2**31))
    a = np.asarray(mask).astype(np.float32) * rng.uniform(0.75, 1.0)
    a *= nrng.uniform(0.82, 1.0, a.shape)
    m = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    col = Image.new("RGB", m.size, tuple(max(0, min(255, c + rng.randint(-10, 10))) for c in ink))
    page.paste(col, (int(xy[0]), int(xy[1])), m)
    bb = mask.getbbox() or (0, 0, 1, 1)
    return [int(xy[0] + bb[0]), int(xy[1] + bb[1]), int(xy[0] + bb[2]), int(xy[1] + bb[3])]


def styled(name, case):
    return name.upper() if case == "upper" else name.lower() if case == "lower" else name


# ---------------------------------------------------------------- page
def draw_printed(draw, xy, text, path, size, fill):
    f = ImageFont.truetype(path, size)
    draw.text(xy, text, font=f, fill=fill)
    return draw.textbbox(xy, text, font=f)


def make_page(doc, idx, seed, cat, assets):
    rng = random.Random(seed * 1_000_003 + idx)
    prods = cat[0]
    W = rng.randint(1100, 1300)
    H = int(W * rng.uniform(1.32, 1.5))
    paper = tuple(rng.randint(238, 255) - (k == 2) * rng.randint(0, 12) for k in range(3))
    page = Image.new("RGB", (W, H), paper)
    draw = ImageDraw.Draw(page)
    F = lambda p: fpath(assets, p)
    m, size, slant = doc["messiness"], doc["size"], doc["slant"]
    hand = F(doc["font"])
    printed_rx = doc["printed"]
    labels = {"medicines": [], "tests": [], "pii": []}
    y = int(H * 0.03)
    col = doc["color"]

    if doc["letterhead"]:
        bold = F(rng.choice(PRINT_BOLD))
        reg = F(rng.choice(PRINT_REGULAR))
        draw_printed(draw, (int(W * 0.05), y), doc["name"], bold, rng.randint(40, 56), col)
        y += 62
        draw_printed(draw, (int(W * 0.05), y), doc["quals"], reg, 26, col)
        draw_printed(draw, (int(W * 0.55), y), doc["specialty"], reg, 26, col)
        y += 36
        draw_printed(draw, (int(W * 0.05), y), doc["reg"], reg, 22, col)
        y += 32
        if doc["lang"] != "en" and features.check("raqm"):
            sp = F(PRINT_SCRIPT[doc["lang"]])
            for ph in rng.sample(REGIONAL[doc["lang"]], k=min(2, len(REGIONAL[doc["lang"]]))):
                draw_printed(draw, (int(W * 0.05), y), ph, sp, 28, col)
                y += 40
        clinic = f"{doc['clinic'].strip()}, {doc['city']} · Ph: {doc['phone'][:5]} {doc['phone'][5:]}"
        draw_printed(draw, (int(W * 0.05), y), clinic, reg, 22, col)
        y += 38
        draw.line([(int(W * 0.03), y), (int(W * 0.97), y)], fill=col, width=rng.randint(2, 5))
        y += 22

    # patient row: printed labels, handwritten values (these are the PII boxes the blur must catch)
    rowf = F(rng.choice(PRINT_REGULAR))
    first = rng.choice(FIRST_M + FIRST_F)
    pname = f"{first} {rng.choice(SURNAMES)}"
    age = f"{rng.randint(2, 85)} {rng.choice(['Y', 'yrs', 'Y/M', 'Y/F', ''])}".strip()
    date = rng.choice(["{d}/{mo}/26", "{d}-{mo}-2026", "{d}.{mo}.26"]).format(d=rng.randint(1, 28), mo=rng.randint(1, 12))
    hx = int(W * 0.05)
    if rng.random() < 0.85:
        b = draw_printed(draw, (hx, y + 8), "Name:", rowf, 26, col)
        labels["pii"].append({"type": "patient_name", "box": put_ink(page, hand_mask(styled(pname, doc["case"]), hand, size, min(m, 2), slant, rng), (b[2] + 10, y - size * 0.5), doc["ink"], rng)})
        b = draw_printed(draw, (int(W * 0.58), y + 8), "Age/Sex:", rowf, 26, col)
        labels["pii"].append({"type": "patient_age", "box": put_ink(page, hand_mask(age, hand, size, min(m, 2), slant, rng), (b[2] + 10, y - size * 0.5), doc["ink"], rng)})
        b = draw_printed(draw, (int(W * 0.80), y + 8), "Date:", rowf, 24, col)
        put_ink(page, hand_mask(date, hand, int(size * 0.85), min(m, 2), slant, rng), (b[2] + 6, y - size * 0.4), doc["ink"], rng)
    else:
        labels["pii"].append({"type": "patient_name", "box": put_ink(page, hand_mask(styled(pname, doc["case"]) + "  " + age, hand, size, m, slant, rng), (hx, y), doc["ink"], rng)})
    y += int(size * 1.9)
    if rng.random() < 0.2:
        ph = f"Mob {rng.randint(6, 9)}{rng.randint(100000000, 999999999)}"
        labels["pii"].append({"type": "patient_phone", "box": put_ink(page, hand_mask(ph, hand, int(size * 0.85), min(m, 2), slant, rng), (hx, y), doc["ink"], rng)})
        y += int(size * 1.5)

    # left column: complaints / diagnosis / vitals (noise the reader must ignore)
    if rng.random() < 0.55:
        ly = y
        notes = rng.sample(COMPLAINTS, rng.randint(1, 3))
        if rng.random() < 0.5:
            notes.append(f"BP {rng.randint(100, 170)}/{rng.randint(60, 100)}")
        notes.append("Dx: " + rng.choice(DIAGNOSES) if rng.random() < 0.6 else rng.choice(DIAGNOSES))
        for n in notes:
            put_ink(page, hand_mask(("c/o " if rng.random() < 0.2 else "") + n, hand, int(size * 0.8), m, slant, rng), (hx, ly), doc["ink"], rng)
            ly += int(size * 1.4)
        if rng.random() < 0.5:
            y = ly + int(size * 0.4)
        bx = int(W * rng.uniform(0.30, 0.42)) if y < ly else hx
    else:
        bx = hx

    # Rx symbol
    if rng.random() < 0.8:
        if rng.random() < 0.5:
            draw_printed(draw, (bx, y), "Rx", F(PRINT_BOLD[0]), rng.randint(44, 64), col)
        else:
            put_ink(page, hand_mask("Rx", hand, int(size * 1.3), m, slant, rng), (bx, y - 10), doc["ink"], rng)
        y += int(size * 1.7)

    # medicine lines
    n_med = rng.choices([1, 2, 3, 4, 5, 6, 7], weights=[4, 8, 10, 9, 6, 3, 2])[0]
    bullets = rng.choice(["num", "dash", "none", "num_paren"])
    printf = F(rng.choice(PRINT_REGULAR))
    for k in range(n_med):
        p = rng.choice(doc["pdrugs"]) if rng.random() < 0.8 else rng.choice(prods)
        abbr = rng.choice(FORM_ABBR.get(p["form"], [p["form"]]))
        dose = rng.choice(DOSE_BY_FORM.get(p["form"], DOSES_ORAL))
        timing = rng.choice(TIMINGS) if p["form"] in ("Tab", "Cap", "Syp") else ""
        dur_c, dur_w = rng.choice(DURATIONS)
        dur_w = rng.choice(dur_w)
        bullet = {"num": f"{k + 1}.", "num_paren": f"{k + 1})", "dash": "—", "none": ""}[bullets]
        brand = styled(p["written"], doc["case"])
        x = bx + rng.randint(-15, 30)
        scrawl = None
        if printed_rx:
            line = f"{bullet} {abbr} {p['written'].upper()}   {dose} {timing} {dur_w}".strip()
            box = list(draw_printed(draw, (x, y), line, printf, 30, (20, 20, 20)))
            y += 52
        else:
            box = None
            parts = [t for t in [bullet, abbr] if t]
            if parts:
                mk = hand_mask(" ".join(parts), hand, size, m, slant, rng)
                box = put_ink(page, mk, (x, y), doc["ink"], rng)
                x = box[2] + int(size * 0.3)
            if m >= 1 and rng.random() < 0.12 * m and len(brand) > 4:
                scrawl = max(2, int(len(brand) * rng.uniform(0.35, 0.7)))
            mk = hand_mask(brand, hand, int(size * rng.uniform(1.0, 1.15)), m, slant, rng, scrawl_from=scrawl)
            bb = put_ink(page, mk, (x, y - rng.randint(0, 8)), doc["ink"], rng)
            box = bb if box is None else [min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3])]
            x = bb[2] + int(size * rng.uniform(0.4, 1.2))
            tail = " ".join(t for t in [dose, timing, dur_w] if t)
            if doc["hindi_notes"] and rng.random() < 0.4 and features.check("raqm"):
                hn = rng.choice(HINDI_HAND)
                put_ink(page, hand_mask(hn, F(rng.choice(HAND_DEVA)), int(size * 0.8), min(m, 1), 0, rng), (x, y + size * 0.9), doc["ink"], rng)
            bottom = box[3]
            if x + len(tail) * size * 0.45 > W * 0.95 or rng.random() < 0.2:
                tb = put_ink(page, hand_mask(tail, hand, int(size * 0.85), m, slant, rng), (bx + int(W * 0.15), bottom - int(size * 0.3)), doc["ink"], rng)
            else:
                tb = put_ink(page, hand_mask(tail, hand, int(size * 0.85), m, slant, rng), (x, y + rng.randint(-6, 6)), doc["ink"], rng)
            y = max(bottom, tb[3]) + int(size * rng.uniform(0.3, 0.9))
        labels["medicines"].append({"name": p["written"], "catalogue_name": p["catalogue_name"], "form": p["form"],
                                    "strength": p["strength"], "salts": p["salts"], "dose": dose, "timing": timing,
                                    "duration": dur_c, "written_form": abbr, "scrawled": (not printed_rx) and scrawl is not None,
                                    "box": box})
        if y > H * 0.86:
            break

    # tests
    if rng.random() < 0.45 and y < H * 0.8:
        tests = rng.sample(TESTS, rng.randint(1, 4))
        written = [rng.choice(w) for _, w in tests]
        line = rng.choice(["Adv: ", "Adv - ", "Inv: ", "Investigations: ", "Get done: "]) + ", ".join(written)
        if printed_rx:
            draw_printed(draw, (bx, y), line, printf, 30, (20, 20, 20))
        else:
            put_ink(page, hand_mask(line, hand, int(size * 0.9), m, slant, rng), (bx, y), doc["ink"], rng)
        labels["tests"] = [{"name": c, "written": w} for (c, _), w in zip(tests, written)]
        y += int(size * 2)
    if rng.random() < 0.5 and y < H * 0.85:
        put_ink(page, hand_mask(rng.choice(["Review after 7 days", "SOS", "F/U 1 wk", "Review with reports", "Follow up after 15 days"]), hand, int(size * 0.85), m, slant, rng), (bx, y), doc["ink"], rng)

    # signature scribble
    sx, sy = int(W * rng.uniform(0.62, 0.78)), int(H * rng.uniform(0.82, 0.9))
    pts = [(sx + i * 6, sy + 18 * math.sin(i / rng.uniform(1.5, 3)) + rng.uniform(-6, 6)) for i in range(rng.randint(18, 40))]
    sig = Image.new("L", page.size, 0)
    ImageDraw.Draw(sig).line(pts, fill=255, width=3, joint="curve")
    page.paste(Image.new("RGB", page.size, doc["ink"]), (0, 0), sig)
    if doc["letterhead"] and rng.random() < 0.5:
        fy = int(H * 0.94)
        draw.line([(int(W * 0.03), fy - 10), (int(W * 0.97), fy - 10)], fill=col, width=2)
        draw_printed(draw, (int(W * 0.05), fy), rng.choice(["Not valid for medico-legal purposes", "Timings: 10 am - 2 pm, 5 pm - 8 pm", "Emergency: " + doc["phone"]]), F(PRINT_REGULAR[0]), 20, col)
    return page, labels, rng


# ---------------------------------------------------------------- photo effects
def homography(src, dst):
    A, b = [], []
    for (x, y), (u, v) in zip(src, dst):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
        A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
    return np.linalg.solve(np.array(A, float), np.array(b, float))


def apply_h(h, x, y):
    d = h[6] * x + h[7] * y + 1
    return (h[0] * x + h[1] * y + h[2]) / d, (h[3] * x + h[4] * y + h[5]) / d


def photo(page, rng):
    W, H = page.size
    mode = "scan" if rng.random() < 0.4 else "photo"
    if mode == "scan":
        pad = rng.randint(0, 40)
        OW, OH = W + 2 * pad, H + 2 * pad
        ang = math.radians(rng.uniform(-2, 2))
        cx, cy = OW / 2, OH / 2
        dst = []
        for x, y in [(0, 0), (W, 0), (W, H), (0, H)]:
            x, y = x + pad - cx, y + pad - cy
            dst.append((cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang)))
        bg = (rng.randint(200, 250),) * 3
    else:
        OW, OH = int(W * rng.uniform(1.05, 1.3)), int(H * rng.uniform(1.05, 1.25))
        mx, my = (OW - W) / 2, (OH - H) / 2
        j = lambda s: rng.uniform(-s, s)
        sx, sy = W * 0.07, H * 0.05
        dst = [(mx + j(sx), my + j(sy)), (mx + W + j(sx), my + j(sy)), (mx + W + j(sx), my + H + j(sy)), (mx + j(sx), my + H + j(sy))]
        bg = rng.choice([(110, 80, 50), (60, 60, 65), (180, 170, 150), (40, 50, 70), (140, 120, 100), (200, 200, 205)])
    src = [(0, 0), (W, 0), (W, H), (0, H)]
    inv = homography(dst, src)  # output -> input, what PIL wants
    fwd = homography(src, dst)
    warped = page.transform((OW, OH), Image.PERSPECTIVE, tuple(inv), resample=Image.BICUBIC)
    mask = Image.new("L", page.size, 255).transform((OW, OH), Image.PERSPECTIVE, tuple(inv), resample=Image.BILINEAR)
    nrng = np.random.default_rng(rng.randint(0, 2**31))
    bgarr = np.clip(np.array(bg, np.float32) + nrng.normal(0, 12, (OH, OW, 1)) + nrng.normal(0, 4, (OH, OW, 3)), 0, 255)
    out = Image.composite(warped, Image.fromarray(bgarr.astype(np.uint8)), mask)
    a = np.asarray(out).astype(np.float32)
    if mode == "photo":
        gx = np.linspace(0, 1, OW)[None, :, None]
        gy = np.linspace(0, 1, OH)[:, None, None]
        t = rng.uniform(0, 2 * math.pi)
        g = math.cos(t) * gx + math.sin(t) * gy
        g = (g - g.min()) / (g.max() - g.min() + 1e-6)
        a *= (1 - rng.uniform(0.1, 0.45) * g)
        if rng.random() < 0.4:  # soft shadow blob (hand or phone)
            cx, cy, r = rng.uniform(0, OW), rng.uniform(0, OH), rng.uniform(0.15, 0.4) * OW
            Y, X = np.mgrid[0:OH, 0:OW]
            a *= (1 - rng.uniform(0.15, 0.35) * np.exp(-((X - cx) ** 2 + (Y - cy) ** 2) / (2 * r * r)))[..., None]
        a *= np.array([rng.uniform(0.92, 1.05), rng.uniform(0.92, 1.03), rng.uniform(0.85, 1.02)])
    a = a * rng.uniform(0.85, 1.1) + rng.uniform(-15, 10)
    a += nrng.normal(0, rng.uniform(0, 6), a.shape)
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    r = rng.choice([0, 0, 0.5, 0.8, 1.2])
    if r:
        out = out.filter(ImageFilter.GaussianBlur(r))
    long_side = rng.choice([960, 1280, 1280, 1600, 1600, 2048])
    s = long_side / max(OW, OH)
    out = out.resize((int(OW * s), int(OH * s)), Image.LANCZOS)

    def tbox(b):
        pts = [apply_h(fwd, x, y) for x, y in [(b[0], b[1]), (b[2], b[1]), (b[2], b[3]), (b[0], b[3])]]
        xs, ys = [p[0] * s for p in pts], [p[1] * s for p in pts]
        return [int(min(xs)), int(min(ys)), int(max(xs)) + 1, int(max(ys)) + 1]
    return out, tbox, {"mode": mode, "long_side": long_side, "blur": r}


def target_json(labels):
    meds = [{"name": m["name"], "form": m["form"], "dose": m["dose"], "duration": m["duration"]} for m in labels["medicines"]]
    return json.dumps({"medicines": meds, "tests": [t["name"] for t in labels["tests"]]}, ensure_ascii=False)


def gen_one(args):
    idx, seed, out, assets, doctors = args
    rng0 = random.Random(seed * 31 + idx)
    doc = rng0.choice(DOCTORS)
    page, labels, rng = make_page(doc, idx, seed, CAT, assets)
    img, tbox, meta = photo(page, rng)
    for m in labels["medicines"]:
        if m["box"]:
            m["box"] = tbox(m["box"])
    for p in labels["pii"]:
        p["box"] = tbox(p["box"])
    q = rng.randint(35, 92)
    name = f"s{seed:02d}_{idx:06d}.jpg"
    img.save(os.path.join(out, "images", name), quality=q)
    rec = {"id": name[:-4], "image": "images/" + name, "doctor_id": doc["id"], "messiness": doc["messiness"],
           "printed": doc["printed"], "letterhead_lang": doc["lang"] if doc["letterhead"] else None,
           "jpeg_quality": q, **meta, "size": img.size, "medicines": labels["medicines"],
           "tests": labels["tests"], "pii": labels["pii"], "target": target_json(labels)}
    return json.dumps(rec, ensure_ascii=False)


CAT, DOCTORS = None, None


def init(cat_path, seed, n_doctors):
    global CAT, DOCTORS
    CAT = load_catalogue(cat_path)
    DOCTORS = [make_doctor(i, seed, CAT) for i in range(n_doctors)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "gen"])
    ap.add_argument("--assets", required=True)
    ap.add_argument("--catalogue")
    ap.add_argument("--out")
    ap.add_argument("--n", type=int, default=100)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--doctors", type=int, default=400)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(a.assets)
        return
    if not features.check("raqm"):
        print("warning: Pillow has no raqm; regional-script text will be skipped", file=sys.stderr)
    os.makedirs(os.path.join(a.out, "images"), exist_ok=True)
    jobs = [(i, a.seed, a.out, a.assets, a.doctors) for i in range(a.start, a.start + a.n)]
    with Pool(a.workers, initializer=init, initargs=(a.catalogue, a.seed, a.doctors)) as pool, \
            open(os.path.join(a.out, "labels.jsonl"), "a", encoding="utf8") as f:
        for k, line in enumerate(pool.imap(gen_one, jobs, chunksize=8)):
            f.write(line + "\n")
            if (k + 1) % 500 == 0:
                print(f"{k + 1}/{a.n}", flush=True)
    print("done", a.n)


if __name__ == "__main__":
    main()
