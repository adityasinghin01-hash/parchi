#!/usr/bin/env python3
"""Build the catalogue MRP bundle (plan gaps U6/U7) from the Medlex product list.

Usage: python3 tools/build_catalogue_prices.py [MEDLEX_CSV] [--ja-list JSON] [--out DIR]

Writes to engine/catalogue/ (bundle resources):
  brand_mrp.json                  MRP + pack + salt composition + dosage form per brand, strength and extra words
  janaushadhi_products.json       copy of the official Jan Aushadhi list (docs/research/evidence/..._2026-10-23.json)
  DATA_VERSION.json               gets the keys "janaushadhi_list_date" and "brand_mrp" (other keys are kept)

Rules: stdlib only; money is integer paise; never invent a value; output is deterministic (running twice gives
identical files). The brand key and the strength keys are computed EXACTLY like ParchiCore's `Catalogue`
(first word of the product name, letters only, upper case, at least 3 letters; every number that starts a later
word is a strength), so a brand/strength the app accepts on the Confirm screen has the same key here.

What is kept (this is how the file stays small, 12 MB -> under 6 MB):
  * only products that are not discontinued and are allopathy; descriptions, side effects, manufacturers and
    interactions of the 45 MB input are dropped;
  * only products whose name gives a brand key (>= 3 letters);
  * a product without a number in its name (strength "") is kept only for a brand that has no numbered product
    at all: for "Telma" with no strength read, the price of "Telma H" must never be shown;
  * per brand + strength + extra words + dosage form + release type ONE pack: the one with the lowest MRP per
    unit (per tablet / capsule / vial; a bottle or tube counts as 1 unit). Not the lowest price of the pack: a
    1-tablet strip would otherwise always win and a 10-tablet parchi would cost 10 strips. "Extra words" are the
    alphabetic words after the brand that are not a dosage form ("Telma H 40", "Montair LC"): "Telma 40" and
    "Telma H 40" are different medicines and never share a price;
  * each entry is a short list of integers; pack labels, salt compositions and extra words are stored once in
    side tables and referred to by index.
Salt composition ("Telmisartan (40mg)", "Amoxycillin (500mg) + Clavulanic Acid (125mg)") is kept only when it is
trustworthy: the full `salt_composition` column, or else short_composition1/2 when the data shows that list is
complete (the source marks a list that continues with a trailing space after the last salt) and every salt has a
numeric strength. A group of packs whose products disagree on the salt gets no salt at all.
"""
import csv
import json
import re
import shutil
import sys
from fractions import Fraction
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_MEDLEX = Path.home() / "dev/parchi-research/data/medlex/updated.csv"
DEFAULT_JA = REPO / "docs/research/evidence/janaushadhi_products_2026-10-23.json"
DEFAULT_OUT = REPO / "engine/catalogue"
JA_LIST_DATE = "2026-10-23"          # download date of the saved official list
FORMAT_VERSION = 1


class DataError(Exception):
    pass


# --- brand and strength keys: identical to ParchiCore Catalogue(productNames:) ---------------------------------

def brand_and_strengths(name):
    """("TELMA", {"40"}) for "Telma 40 Tablet"; (None, set()) when the name gives no usable brand."""
    parts = [p for p in name.split(" ") if p]
    if not parts:
        return None, set()
    brand = "".join(ch for ch in parts[0] if ch.isalpha()).upper()
    if len(brand) < 3:
        return None, set()
    strengths = set()
    for part in parts[1:]:
        number = strength_token(part)
        if number:
            strengths.add(number)
    return brand, strengths


def strength_token(part):
    """The strength a word starts with: "40" for "40mg", "2/500" for "2/500" (a combination keeps ALL its numbers:
    "2/500" and "2/850" are different products), "125" for "125mg/5ml" (the "/5ml" is a volume, not a strength).
    "" when the word does not start with a number."""
    number = ""
    i = 0
    while i < len(part) and (part[i].isnumeric() or part[i] == "."):
        number += part[i]
        i += 1
    while number and i + 1 < len(part) and part[i] == "/" and (part[i + 1].isnumeric() or part[i + 1] == "."):
        number += "/"
        i += 1
        while i < len(part) and (part[i].isnumeric() or part[i] == "."):
            number += part[i]
            i += 1
    return number


# --- dosage form + release type (same rules as ParchiCore JAName.detectForm / detectVariant) --------------------

def _rx(pattern):
    return re.compile(pattern, re.IGNORECASE)


