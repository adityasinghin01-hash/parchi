"""Score the running Claude reader on MIRAGE-100 with the repo's own scorer (ai/score_rx.py).

  .venv/bin/python eval_reader_claude.py --images ~/parchi-data/mirage100 \\
      --labels ../docs/research/evidence/labels.json --limit 5
  (more than 5 images needs --yes-spend; the reader must be running on 127.0.0.1:8100 with a key)

Matching is reused, not reinvented: the gold/prediction key rule is score_rx.gold_keys, and the optional
catalogue rows (raw / lexicon / guided) call score_rx.predict. Pages with no gold medicine are skipped for
recall/precision exactly as score_rx does; medicines returned for those pages are counted separately.
Test images only: never copy them into the repo.
"""
import argparse
import json
import re
import sys
import tempfile
import time
from pathlib import Path

import httpx

HERE = Path(__file__).resolve().parent
SCORER = HERE.parent / "ai" / "score_rx.py"
DEFAULT_CATALOGUE = Path.home() / "dev" / "parchi-research" / "data" / "medlex" / "indian_medicine_data.csv"
FREE_IMAGES = 5
ASSUMED_TOKENS_IN = 2000    # ~1,500 image tokens for a 1000x1100 page + ~500 prompt/schema
ASSUMED_TOKENS_OUT = 400    # ~6-8 JSON lines
PRICES = {"claude-opus-5-5": (4.0, 20.0), "claude-sonnet-5-5": (2.0, 10.0), "claude-haiku-5-5": (0.10, 0.50)}
INR_PER_USD = 88


def load_scorer(labels_path: Path, catalogue: Path | None) -> dict:
    """Run the top of score_rx.py (everything before its report loop) and return its namespace."""
    source = SCORER.read_text(encoding="utf8")
    head = source.split("for mode in [", 1)[0]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump({"results": {}}, handle)
        ocr_path = handle.name
    saved = sys.argv
    sys.argv = [str(SCORER), str(labels_path), ocr_path, str(catalogue)]
    namespace: dict = {"__name__": "score_rx"}
    try:
        exec(compile(head, str(SCORER), "exec"), namespace)
    finally:
        sys.argv = saved
        Path(ocr_path).unlink(missing_ok=True)
    return namespace


def predicted_keys(scorer: dict, lines: list[dict]) -> set:
    cues = scorer["CUES"]
    keys = set()
    for line in lines:
        if line.get("kind") != "medicine":
            continue
        words = re.findall(r"[A-Za-z0-9.]+", line["name"].replace(",", " "))
        while words and re.sub(r"[^A-Za-z]", "", words[0]).upper() in cues:
            words.pop(0)  # a leading "Tab." / "Cap" is a dosage-form cue, not the brand
        keys |= scorer["gold_keys"](" ".join(words))
    return keys


