import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class DistrictRecords(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((ROOT/"game/data/v1/brinewick_district_builds.json").read_text())
        cls.inst = cls.data["installations"]

    def test_cumulative_step_counts(self):
        counts = {n: 0 for n in range(26, 31)}
        for entry in self.inst:
            counts[entry["step"]] += 1
        self.assertEqual(counts,{26:2,27:5,28:2,29:3,30:3})

    def test_stable_site_references_and_no_id_duplicates(self):
        sites = json.loads((ROOT/"game/data/v1/brinewick_step25_blockout.json").read_text())
        allowed={s["id"] for s in sites["sites"]}
        ids=[r["id"] for r in self.inst]
        self.assertEqual(len(ids),len(set(ids)))
        self.assertTrue(all(r["site_id"] in allowed for r in self.inst))

    def test_no_unapproved_population_in_saved_catalogue(self):
        catalogue=json.loads((ROOT/"game/data/v1/sample_parts.json").read_text())
        self.assertGreaterEqual(len(catalogue["parts"]),55)
        self.assertEqual(sum(1 for r in self.inst if r.get("kind")=="cottage"),1)
        self.assertFalse(any(r.get("passive_income") or r.get("auto_salvage") for r in self.inst))

    def test_protected_study(self):
        school=[x for x in self.inst if x["step"] == 30]
        self.assertTrue(all(x["protected_story"] for x in school))
        self.assertNotIn("fixture/harbour/bell",[x["id"] for x in self.inst])

if __name__=="__main__":
    unittest.main()