RX_INJECTION = _rx(r"injection|infusion|\binj\b")
RX_INHALER = _rx(r"inhal(?:er|ation)\b|respules|rotacaps?|nebuli|respirator solution|\bmdi\b")
RX_TABLET = _rx(r"\btablets?\b|\btabs?\b")
RX_CAPSULE = _rx(r"\bcapsules?\b|\bcaps?\b")
RX_GARGLE = _rx(r"gargle|mouth ?wash")
RX_DROPS = _rx(r"\bdrops?\b")
RX_DROPS_SITE = _rx(r"\b(?:eye|ear|nasal)\b")
RX_OTHER = _rx(r"\b(?:eye|ear|nasal)\b|spray|shampoo|\bpaint\b|\bsoap\b|dusting|enema|suppositor|pessary|vaginal|patch|\bpen\b|\bkit\b")
RX_LIQUID = _rx(r"\bsyrup\b|suspension|\bsolution\b|\bliquid\b|emulsion|elixir")
RX_TOPICAL = _rx(r"\bointment\b|\bcream\b|\bgel\b|\blotion\b")
RX_POWDER = _rx(r"\bsachets?\b|\bpowder\b|\bgranules\b")

RX_MODIFIED = _rx(r"prolonged|sustained|extended|modified[- ]?release|controlled[- ]?release|long[- ]acting|\b(?:sr|xr|er|cr|pr|xl)\b")
RX_DISPERSIBLE = _rx(r"dispersible|dissolving|chewable|sublingual|effervescent|orodispersible|\b(?:dt|md|mdt|odt)\b")
# Release type cannot be told from these letters (MR may be muscle relaxant or modified release, OD once daily...):
# such a product is priced but never matched to Jan Aushadhi.
RX_UNCLEAR = _rx(r"\b(?:mr|od|la|tr)\b|retard|contin\b|depot|chrono|spansule")


def detect_form(text):
    s = " ".join(text.lower().split())
    if RX_INJECTION.search(s):
        return "injection"
    if RX_INHALER.search(s):
        return "inhaler"
    if RX_TABLET.search(s):
        return "tablet"
    if RX_CAPSULE.search(s):
        return "capsule"
    if RX_GARGLE.search(s):
        return "gargle"
    if RX_DROPS.search(s):
        return "drops" if RX_DROPS_SITE.search(s) else "liquid"
    if RX_OTHER.search(s):
        return None
    if RX_LIQUID.search(s):
        return "liquid"
    if RX_TOPICAL.search(s):
        return "topical"
    if RX_POWDER.search(s):
        return "powder"
    return None


def detect_variant(text):
    """"modified", "dispersible", "unclear", or None for a plain product."""
    s = " ".join(text.lower().split())
    if RX_UNCLEAR.search(s):
        return "unclear"
    if RX_MODIFIED.search(s):
        return "modified"
    if RX_DISPERSIBLE.search(s):
        return "dispersible"
    return None


def product_form(name, pack_label):
    """Name first (it says "Syrup", "Injection"), then the pack label ("bottle of 100 ml Syrup")."""
    return detect_form(name) or detect_form(pack_label)


def product_variant(name, pack_label):
    return detect_variant(name + " " + pack_label)


# --- pack size ----------------------------------------------------------------------------------------------

MEASURE_UNITS = {"ml", "l", "litre", "liter", "gm", "g", "mg", "mcg", "iu", "kg"}
RX_PACK = re.compile(r"^(.+?) of (\d+(?:\.\d+)?)\s+(\S+)", re.IGNORECASE)


def pack_units(label):
    """How many separately counted units one pack holds: 10 for "strip of 10 tablets", 1 for a bottle/tube/vial.
    None when the label cannot be understood. Same rules as ParchiCore `PackSize.unitsPerPack`."""
    m = RX_PACK.match(" ".join(label.lower().split()))
    if not m:
        return None
    number, unit = m.group(2), m.group(3).strip(".,")
    if unit in MEASURE_UNITS:
        return 1
    if "." in number:
        return None
    count = int(number)
    return count if count >= 1 else None


# --- salt composition ---------------------------------------------------------------------------------------

RX_SALT_PART = re.compile(
    r"^[A-Za-z][A-Za-z0-9 ,.'\-()/]*?\s*\((\d+(?:\.\d+)?)\s*(mg|mcg|gm|g|iu|%)((?:\s*w/[wv]|\s*v/v)?(?:\s*/\s*\d*(?:\.\d+)?\s*ml)?)\)$",
    re.IGNORECASE,
)


