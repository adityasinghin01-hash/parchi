import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_catalogue_prices as b  # noqa: E402
import contextlib  # noqa: E402
import io  # noqa: E402

HEAD = ["id", "name", "price", "Is_discontinued", "manufacturer_name", "type", "pack_size_label",
        "short_composition1", "short_composition2", "salt_composition"]


def row(ident, name, price, pack="strip of 10 tablets", disc="FALSE", salt="", s1="", s2="", kind="allopathy"):
    return {"id": str(ident), "name": name, "price": str(price), "Is_discontinued": disc, "manufacturer_name": "X",
            "type": kind, "pack_size_label": pack, "short_composition1": s1, "short_composition2": s2,
            "salt_composition": salt}


ROWS = [
    row(1, "Telma 40 Tablet", "245.95", "strip of 30 tablets", salt="Telmisartan (40mg)"),
    row(2, "Telma 40 Tablet", "122.98", "strip of 15 tablets", salt="Telmisartan (40mg)"),
    row(3, "Telma 40 Tablet", "9.00", "strip of 10 tablets", disc="TRUE", salt="Telmisartan (40mg)"),       # discontinued: ignored
    row(4, "Telma H 40 Tablet", "150", salt="Telmisartan (40mg) + Hydrochlorothiazide (12.5mg)"),          # extra word H
    row(5, "Telma 80 Tablet", "187.32", "strip of 15 tablets", salt="Telmisartan (80mg)"),
    row(6, "Glycomet 500 SR Tablet", "47.71", "strip of 20 tablet sr", salt="Metformin (500mg)"),
    row(7, "Glycomet 500 Tablet", "30", "strip of 10 tablets", salt="Metformin (500mg)"),
    row(8, "Pan 40 Tablet", "155", salt="Pantoprazole (40mg)"),
    row(9, "Pan 40 Injection", "70", "vial of 1 Injection", salt="Pantoprazole (40mg)"),
    row(10, "Ascoril Syrup", "99", "bottle of 100 ml Syrup", s1="Ambroxol (15mg)", s2=" Levosalbutamol (1mg) "),    # cut off list
    row(11, "Cefix 200 Tablet", "80", s1="Cefixime (200mg)"),                                              # complete short list
    row(12, "Vitamin Plus Tablet", "12", salt=""),                                                         # no number, brand has none
    row(13, "Dolo 650 Tablet", "34.27", "strip of 15 tablets", salt="Paracetamol (650mg)"),
    row(14, "Dolo Drops", "20", "bottle of 15 ml Drops"),                                                  # no number but brand has numbered
    row(15, "Ayur Kit", "50", kind="ayurveda"),                                                            # not allopathy
    row(16, "AB 10 Tablet", "5"),                                                                          # brand shorter than 3 letters
    row(17, "Free 10 Tablet", "0"),                                                                        # no price
    row(18, "Dolo 650 Tablet", "40", "strip of 15 tablets", salt="Paracetamol (500mg)"),                  # products disagree on the salt
    row(19, "Syrupy 5 Syrup", "40", "bottle of 60 ml Syrup", salt="Cetirizine (5mg/5ml)"),
]


def built():
    return b.build(ROWS)


