import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_app_data as b  # noqa: E402

LAB_HEAD = ["city", "lab", "type", "status", "home_collection", "booking_url", "phone", "whatsapp", "address",
            "source_url", "date_seen", "verify"]
PRICE_HEAD = ["city", "lab", "test_canonical", "test_name_on_page", "price_inr", "price_text", "mrp_inr",
              "source_url", "date_seen", "verify", "note"]
LINK_HEAD = ["medicine_key", "medicine_asked", "seller", "usable_in_app", "match", "product_title_on_page",
             "pack_size_on_page", "form", "strength", "product_url", "price_inr", "price_text", "mrp_inr",
             "in_stock", "verify", "date_seen", "note"]


def write_csv(path, head, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=head)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in head})


def make_input(root, drop_price_col=None):
    write_csv(root / "labs/labs.csv", LAB_HEAD, [
        dict(city="Meerut", lab="Dr Lal PathLabs", status="confirmed", home_collection="yes",
             booking_url="https://x/book", phone="+911", source_url="https://x", date_seen="2026-10-23"),
        dict(city="Meerut", lab="Thyrocare", status="NOT FOUND", home_collection="unknown",
             booking_url="NOT FOUND", phone="NOT FOUND", source_url="NOT FOUND", date_seen="2026-10-23"),
        dict(city="Muradnagar", lab="Agilus", status="BLOCKED", home_collection="unknown", date_seen="2026-10-23"),
        dict(city="Meerut", lab="Agilus", status="confirmed", home_collection="unknown",
             booking_url="NOT FOUND", phone="+912", source_url="https://y", date_seen="2026-10-22"),
    ])
    head = [h for h in PRICE_HEAD if h != drop_price_col]
    write_csv(root / "prices/lab_prices.csv", head, [
        dict(city="Meerut", lab="Dr Lal PathLabs", test_canonical="CBC", price_inr="210", price_text="₹210.00",
             source_url="https://p", date_seen="2026-10-23"),
        dict(city="Meerut", lab="Agilus", test_canonical="Total T4", price_inr="99.5", price_text="₹99.5",
             source_url="https://q", date_seen="2026-10-23"),
        dict(city="Meerut", lab="Agilus", test_canonical="HbA1c", price_inr="NOT FOUND", price_text="",
             source_url="https://q", date_seen="2026-10-23"),
    ])
    write_csv(root / "product_links/product_links.csv", LINK_HEAD, [
        dict(medicine_key="azithral_500", seller="Blinkit", usable_in_app="yes", product_url="https://b/1",
             price_inr="111", mrp_inr="126.73", date_seen="2026-10-23"),
        dict(medicine_key="azithral_500", seller="Apollo Pharmacy", usable_in_app="yes", product_url="https://a/1",
             price_inr="", mrp_inr="", date_seen="2026-10-23"),
        dict(medicine_key="azithral_500", seller="Amazon Pharmacy", usable_in_app="no", product_url="BLOCKED",
             price_inr="5", date_seen="2026-10-23"),
    ])
    (root / "catalogue").mkdir(parents=True, exist_ok=True)
    (root / "catalogue/tests_canonical.json").write_text(json.dumps(
        {"tests": [{"test_canonical": "CBC", "synonyms": ["CBC"], "confusable_with": []}]}), encoding="utf-8")
    (root / "catalogue/schedule_h1_x.json").write_text(json.dumps([
        {"schedule": "H1", "salt": "Alprazolam", "source_url": "https://g", "date": "2013-08-30",
         "date_seen": "2026-10-23", "verify": "x", "notification_no": "n"},
        {"schedule": "X", "salt": "Ketamine hydrochloride", "source_url": "https://g", "date": "1985-01-01",
         "date_seen": "2026-10-23"},
    ]), encoding="utf-8")