def _ws(text):
    return " ".join(text.split())


def salt_composition(row):
    """Canonical "Salt (strength) + Salt (strength)" or None when it cannot be trusted."""
    full = _ws(row.get("salt_composition", ""))
    if full:
        parts = [_ws(p) for p in full.split("+")]
    else:
        s1, s2 = row.get("short_composition1", ""), row.get("short_composition2", "")
        last = s2 if s2.strip() else s1
        if not last.strip() or last != last.rstrip():
            return None          # source marks "more salts follow" with a trailing space: list is cut off
        parts = [_ws(x) for x in (s1, s2) if x.strip()]
    if not parts or not all(RX_SALT_PART.match(p) for p in parts):
        return None
    return " + ".join(parts)


# --- extra words --------------------------------------------------------------------------------------------

# Words after the brand that say how the medicine is made, not which medicine it is.
NOT_EXTRA = set("""tablet tablets tab capsule capsules cap caps syrup dry suspension oral solution liquid drops drop eye ear
nasal injection inj infusion cream gel ointment lotion powder sachet granules inhaler respules rotacap rotacaps spray
syp syr susp oint tabs sr xr er cr pr xl mr od la tr dt md mdt odt soft gelatin chewable dispersible sugar free iv im vaccine mg ml gm g mcg iu
for of and with in""".split())


def extra_words(name):
    """"H" for "Telma H 40 Tablet", "LC" for "Montair LC Tablet", "" for "Telma 40 Tablet". Upper case, space joined."""
    out = []
    for part in [p for p in name.split(" ") if p][1:]:
        word = "".join(ch for ch in part.lower() if "a" <= ch <= "z")
        if not word or part[0].isdigit() or part[0] == ".":
            continue
        if word in NOT_EXTRA:
            continue
        out.append(word.upper())
    return " ".join(out)


FORMS = ["", "tablet", "capsule", "liquid", "drops", "injection", "inhaler", "topical", "powder", "gargle"]
VARIANTS = ["", "modified", "dispersible", "unclear"]


# --- build --------------------------------------------------------------------------------------------------

