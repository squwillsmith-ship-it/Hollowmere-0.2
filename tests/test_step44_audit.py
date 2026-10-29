"""Step44 source-data audit negative-case regression suite."""
import json
from pathlib import Path
import tempfile
import unittest
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from audit_step44 import analyze

NAMES = ("sample_parts", "landmark_parts", "tools", "materials",
         "upgrades", "requisitions", "story", "locations")

class AuditChecks(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.path = Path(self.workspace.name)
        for name in NAMES:
            file = name + ".json"
            source = ROOT / "game" / "data" / "v1" / file
            (self.path / file).write_bytes(source.read_bytes())

    def tearDown(self):
        self.workspace.cleanup()

    def alter(self, name, change):
        file = self.path / (name + ".json")
        data = json.loads(file.read_text(encoding="utf-8"))
        change(data)
        file.write_text(json.dumps(data), encoding="utf-8")

    def test_actual_content(self):
        metrics, errors = analyze(self.path)
        self.assertEqual(errors, [])
        self.assertEqual(metrics["total_definitions"], 351)
        # Catalogue totals preserve legacy engineering-yard definitions,
        # while campaign totals must exclude 4 non-spawned shed fixtures.
        self.assertEqual(metrics["total_recoverable_units"], 1311)
        self.assertEqual(metrics["maximum_potential_intact_sale_credits"], 3179)
        self.assertEqual(metrics["normal_brinewick_removable_parts"], 345)
        self.assertEqual(metrics["engineering_yard_only_parts"], 4)
        self.assertEqual(metrics["normal_brinewick_total_units"], 1297)
        self.assertEqual(metrics["normal_brinewick_maximum_intact_sale_credits"], 3139)
        self.assertEqual(metrics["largest_single_output_units"], 8)  # Bell is protected, not a carry parcel
        self.assertEqual(metrics["safe_reachability_by_act"][1]["units"], 14)
        self.assertEqual(metrics["safe_reachability_by_act"][2]["units"], 854)
        self.assertEqual(metrics["safe_reachability_by_act"][3]["units"], 1297)
        self.assertFalse(metrics["balance_approved"])
        self.assertFalse(any("fired_clay" in warning for warning in metrics["warnings"]))
        requisitions = json.loads((self.path / "requisitions.json").read_text())["requisitions"]
        self.assertEqual(requisitions[2]["families"], ["timber", "stone"])
        self.assertEqual(requisitions[2]["min_registered_units"], 25)

    def test_unavailable_requisition_family_is_detected(self):
        self.alter("requisitions", lambda d:
                   d["requisitions"][2]["families"].append("fired_clay"))
        report, errors = analyze(self.path)
        self.assertTrue(any("fired_clay" in item and "req_act_03" in item
                            for item in errors))
        self.assertEqual(report["status"], "FAIL_STATIC")

    def test_material_mismatch(self):
        self.alter("landmark_parts", lambda d:
                   d["parts"][0]["outputs"][0]["allocation"].update({"stone": 99}))
        _, errors = analyze(self.path)
        self.assertTrue(any("Output conservation failure" in e for e in errors))

    def test_bad_support_cycle(self):
        def mutate(data):
            a, b = data["parts"][0:2]
            a["supports"] = [b["id"]]
            b["supports"] = [a["id"]]
        self.alter("landmark_parts", mutate)
        _, errors = analyze(self.path)
        self.assertTrue(any("cycle" in e.lower() for e in errors))

    def test_incorrect_tool_tier(self):
        self.alter("landmark_parts", lambda d: d["parts"][1].update({"tier": 1}))
        _, errors = analyze(self.path)
        self.assertTrue(any("Tool/tier mismatch" in e for e in errors))

    def test_unknown_requisition_material_rejected(self):
        self.alter("requisitions", lambda d:
                   d["requisitions"][2]["families"].append("imaginary_stone"))
        _, errors = analyze(self.path)
        self.assertTrue(any("Unknown requisition family imaginary_stone" in e
                            for e in errors))

    def test_engineering_only_fixture_does_not_inflate_campaign(self):
        def mutate(data):
            part = next(p for p in data["parts"] if p["id"] == "fixture/shed/loose_rope")
            part["allocation"]["fibres"] = 3
            part["outputs"][0]["allocation"]["fibres"] = 3
        self.alter("sample_parts", mutate)
        metrics, errors = analyze(self.path)
        self.assertEqual(errors, [])
        self.assertEqual(metrics["normal_brinewick_total_units"], 1297)
        self.assertEqual(metrics["safe_reachability_by_act"][1]["units"], 14)
        self.assertEqual(metrics["total_recoverable_units"], 1312)

    def test_impossible_first_quota(self):
        self.alter("requisitions", lambda d:
                   d["requisitions"][0].update({"min_registered_units": 100000}))
        _, errors = analyze(self.path)
        self.assertTrue(any("Insufficient safe salvage" in e for e in errors))

if __name__ == "__main__":
    unittest.main()
