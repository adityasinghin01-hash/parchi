#!/usr/bin/env python3
"""Build the JSON data bundled in the Parchi app from the collected "Parchi Data" folder.

Usage: python3 tools/build_app_data.py [INPUT_DIR] [MEDLEX_CSV] [--out DIR]

Writes to engine/catalogue/ (bundle resources): labs.json, lab_prices.json, product_links.json,
tests_canonical.json, schedule_h1_x.json, brand_schedule.json (optional), DATA_VERSION.json.

Rules: stdlib only; money is integer paise; never invent a value (no price -> null / row skipped);
fail loudly on a missing column; output is deterministic (running twice gives identical files).
Apple Maps places and contacts are deliberately NOT shipped.
"""
import csv
import json
import re
import sys
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = Path.home() / "dev/parchi-research/drive-staging/Parchi Data"
DEFAULT_MEDLEX = Path.home() / "dev/parchi-research/data/medlex/updated.csv"
DEFAULT_OUT = REPO / "engine/catalogue"

MISSING = {"", "NOT FOUND", "BLOCKED", "N/A", "NA"}

LAB_COLUMNS = ["city", "lab", "status", "home_collection", "booking_url", "phone", "source_url", "date_seen"]
PRICE_COLUMNS = ["city", "lab", "test_canonical", "price_inr", "price_text", "source_url", "date_seen"]
LINK_COLUMNS = ["medicine_key", "seller", "usable_in_app", "product_url", "price_inr", "mrp_inr", "date_seen"]
SCHEDULE_KEYS = ["schedule", "salt", "source_url", "date", "date_seen"]
MEDLEX_COLUMNS = ["name", "salt_composition"]


class DataError(Exception):
    pass


def clean(value):
    """CSV cell -> str or None ('NOT FOUND', 'BLOCKED', empty all mean no value)."""
    if value is None:
        return None
    value = value.strip()
    return None if value.upper() in MISSING else value


def read_csv(path, required):
    if not Path(path).is_file():
        raise DataError(f"missing input file: {path}")
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        absent = [c for c in required if c not in (reader.fieldnames or [])]
        if absent:
            raise DataError(f"{path}: missing columns {absent}")
        return list(reader)