def make_medlex(path):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["id", "name", "salt_composition", "short_composition1", "short_composition2"])
        w.writeheader()
        w.writerow({"id": 1, "name": "Alprax 0.25 Tablet", "salt_composition": "Alprazolam (0.25mg)"})
        w.writerow({"id": 2, "name": "Ketmin 50 Injection", "salt_composition": "Ketamine (50mg)"})
        w.writerow({"id": 3, "name": "Dolo 650 Tablet", "salt_composition": "Paracetamol (650mg)"})
        w.writerow({"id": 4, "name": "Mix Tablet", "salt_composition": "Paracetamol (325mg) + Alprazolam (0.5mg)"})
        # salt_composition empty, only the short columns filled (the real "Aaram Tablet" row)
        w.writerow({"id": 5, "name": "Aaram 0.5mg Tablet", "salt_composition": "", "short_composition1": "Alprazolam (0.5mg)"})
        w.writerow({"id": 6, "name": "Zolnor Tablet", "salt_composition": "", "short_composition1": "Paracetamol (325mg) ",
                    "short_composition2": " Ketamine HCl (10mg)"})
        w.writerow({"id": 7, "name": "Crocin 500 Tablet", "salt_composition": "", "short_composition1": "Paracetamol (500mg)"})   # negative control
        w.writerow({"id": 8, "name": "Alprazolam 0.25 Tablet", "salt_composition": "", "short_composition1": "Alprazolam (0.25mg)"})


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.inp = self.root / "Parchi Data"
        self.out = self.root / "out"
        make_input(self.inp)
        self.medlex = self.root / "medlex.csv"
        make_medlex(self.medlex)

    def tearDown(self):
        self.tmp.cleanup()

    def load(self, name):
        return json.loads((self.out / name).read_text(encoding="utf-8"))

    def test_labs_only_confirmed(self):
        b.build(self.inp, self.out, self.medlex)
        labs = self.load("labs.json")
        self.assertEqual([(l["city"], l["lab"]) for l in labs], [("Meerut", "Agilus"), ("Meerut", "Dr Lal PathLabs")])
        self.assertIsNone(labs[0]["booking_url"])  # NOT FOUND -> null, never a made-up value
        self.assertEqual(labs[1]["home_collection"], "yes")

    def test_lab_prices_paise_and_skip_missing(self):
        b.build(self.inp, self.out, self.medlex)
        prices = self.load("lab_prices.json")
        self.assertEqual(prices["Meerut"]["Dr Lal PathLabs"]["CBC"]["price_paise"], 21000)
        self.assertEqual(prices["Meerut"]["Agilus"]["Total T4"]["price_paise"], 9950)
        self.assertNotIn("HbA1c", prices["Meerut"]["Agilus"])

    def test_product_links_usable_and_null_prices(self):
        b.build(self.inp, self.out, self.medlex)
        links = self.load("product_links.json")["azithral_500"]
        self.assertEqual(set(links), {"Blinkit", "Apollo Pharmacy"})
        self.assertEqual(links["Blinkit"]["price_paise"], 11100)
        self.assertEqual(links["Blinkit"]["mrp_paise"], 12673)
        self.assertIsNone(links["Apollo Pharmacy"]["price_paise"])
        self.assertIsNone(links["Apollo Pharmacy"]["mrp_paise"])

    def test_schedule_and_tests_copied(self):
        b.build(self.inp, self.out, self.medlex)
        sched = self.load("schedule_h1_x.json")
        self.assertEqual([s["salt"] for s in sched], ["Alprazolam", "Ketamine hydrochloride"])
        self.assertEqual(set(sched[0]), set(b.SCHEDULE_KEYS))
        self.assertEqual(self.load("tests_canonical.json")["tests"][0]["test_canonical"], "CBC")

    def test_brand_schedule(self):
        b.build(self.inp, self.out, self.medlex)
        brands = self.load("brand_schedule.json")
        self.assertEqual(brands["ALPRAX"], {"schedule": "H1", "salt": "Alprazolam"})
        self.assertEqual(brands["KETMIN"]["schedule"], "X")  # 'Ketamine' matches 'Ketamine hydrochloride'
        self.assertEqual(brands["MIX"]["salt"], "Alprazolam")
        self.assertNotIn("DOLO", brands)

    def test_brand_schedule_reads_the_short_composition_columns_too(self):
        b.build(self.inp, self.out, self.medlex)
        brands = self.load("brand_schedule.json")
        self.assertEqual(brands["AARAM"], {"schedule": "H1", "salt": "Alprazolam"})       # review item 2
        self.assertEqual(brands["ALPRAZOLAM"]["schedule"], "H1")
        self.assertEqual(brands["ZOLNOR"], {"schedule": "X", "salt": "Ketamine hydrochloride"})   # second short column
        self.assertNotIn("CROCIN", brands)                                                  # negative control
        self.assertNotIn("DOLO", brands)

    def test_brand_schedule_still_works_for_a_file_without_the_short_columns(self):
        old = self.root / "old.csv"
        with open(old, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["id", "name", "salt_composition"])
            w.writeheader()
            w.writerow({"id": 1, "name": "Alprax 0.25 Tablet", "salt_composition": "Alprazolam (0.25mg)"})
        b.build(self.inp, self.out, old)
        self.assertEqual(self.load("brand_schedule.json")["ALPRAX"]["schedule"], "H1")

    def test_brand_is_listed_only_when_half_its_active_products_are_scheduled(self):
        schedule = [{"salt": "Tramadol", "schedule": "H1"}]
        rows = [{"name": "Calpol 500 Tablet", "salt_composition": "Paracetamol (500mg)"} for _ in range(7)]
        rows.append({"name": "Calpol T Tablet", "salt_composition": "Paracetamol (325mg) + Tramadol (37.5mg)"})   # 1 of 8
        rows.append({"name": "Calpol Old Tablet", "salt_composition": "Tramadol (50mg)", "Is_discontinued": "TRUE"})   # ignored
        rows.append({"name": "Oflo 200 Tablet", "salt_composition": "Tramadol (50mg)"})                                # 1 of 1
        rows += [{"name": "Half 1 Tablet", "salt_composition": "Tramadol (50mg)"}, {"name": "Half 2 Tablet", "salt_composition": "Paracetamol"}]
        brands = b.build_brand_schedule(rows, schedule)
        self.assertNotIn("CALPOL", brands, "1 of 8 products is not enough to flag the whole brand")
        self.assertEqual(brands["OFLO"]["schedule"], "H1")
        self.assertEqual(brands["HALF"]["schedule"], "H1", "exactly half counts")
        self.assertIn("CALPOL", b.build_brand_schedule(rows, schedule, min_share=0.1), "the threshold is a parameter")

    def test_data_version_counts(self):
        v = b.build(self.inp, self.out, self.medlex)
        self.assertEqual(v["input_folder"], "Parchi Data")
        self.assertEqual(v["counts"]["labs"], 2)
        self.assertEqual(v["counts"]["lab_prices"], 2)
        self.assertEqual(v["counts"]["product_links"], 2)
        self.assertEqual(v["counts"]["product_links_with_price"], 1)
        self.assertEqual(v["counts"]["schedule_h1_x"], 2)
        self.assertEqual(v["counts"]["brand_schedule"], 6)
        self.assertEqual(v["build_date"], "2026-10-23")
        self.assertEqual(self.load("DATA_VERSION.json"), v)

    def test_idempotent(self):
        b.build(self.inp, self.out, self.medlex)
        first = {p.name: p.read_bytes() for p in self.out.iterdir()}
        b.build(self.inp, self.out, self.medlex)
        second = {p.name: p.read_bytes() for p in self.out.iterdir()}
        self.assertEqual(first, second)

    def test_missing_column_fails_loudly(self):
        make_input(self.inp, drop_price_col="price_inr")
        with self.assertRaises(b.DataError) as ctx:
            b.build(self.inp, self.out, self.medlex)
        self.assertIn("price_inr", str(ctx.exception))

    def test_missing_file_fails_loudly(self):
        (self.inp / "labs/labs.csv").unlink()
        with self.assertRaises(b.DataError):
            b.build(self.inp, self.out, self.medlex)

    def test_garbage_price_fails(self):
        with self.assertRaises(b.DataError):
            b.to_paise("abc", "x")

    def test_conflicting_duplicate_price_fails(self):
        path = self.inp / "prices/lab_prices.csv"
        with open(path, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        rows.append(dict(rows[0], price_inr="999"))
        write_csv(path, PRICE_HEAD, rows)
        with self.assertRaises(b.DataError):
            b.build(self.inp, self.out, self.medlex)

    def test_normalise_salt(self):
        self.assertEqual(b.normalise_salt("Ketamine HCl (50mg)"), "ketamine")
        self.assertEqual(b.normalise_salt("Ethambutol Hydrochloride"), "ethambutol")


if __name__ == "__main__":
    unittest.main()
