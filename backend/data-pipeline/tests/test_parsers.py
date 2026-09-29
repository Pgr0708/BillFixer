import csv
import io
import json
import tempfile
import unittest
from decimal import Decimal
from pathlib import Path

from pipeline.sources import fpl, hospitals, mpfs, mrf


class FplTests(unittest.TestCase):
    def test_parse_response_verifies_year_region_size(self):
        ok = {"data": {"year": "2026", "household_size": "1", "income": "15960", "state": "US"}}
        self.assertEqual(fpl.parse_response(ok, 2026, "us", 1), Decimal("15960"))
        self.assertIsNone(fpl.parse_response(ok, 2027, "us", 1), "API falls back to latest year — must be rejected")
        self.assertIsNone(fpl.parse_response(ok, 2026, "ak", 1))
        self.assertIsNone(fpl.parse_response({"data": {"year": "2026", "household_size": "1", "income": "x", "state": "US"}}, 2026, "us", 1))

    def test_consistency_requires_constant_increment(self):
        rows = [(r, n, Decimal(b + inc * (n - 1))) for r, b, inc in (("us", 15960, 5680), ("ak", 19950, 7100), ("hi", 18360, 6530)) for n in range(1, 9)]
        self.assertTrue(fpl.looks_consistent(rows))
        rows[3] = ("us", 4, Decimal(1))
        self.assertFalse(fpl.looks_consistent(rows))


class HospitalTests(unittest.TestCase):
    def test_pretty_name(self):
        self.assertEqual(hospitals.pretty_name("ST. MARY'S MEDICAL CENTER, LLC"), "St. Mary's Medical Center, LLC")
        self.assertEqual(hospitals.pretty_name("UCSF MEDICAL CENTER"), "UCSF Medical Center")

    def test_tax_status(self):
        self.assertEqual(hospitals.tax_status("Voluntary non-profit - Private"), "nonprofit")
        self.assertEqual(hospitals.tax_status("Voluntary non-profit - Church"), "nonprofit")
        self.assertEqual(hospitals.tax_status("Proprietary"), "for_profit")
        self.assertEqual(hospitals.tax_status("Government - Hospital District or Authority"), "government")
        self.assertEqual(hospitals.tax_status("Veterans Health Administration"), "government")
        self.assertEqual(hospitals.tax_status(""), "unknown")

    def test_parse_csv(self):
        text = ('"Facility ID","Facility Name","Address","City/Town","State","ZIP Code","Telephone Number","Hospital Type","Hospital Ownership","Emergency Services"\n'
                '"10001","SOUTHEAST HEALTH MEDICAL CENTER","1108 ROSS CLARK CIRCLE","DOTHAN","AL","36301","(334) 793-8701","Acute Care Hospitals","Government - Hospital District or Authority","Yes"\n'
                '"","MISSING ID","","","","","","","",""\n')
        rows = list(hospitals.parse_csv(io.StringIO(text)))
        self.assertEqual(len(rows), 1)
        fid, name, raw, addr, city, state, zipc, phone, htype, own, tax, er = rows[0]
        self.assertEqual((fid, name, city, state, phone, tax, er), ("010001", "Southeast Health Medical Center", "Dothan", "AL", "3347938701", "government", 1))


class MpfsTests(unittest.TestCase):
    def test_find_zip_url(self):
        html = '<a href="/files/zip/rvu26d.zip">RVU26D</a> <a href="/files/zip/other.zip">x</a>'
        self.assertEqual(mpfs.find_zip_url(html), "https://www.cms.gov/files/zip/rvu26d.zip")

    def test_parse_pprrvu(self):
        header1 = ["", "", "", "STATUS", "NOT USED FOR", "WORK", "NON-FAC", "NON-FAC NA", "FACILITY", "FACILITY NA", "MP", "NON-FACILITY", "FACILITY"] + [""] * 11 + ["CONV"]
        header2 = ["HCPCS", "MOD", "DESCRIPTION", "CODE", "MEDICARE PAYMENT", "RVU", "PE RVU", "INDICATOR", "PE RVU", "INDICATOR", "RVU", "TOTAL", "TOTAL"] + [""] * 11 + ["FACTOR"]
        data = [
            ["99213", "", "Office o/p est low 20 min", "A", "", "1.30", "1.25", "", "0.53", "", "0.09", "2.64", "1.92"] + [""] * 11 + ["33.4009"],
            ["71046", "26", "X-ray exam chest 2 views", "A", "", "0.22", "0.08", "", "0.08", "", "0.01", "0.31", "0.31"] + [""] * 11 + ["33.4009"],
            ["99999", "", "Bundled code", "B", "", "0", "0", "", "0", "", "0", "0", "0"] + [""] * 11 + ["33.4009"],
        ]
        rows = list(mpfs.parse_pprrvu([["Notes line"], header1, header2, *data]))
        self.assertEqual(len(rows), 2, "status B (bundled) is not payable")
        code, mod, desc, status, nonfac, fac, cf = rows[0]
        self.assertEqual((code, nonfac, fac, cf), ("99213", "88.18", "64.13", "33.4009"))
        self.assertEqual(rows[1][1], "26")