def estimate_inr(model: str, images: int) -> float:
    price_in, price_out = PRICES.get(model, PRICES["claude-opus-5-5"])
    return images * (ASSUMED_TOKENS_IN * price_in + ASSUMED_TOKENS_OUT * price_out) / 1_000_000 * INR_PER_USD


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--images", required=True, type=Path)
    ap.add_argument("--labels", required=True, type=Path)
    ap.add_argument("--limit", type=int, default=0, help="first N labelled images (default: all)")
    ap.add_argument("--yes-spend", action="store_true", help="required to send more than 5 images")
    ap.add_argument("--url", default="http://127.0.0.1:8100", help="reader base URL")
    ap.add_argument("--catalogue", type=Path, default=DEFAULT_CATALOGUE, help="medicine CSV the scorer loads")
    ap.add_argument("--out", type=Path, default=Path("results.json"))
    args = ap.parse_args()

    labels = json.loads(args.labels.read_text(encoding="utf8"))
    names = [n for n in sorted(labels) if (args.images / n).is_file()]
    if args.limit:
        names = names[: args.limit]
    if not names:
        print("no labelled images found in", args.images)
        return 1
    if len(names) > FREE_IMAGES and not args.yes_spend:
        print(f"REFUSING: {len(names)} images would spend real money. Re-run with --yes-spend, or --limit {FREE_IMAGES}.")
        return 2
    if not args.catalogue.is_file():
        print("catalogue CSV not found:", args.catalogue, "(pass --catalogue)")
        return 1

    with httpx.Client(timeout=120) as http:
        try:
            health = http.get(f"{args.url}/health").json()
        except httpx.HTTPError:
            print("reader is not running at", args.url)
            return 1
        if not health.get("keyConfigured"):
            print("reader has no API key (data/anthropic.key or ANTHROPIC_API_KEY)")
            return 1
        model = health["model"]
        print(f"model {model}: {len(names)} images, estimated cost INR {estimate_inr(model, len(names)):.2f} "
              f"(assumes {ASSUMED_TOKENS_IN} in / {ASSUMED_TOKENS_OUT} out tokens per image, INR = USD x {INR_PER_USD})")
        before = http.get(f"{args.url}/usage").json()

        scorer = load_scorer(args.labels, args.catalogue)
        tp = fp = fn = 0
        blank_pages = blank_pages_with_meds = blank_false_meds = 0
        failed, per_image, seconds = [], {}, []
        modes = {m: [0, 0, 0] for m in ("raw", "lexicon", "guided")}
        for i, name in enumerate(names, 1):
            started = time.monotonic()
            try:
                reply = http.post(f"{args.url}/read", files={"image": (name, (args.images / name).read_bytes(), "image/jpeg")})
            except httpx.HTTPError as exc:
                reply, error = None, type(exc).__name__
            seconds.append(time.monotonic() - started)
            if reply is None or reply.status_code != 200:
                failed.append({"image": name, "status": reply.status_code if reply is not None else error})
                lines = []
            else:
                lines = reply.json()["lines"]
            gold = scorer["gold_keys"](labels[name])
            pred = predicted_keys(scorer, lines)
            per_image[name] = {"gold": sorted(gold), "predicted": sorted(pred), "lines": len(lines)}
            if gold:
                tp += len(gold & pred); fp += len(pred - gold); fn += len(gold - pred)
                text_lines = [{"text": f'{l["name"]} {l.get("strength", "")}'} for l in lines if l["kind"] == "medicine"]
                for mode, counts in modes.items():
                    p = scorer["predict"](text_lines, mode)
                    counts[0] += len(gold & p); counts[1] += len(p - gold); counts[2] += len(gold - p)
            else:
                blank_pages += 1
                meds = sum(1 for l in lines if l["kind"] == "medicine")
                blank_false_meds += meds
                blank_pages_with_meds += bool(meds)
            print(f"[{i}/{len(names)}] {name}: {len(lines)} lines, {seconds[-1]:.1f}s", "FAILED" if failed and failed[-1]["image"] == name else "")
        after = http.get(f"{args.url}/usage").json()

    def ratio(a, b):
        return round(a / b, 4) if b else 0.0

    results = {
        "model": model, "images": len(names), "scoredImages": len(names) - blank_pages,
        "recall": ratio(tp, tp + fn), "precision": ratio(tp, tp + fp), "tp": tp, "fp": fp, "fn": fn,
        "blankPages": blank_pages, "blankPagesWithFalseMedicines": blank_pages_with_meds,
        "blankPageFalseMedicines": blank_false_meds,
        "secondsPerImage": round(sum(seconds) / len(seconds), 2),
        "failed": failed,
        "scorerRows": {m: {"recall": ratio(c[0], c[0] + c[2]), "precision": ratio(c[0], c[0] + c[1])} for m, c in modes.items()},
        "scorerRowsNote": "score_rx.predict on 'name strength' text with the catalogue; raw/lexicon/guided as in the repo scorer",
        "costUsd": round(after["costUsd"] - before["costUsd"], 6),
        "costInr": round(after["costInr"] - before["costInr"], 4),
        "tokensIn": after["inputTokens"] - before["inputTokens"],
        "tokensOut": after["outputTokens"] - before["outputTokens"],
        "estimatedCostInrBefore": round(estimate_inr(model, len(names)), 2),
        "inrNote": f"INR = USD x {INR_PER_USD}",
        "perImage": per_image,
    }
    args.out.write_text(json.dumps(results, indent=1), encoding="utf8")
    print(f"recall {results['recall']:.1%}  precision {results['precision']:.1%}  blank-page false medicines "
          f"{blank_false_meds} on {blank_pages_with_meds}/{blank_pages} blank pages  {results['secondsPerImage']} s/image  "
          f"failed {len(failed)}")
    print(f"real cost INR {results['costInr']:.2f} (USD {results['costUsd']:.4f}, {results['tokensIn']} in / {results['tokensOut']} out)  -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