def rupees_to_paise(text):
    try:
        value = Fraction(text.strip())
    except (ValueError, ZeroDivisionError):
        return None
    if value <= 0:
        return None
    return int((value * 100 + Fraction(1, 2)) // 1)


def pick_key(candidate):
    """Lowest MRP per unit, then lowest MRP, then label/name/id for a stable result."""
    paise, units, pack, name, ident = candidate
    return (Fraction(paise, units or 1), paise, pack, name, ident)


def build(rows):
    """rows: dicts with the Medlex columns. Returns the JSON-ready dict (see module doc)."""
    groups = {}   # (brand, strength, extras, form, variant) -> {"cands": [...], "salts": set of salt or None}
    stats = {"rows": 0, "kept_rows": 0}
    for row in rows:
        stats["rows"] += 1
        if row.get("Is_discontinued", "").strip().upper() == "TRUE" or row.get("type", "allopathy").strip() != "allopathy":
            continue
        paise = rupees_to_paise(row.get("price", ""))
        name = _ws(row.get("name", ""))
        pack = _ws(row.get("pack_size_label", ""))
        brand, strengths = brand_and_strengths(name)
        if paise is None or brand is None or not pack:
            continue
        form = product_form(name, pack) or ""
        variant = product_variant(name, pack) or ""
        extras = extra_words(name)
        salt = salt_composition(row)
        stats["kept_rows"] += 1
        for strength in (sorted(strengths) if strengths else [""]):
            group = groups.setdefault((brand, strength, extras, form, variant), {"cands": [], "salts": set()})
            group["cands"].append((paise, pack_units(pack), pack, name, row.get("id", "")))
            group["salts"].add(salt)

    # A product without a number is kept only for a brand that has no numbered product at all.
    numbered = {key[0] for key in groups if key[1] != ""}
    chosen = {}
    for key, group in groups.items():
        if key[1] == "" and key[0] in numbered:
            continue
        paise, _units, pack, _name, _ident = min(group["cands"], key=pick_key)
        agreed = next(iter(group["salts"])) if len(group["salts"]) == 1 else None
        chosen[key] = (paise, pack, agreed)

    # Most used first: the common pack ("strip of 10 tablets") gets index 0, which is 1 character instead of 4.
    def by_use(values):
        counts = {}
        for value in values:
            counts[value] = counts.get(value, 0) + 1
        return sorted(counts, key=lambda v: (-counts[v], v))

    pack_list = by_use(v[1] for v in chosen.values())
    salt_list = by_use(v[2] for v in chosen.values() if v[2])
    extras_list = by_use(k[2] for k in chosen if k[2])
    pack_index = {p: i for i, p in enumerate(pack_list)}
    salt_index = {s: i + 1 for i, s in enumerate(salt_list)}
    extras_index = {x: i + 1 for i, x in enumerate(extras_list)}

    brands = {}
    strength_keys = set()
    entry_count = 0
    for key in sorted(chosen, key=lambda k: (k[0], k[1], k[2], k[3], k[4])):
        brand, strength, extras, form, variant = key
        paise, pack, salt = chosen[key]
        entry = [paise, pack_index[pack], FORMS.index(form) * 4 + VARIANTS.index(variant),
                 salt_index.get(salt, 0) if salt else 0, extras_index.get(extras, 0)]
        while len(entry) > 3 and entry[-1] == 0:
            entry.pop()
        brands.setdefault(brand, []).append(",".join([strength] + [str(n) for n in entry]))
        strength_keys.add((brand, strength))
        entry_count += 1

    return {
        "format": {
            "version": FORMAT_VERSION,
            "brands": "BRAND -> 'entry;entry;...' (one string per brand keeps the file small and is parsed only when the brand is looked up)",
            "entry": "'strength,m,p,fv,s,x': strength is the number as in the product name ('' = no number in the name); one entry per strength, extra words, dosage form and release type; s and x may be left out",
            "m": "MRP of one pack in paise (the pack with the lowest MRP per unit)",
            "p": "index into packs (the pack label as the product list prints it)",
            "fv": "form * 4 + release type; form index into forms (0 = unknown), release type index into variants (0 = plain)",
            "s": "index + 1 into salts (salt composition), 0 or left out when unknown or the products disagree",
            "x": "index + 1 into extras (words after the brand, 'H' in 'Telma H 40'), 0 or left out when none",
        },
        "forms": FORMS,
        "variants": VARIANTS,
        "packs": pack_list,
        "salts": salt_list,
        "extras": extras_list,
        "brands": {brand: ";".join(entries) for brand, entries in brands.items()},
        "_stats": {"brands": len(brands), "strengths": len(strength_keys), "entries": entry_count,
                   "input_rows": stats["rows"], "kept_rows": stats["kept_rows"]},
    }


def dump(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


def write_outputs(data, ja_source, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    dump(out_dir / "brand_mrp.json", data)
    shutil.copyfile(ja_source, out_dir / "janaushadhi_products.json")
    ja_rows = len(json.loads(Path(ja_source).read_text(encoding="utf-8"))["responseBody"]["newProductResponsesList"])
    version_path = out_dir / "DATA_VERSION.json"
    version = json.loads(version_path.read_text(encoding="utf-8")) if version_path.exists() else {}
    stats = data["_stats"]
    version["janaushadhi_list_date"] = JA_LIST_DATE
    version["brand_mrp"] = {"source": "Medlex product list (updated.csv)", "brands": stats["brands"],
                            "strengths": stats["strengths"], "entries": stats["entries"], "janaushadhi_rows": ja_rows}
    version_path.write_text(json.dumps(version, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def main(argv):
    args = list(argv)
    ja = DEFAULT_JA
    out = DEFAULT_OUT
    for flag in ("--ja-list", "--out"):
        if flag in args:
            i = args.index(flag)
            value = Path(args[i + 1])
            del args[i:i + 2]
            if flag == "--ja-list":
                ja = value
            else:
                out = value
    csv_path = Path(args[0]) if args else DEFAULT_MEDLEX
    if not csv_path.exists():
        raise DataError("input not found: %s" % csv_path)
    if not Path(ja).exists():
        raise DataError("Jan Aushadhi list not found: %s" % ja)
    csv.field_size_limit(1 << 24)
    with open(csv_path, encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = {"name", "price", "Is_discontinued", "type", "pack_size_label", "salt_composition",
                   "short_composition1", "short_composition2"} - set(reader.fieldnames or [])
        if missing:
            raise DataError("missing columns: %s" % ", ".join(sorted(missing)))
        data = build(reader)
    write_outputs(data, ja, Path(out))
    print(json.dumps(data["_stats"], sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except DataError as error:
        sys.exit("build_catalogue_prices: %s" % error)
