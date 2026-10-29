"""Act III fired-clay eligibility and signed-save migration source checks."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ActIIIMaterialFix(unittest.TestCase):
    def test_requisition_only_lists_available_families(self):
        reqs = json.loads((ROOT / "game/data/v1/requisitions.json").read_text())["requisitions"]
        self.assertEqual(reqs[2]["families"], ["timber", "stone"])
        self.assertEqual([r["min_registered_units"] for r in reqs], [4, 10, 25, 65])
        self.assertEqual(reqs[2]["min_distinct_sites"], 3)
        self.assertEqual(reqs[2]["requires_flags"], ["mine_voice_heard"])
        self.assertEqual(reqs[2]["required_tool_ids"], ["crowbar", "pickaxe"])
        materials = json.loads((ROOT / "game/data/v1/materials.json").read_text())["families"]
        self.assertIn("fired_clay", [m["id"] for m in materials])  # do not delete material taxonomy

    def test_legacy_hash_reconstruction_is_narrow(self):
        code = (ROOT / "game/scripts/save/hm_save_store.gd").read_text()
        for term in (
            'act_iii["families"] = ["timber", "stone", "fired_clay"]',
            'act_iii.get("families", []) != ["timber", "stone"]',
            'JSON.stringify(old_tables, "", true).sha256_text() != previous_hash',
            'HMSaveState.validate(prior_catalog, old_save)',
            'HMSaveState.validate(catalog, migrated)',
            'if previous_parts.size() != saved.size():',
        ):
            self.assertIn(term, code)

    def test_engine_regression_is_registered(self):
        runner = (ROOT / "tools/test_environment.py").read_text()
        test = (ROOT / "game/tests/test_requisition_family_migration.gd").read_text()
        self.assertIn("test_requisition_family_migration.gd", runner)
        self.assertIn("HOLLOWMERE_ACT_III_MATERIAL_MIGRATION_OK", test)
        for slot in ("act3_legacy_full", "act3_legacy_297", "act3_legacy_75", "act3_invalid_quota"):
            self.assertIn(slot, test)

if __name__ == "__main__":
    unittest.main()