def entries(data, brand):
    out = []
    for item in data["brands"][brand].split(";"):
        f = item.split(",")
        out.append({"strength": f[0], "m": int(f[1]), "pack": data["packs"][int(f[2])], "form": data["forms"][int(f[3]) // 4],
                    "variant": data["variants"][int(f[3]) % 4],
                    "salt": data["salts"][int(f[4]) - 1] if len(f) > 4 and int(f[4]) else None,
                    "extras": data["extras"][int(f[5]) - 1] if len(f) > 5 and int(f[5]) else ""})
    return out


class KeyTests(unittest.TestCase):
    def test_brand_and_strengths_follow_the_app_catalogue(self):
        self.assertEqual(b.brand_and_strengths("Telma 40 Tablet"), ("TELMA", {"40"}))
        self.assertEqual(b.brand_and_strengths("Pan 40mg Tablet"), ("PAN", {"40"}))
        self.assertEqual(b.brand_and_strengths("Montair-LC Tablet"), ("MONTAIRLC", set()))
        self.assertEqual(b.brand_and_strengths("Granac MR 100mg/325mg/250mg Tablet"), ("GRANAC", {"100"}))
        self.assertEqual(b.brand_and_strengths("AB 10 Tablet"), (None, set()))
        self.assertEqual(b.brand_and_strengths("Augmentin 1.2 Injection"), ("AUGMENTIN", {"1.2"}))

    def test_extra_words(self):
        self.assertEqual(b.extra_words("Telma H 40 Tablet"), "H")
        self.assertEqual(b.extra_words("Montair LC Kid Syrup"), "LC KID")
        self.assertEqual(b.extra_words("Telma 40 Tablet"), "")
        self.assertEqual(b.extra_words("Glycomet 500 SR Tablet"), "")
        self.assertEqual(b.extra_words("Pan 40 Injection IV"), "")

    def test_form_and_release(self):
        self.assertEqual(b.product_form("Pan 40 Injection", ""), "injection")
        self.assertEqual(b.product_form("Ascoril Syrup", "bottle of 100 ml Syrup"), "liquid")
        self.assertEqual(b.product_form("Dolo Drops", "bottle of 15 ml Drops"), "liquid")      # oral drops are liquid
        self.assertEqual(b.product_form("Napa Eye Drop", ""), "drops")
        self.assertIsNone(b.product_form("Mystery 5", "box of 5 things"))
        self.assertEqual(b.product_variant("Glycomet 500 SR Tablet", "strip of 20 tablet sr"), "modified")
        self.assertEqual(b.product_variant("Montair 4mg Chewable Tablet", ""), "dispersible")
        self.assertEqual(b.product_variant("Dvcor OD 500mg Tablet", ""), "unclear")
        self.assertIsNone(b.product_variant("Telma 40 Tablet", "strip of 10 tablets"))

    def test_pack_units(self):
        self.assertEqual(b.pack_units("strip of 10 tablets"), 10)
        self.assertEqual(b.pack_units("strip of 10 tablet sr"), 10)
        self.assertEqual(b.pack_units("bottle of 100 ml Syrup"), 1)
        self.assertEqual(b.pack_units("tube of 15 gm Cream"), 1)
        self.assertEqual(b.pack_units("vial of 1 Injection"), 1)
        self.assertIsNone(b.pack_units("vial of 5.5 \u00b5cg Powder for Injection"))
        self.assertIsNone(b.pack_units(""))

    def test_salt_composition(self):
        self.assertEqual(b.salt_composition(row(1, "x", 1, salt="Azithromycin (500mg)")), "Azithromycin (500mg)")
        self.assertEqual(b.salt_composition(row(1, "x", 1, salt="Amoxycillin  (500mg) +  Clavulanic Acid (125mg)")),
                         "Amoxycillin (500mg) + Clavulanic Acid (125mg)")
        self.assertEqual(b.salt_composition(row(1, "x", 1, s1="Cefixime (200mg)")), "Cefixime (200mg)")
        self.assertIsNone(b.salt_composition(row(1, "x", 1, s1="Ambroxol (15mg)", s2=" Levosalbutamol (1mg) ")))
        self.assertIsNone(b.salt_composition(row(1, "x", 1, salt="Loperamide (NA)")))
        self.assertEqual(b.salt_composition(row(1, "x", 1, salt="Lactulose (3.35gm/5ml)")), "Lactulose (3.35gm/5ml)")
        self.assertEqual(b.salt_composition(row(1, "x", 1, salt="Clobetasol (0.05% w/w)")), "Clobetasol (0.05% w/w)")


class BuildTests(unittest.TestCase):
    def test_cheapest_pack_per_unit_not_a_one_tablet_strip(self):
        data = built()
        [e] = [x for x in entries(data, "TELMA") if x["strength"] == "40" and x["extras"] == ""]
        # 245.95 / 30 = 8.1983 per tablet beats 122.98 / 15 = 8.1987; the discontinued 9.00 strip is ignored
        self.assertEqual((e["m"], e["pack"]), (24595, "strip of 30 tablets"))
        self.assertEqual(e["salt"], "Telmisartan (40mg)")
        self.assertEqual((e["form"], e["variant"]), ("tablet", ""))

    def test_extra_words_keep_combination_products_apart(self):
        data = built()
        telma40 = [x for x in entries(data, "TELMA") if x["strength"] == "40"]
        self.assertEqual(sorted((x["extras"], x["m"]) for x in telma40), [("", 24595), ("H", 15000)])

    def test_release_types_and_forms_are_separate_entries(self):
        data = built()
        glycomet = [x for x in entries(data, "GLYCOMET") if x["strength"] == "500"]
        self.assertEqual(sorted((x["variant"], x["m"]) for x in glycomet), [("", 3000), ("modified", 4771)])
        pan = [x for x in entries(data, "PAN") if x["strength"] == "40"]
        self.assertEqual(sorted((x["form"], x["m"]) for x in pan), [("injection", 7000), ("tablet", 15500)])

    def test_products_that_disagree_on_the_salt_get_no_salt(self):
        data = built()
        [dolo] = [x for x in entries(data, "DOLO") if x["strength"] == "650"]
        self.assertIsNone(dolo["salt"])
        self.assertEqual(dolo["m"], 3427)        # 34.27 for 15 tablets is cheaper per tablet than 40 for 15

    def test_numberless_products_only_for_brands_without_numbers(self):
        data = built()
        self.assertEqual([x["strength"] for x in entries(data, "ASCORIL")], [""])
        self.assertEqual([x["strength"] for x in entries(data, "VITAMIN")], [""])
        self.assertNotIn("", [x["strength"] for x in entries(data, "DOLO")])     # "Dolo Drops" dropped: Dolo has numbered products

    def test_rows_that_cannot_be_priced_are_left_out(self):
        data = built()
        for brand in ("AYUR", "FREE", "AB"):
            self.assertNotIn(brand, data["brands"])
        self.assertIn("SYRUPY", data["brands"])

    def test_cut_off_short_composition_is_not_a_salt_but_a_complete_one_is(self):
        data = built()
        self.assertIsNone(entries(data, "ASCORIL")[0]["salt"])
        self.assertEqual(entries(data, "CEFIX")[0]["salt"], "Cefixime (200mg)")

    def test_stats_and_tables(self):
        data = built()
        self.assertEqual(data["_stats"]["brands"], len(data["brands"]))
        self.assertEqual(data["_stats"]["entries"], sum(len(v.split(";")) for v in data["brands"].values()))
        self.assertEqual(data["packs"][0], "strip of 10 tablets")      # most used pack first
        self.assertEqual(len(set(data["packs"])), len(data["packs"]))

    def test_deterministic_whatever_the_input_order(self):
        a = json.dumps(b.build(ROWS), sort_keys=True)
        c = json.dumps(b.build(list(reversed(ROWS))), sort_keys=True)
        self.assertEqual(a, c)


class FilesTests(unittest.TestCase):
    def make_inputs(self, root):
        csv_path = root / "updated.csv"
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=HEAD)
            w.writeheader()
            for r in ROWS:
                w.writerow(r)
        ja = root / "ja.json"
        ja.write_text(json.dumps({"responseBody": {"newProductResponsesList": [
            {"productId": 1, "genericName": "Telmisartan Tablets IP 40 mg", "unitSize": "10's", "mrp": 9.5}]}}), encoding="utf-8")
        return csv_path, ja

    def test_writes_files_keeps_other_version_keys_and_is_byte_identical_on_rerun(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            csv_path, ja = self.make_inputs(root)
            out = root / "out"
            out.mkdir()
            (out / "DATA_VERSION.json").write_text(json.dumps({"build_date": "2026-10-23", "counts": {"labs": 1}}), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(b.main([str(csv_path), "--ja-list", str(ja), "--out", str(out)]), 0)
            first = {p.name: p.read_bytes() for p in out.iterdir()}
            self.assertEqual(sorted(first), ["DATA_VERSION.json", "brand_mrp.json", "janaushadhi_products.json"])
            self.assertEqual(first["janaushadhi_products.json"], ja.read_bytes())
            version = json.loads(first["DATA_VERSION.json"])
            self.assertEqual(version["janaushadhi_list_date"], "2026-10-23")
            self.assertEqual(version["counts"], {"labs": 1})
            self.assertEqual(version["brand_mrp"]["janaushadhi_rows"], 1)
            with contextlib.redirect_stdout(io.StringIO()):
                b.main([str(csv_path), "--ja-list", str(ja), "--out", str(out)])
            self.assertEqual(first, {p.name: p.read_bytes() for p in out.iterdir()})

    def test_missing_column_fails_loudly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            csv_path, ja = self.make_inputs(root)
            text = csv_path.read_text(encoding="utf-8").replace("pack_size_label", "pack")
            csv_path.write_text(text, encoding="utf-8")
            with self.assertRaises(b.DataError):
                b.main([str(csv_path), "--ja-list", str(ja), "--out", str(root / "out")])


if __name__ == "__main__":
    unittest.main()