class MrfTests(unittest.TestCase):
    def test_hpt_txt_and_location_match(self):
        txt = ("location-name: Riverside Medical Center\nsource-page-url: https://r.org/price\nmrf-url: https://r.org/a.json\n"
               "contact-name: Jane\ncontact-email: j@r.org\n\n"
               "location-name: Riverside Children's Hospital\nmrf-url: https://r.org/b.json\n")
        blocks = mrf.parse_hpt_txt(txt)
        self.assertEqual(len(blocks), 2)
        self.assertEqual(mrf.best_location(blocks, "Riverside Children's Hospital")["mrf-url"], "https://r.org/b.json")

    def _write(self, suffix, content):
        f = tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False, encoding="utf-8")
        f.write(content)
        f.close()
        self.addCleanup(Path(f.name).unlink)
        return Path(f.name)

    def test_json_v2(self):
        doc = {"hospital_name": "Riverside", "last_updated_on": "2026-07-01", "version": "2.0.0",
               "standard_charge_information": [{
                   "description": "Chest X-Ray 2 Views", "code_information": [{"code": "71046", "type": "CPT"}],
                   "standard_charges": [{"setting": "outpatient", "gross_charge": 420, "discounted_cash": 180, "minimum": 95, "maximum": 310,
                                         "payers_information": [{"payer_name": "Aetna", "standard_charge_dollar": 150},
                                                                {"payer_name": "Cigna", "standard_charge_dollar": 210},
                                                                {"payer_name": "BCBS", "standard_charge_dollar": 310}]}]},
                   {"description": "Irrelevant", "code_information": [{"code": "470", "type": "MS-DRG"}], "standard_charges": [{"gross_charge": 1}]}]}
        agg, meta = mrf.parse_file(self._write(".json", json.dumps(doc)))
        recs = list(agg.records())
        self.assertEqual(meta["format"], "json")
        self.assertEqual(meta["last_updated_on"], "2026-07-01")
        self.assertEqual(len(recs), 1)
        code, ctype, desc, setting, gross, cash, lo, hi, med, payers = recs[0]
        self.assertEqual((code, ctype, setting, gross, cash, lo, hi, med, payers), ("71046", "hcpcs", "outpatient", "420", "180", "95", "310", "210.00", 3))

    def test_csv_tall(self):
        rows = [["hospital_name", "last_updated_on", "version"], ["Riverside", "2026-07-01", "2.0.0"],
                ["description", "code|1", "code|1|type", "setting", "standard_charge|gross", "standard_charge|discounted_cash",
                 "payer_name", "plan_name", "standard_charge|negotiated_dollar", "standard_charge|min", "standard_charge|max"],
                ["EKG", "93000", "CPT", "outpatient", "210", "90", "Aetna", "PPO", "120", "", ""],
                ["EKG", "93000", "CPT", "outpatient", "210", "90", "Cigna", "HMO", "160", "", ""]]
        buf = io.StringIO()
        csv.writer(buf).writerows(rows)
        agg, meta = mrf.parse_file(self._write(".csv", buf.getvalue()))
        rec = list(agg.records())[0]
        self.assertEqual(meta["format"], "csv_tall")
        self.assertEqual(rec[0], "93000")
        self.assertEqual((rec[5], rec[6], rec[7], rec[9]), ("90", "120", "160", 2))

    def test_csv_wide(self):
        rows = [["hospital_name", "last_updated_on", "version"], ["Riverside", "2026-07-01", "2.0.0"],
                ["description", "code|1", "code|1|type", "setting", "standard_charge|gross", "standard_charge|discounted_cash",
                 "standard_charge|Aetna|PPO|negotiated_dollar", "standard_charge|Cigna|HMO|negotiated_dollar"],
                ["CT head", "70450", "CPT", "outpatient", "1800", "600", "700", "900"]]
        buf = io.StringIO()
        csv.writer(buf).writerows(rows)
        agg, meta = mrf.parse_file(self._write(".csv", buf.getvalue()))
        rec = list(agg.records())[0]
        self.assertEqual(meta["format"], "csv_wide")
        self.assertEqual((rec[0], rec[6], rec[7], rec[9]), ("70450", "700", "900", 2))


if __name__ == "__main__":
    unittest.main()