def to_paise(value, where):
    """'101.38' -> 10138. None for no value; DataError for garbage."""
    value = clean(value)
    if value is None:
        return None
    try:
        paise = (Decimal(value) * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    except InvalidOperation:
        raise DataError(f"{where}: not a number: {value!r}")
    if paise < 0:
        raise DataError(f"{where}: negative price {value!r}")
    return int(paise)


def build_labs(rows):
    out = []
    for r in rows:
        if r["status"].strip() != "confirmed":
            continue
        home = (clean(r["home_collection"]) or "unknown").lower()
        if home not in ("yes", "no", "unknown"):
            raise DataError(f"labs.csv: bad home_collection {home!r} for {r['city']}/{r['lab']}")
        out.append({
            "city": r["city"].strip(),
            "lab": r["lab"].strip(),
            "home_collection": home,
            "booking_url": clean(r["booking_url"]),
            "phone": clean(r["phone"]),
            "source_url": clean(r["source_url"]),
            "date_seen": clean(r["date_seen"]),
        })
    out.sort(key=lambda x: (x["city"], x["lab"]))
    return out


def build_lab_prices(rows):
    out = {}
    for r in rows:
        paise = to_paise(r["price_inr"], f"lab_prices {r['city']}/{r['lab']}/{r['test_canonical']}")
        if paise is None:
            continue
        entry = {
            "price_paise": paise,
            "price_text": clean(r["price_text"]),
            "source_url": clean(r["source_url"]),
            "date_seen": clean(r["date_seen"]),
        }
        slot = out.setdefault(r["city"].strip(), {}).setdefault(r["lab"].strip(), {})
        test = r["test_canonical"].strip()
        if test in slot and slot[test] != entry:
            raise DataError(f"lab_prices: conflicting duplicate {r['city']}/{r['lab']}/{test}")
        slot[test] = entry
    return out


def build_product_links(rows):
    out = {}
    for r in rows:
        if r["usable_in_app"].strip().lower() != "yes":
            continue
        url = clean(r["product_url"])
        if url is None:
            continue
        where = f"product_links {r['medicine_key']}/{r['seller']}"
        out.setdefault(r["medicine_key"].strip(), {})[r["seller"].strip()] = {
            "product_url": url,
            "price_paise": to_paise(r["price_inr"], where),
            "mrp_paise": to_paise(r["mrp_inr"], where),
            "date_seen": clean(r["date_seen"]),
        }
    return out


def build_schedule(entries):
    out = []
    for e in entries:
        missing = [k for k in SCHEDULE_KEYS if k not in e]
        if missing:
            raise DataError(f"schedule_h1_x.json: entry {e.get('salt')!r} missing {missing}")
        out.append({k: e[k] for k in SCHEDULE_KEYS})
    return out


def normalise_salt(text):
    """Lower-case salt name without strength, 'hydrochloride'/'hcl' suffix or punctuation."""
    text = re.sub(r"\([^)]*\)", " ", text.lower())
    words = [w for w in re.split(r"[^a-z0-9]+", text) if w and not w[0].isdigit()]
    words = [w for w in words if w not in ("hydrochloride", "hcl")]
    return " ".join(words)


def build_brand_schedule(rows, schedule):
    """Brand (first word, letters only, upper-case; same key as Catalogue) -> H1/X salt, from the
    salt_composition of real products. A brand is listed if ANY of its products contains an H1/X salt."""
    by_salt = {normalise_salt(e["salt"]): e for e in schedule}
    out = {}
    for r in rows:
        parts = r["name"].split()
        if not parts:
            continue
        brand = "".join(ch for ch in parts[0] if ch.isalpha()).upper()
        if len(brand) < 3:
            continue
        for part in re.split(r"\+", r["salt_composition"] or ""):
            hit = by_salt.get(normalise_salt(part))
            if hit:
                current = out.get(brand)
                # keep the stricter schedule (X) if a brand has both
                if current is None or (hit["schedule"] == "X" and current["schedule"] != "X"):
                    out[brand] = {"schedule": hit["schedule"], "salt": hit["salt"]}
    return dict(sorted(out.items()))


def dump(path, data):
    text = json.dumps(data, ensure_ascii=False, sort_keys=True, indent=1) + "\n"
    Path(path).write_text(text, encoding="utf-8")


def max_date(*chunks):
    dates = []
    for chunk in chunks:
        for item in chunk:
            d = item.get("date_seen")
            if d:
                dates.append(d)
    return max(dates) if dates else None


def build(input_dir, out_dir, medlex_csv=None):
    input_dir, out_dir = Path(input_dir), Path(out_dir)
    if not input_dir.is_dir():
        raise DataError(f"input folder not found: {input_dir}")
    labs = build_labs(read_csv(input_dir / "labs/labs.csv", LAB_COLUMNS))
    prices = build_lab_prices(read_csv(input_dir / "prices/lab_prices.csv", PRICE_COLUMNS))
    links = build_product_links(read_csv(input_dir / "product_links/product_links.csv", LINK_COLUMNS))

    tests_path = input_dir / "catalogue/tests_canonical.json"
    sched_path = input_dir / "catalogue/schedule_h1_x.json"
    for p in (tests_path, sched_path):
        if not p.is_file():
            raise DataError(f"missing input file: {p}")
    tests = json.loads(tests_path.read_text(encoding="utf-8"))
    if "tests" not in tests or any("test_canonical" not in t or "synonyms" not in t for t in tests["tests"]):
        raise DataError("tests_canonical.json: expected {'tests': [{test_canonical, synonyms, ...}]}")
    schedule = build_schedule(json.loads(sched_path.read_text(encoding="utf-8")))

    brand_schedule = None
    if medlex_csv and Path(medlex_csv).is_file():
        brand_schedule = build_brand_schedule(read_csv(medlex_csv, MEDLEX_COLUMNS), schedule)

    out_dir.mkdir(parents=True, exist_ok=True)
    dump(out_dir / "labs.json", labs)
    dump(out_dir / "lab_prices.json", prices)
    dump(out_dir / "product_links.json", links)
    # copy, re-serialised the same way so reruns are byte-identical
    dump(out_dir / "tests_canonical.json", tests)
    dump(out_dir / "schedule_h1_x.json", schedule)
    brand_path = out_dir / "brand_schedule.json"
    if brand_schedule is not None:
        dump(brand_path, brand_schedule)

    price_dates = [
        {"date_seen": v["date_seen"]}
        for city in prices.values() for lab in city.values() for v in lab.values()
    ]
    link_dates = [v for m in links.values() for v in m.values()]
    version = {
        "input_folder": input_dir.name,
        "build_date": max_date(labs, price_dates, link_dates, schedule),  # newest date_seen, so reruns are identical
        "counts": {
            "labs": len(labs),
            "lab_prices": sum(len(t) for c in prices.values() for t in c.values()),
            "product_links": sum(len(m) for m in links.values()),
            "product_links_with_price": sum(1 for m in links.values() for v in m.values() if v["price_paise"] is not None),
            "tests_canonical": len(tests["tests"]),
            "schedule_h1_x": len(schedule),
            "brand_schedule": None if brand_schedule is None else len(brand_schedule),
        },
    }
    dump(out_dir / "DATA_VERSION.json", version)
    return version


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    out = DEFAULT_OUT
    if "--out" in argv:
        out = Path(argv[argv.index("--out") + 1])
        args = [a for a in args if a != str(out)]
    input_dir = Path(args[0]) if len(args) > 0 else DEFAULT_INPUT
    medlex = Path(args[1]) if len(args) > 1 else DEFAULT_MEDLEX
    try:
        version = build(input_dir, out, medlex)
    except DataError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1
    print(json.dumps(version, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
