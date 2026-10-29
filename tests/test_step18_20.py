"""Source-and-schema checks only; engine acceptance requires pinned Godot CI."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).parents[1]

class MilestoneContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=json.loads((ROOT/'game/data/v1/buildings/cottage_working_01.json').read_text())
        cls.original=json.loads((ROOT/'game/data/v1/sample_parts.json').read_text())

    def test_existing_authority_only(self):
        parts={p['id']:p for p in self.original['parts']}
        ids=[p['id'] for p in self.manifest['parts']]
        self.assertEqual(len(ids),len(set(ids)))
        self.assertGreaterEqual(len(ids),9)
        self.assertTrue({'fixture/house/front_infill','fixture/house/rear_infill','fixture/house/threshold'} <= set(ids))
        for entry in self.manifest['parts']:
            ref=parts[entry['id']]
            self.assertEqual(ref['building_id'], self.manifest['building_id'])
            self.assertEqual(ref['site_id'], self.manifest['site_id'])

    def test_geometry_and_proxies(self):
        permitted={'box','irregular_stone','slate_course','gable_panel'}
        for p in self.manifest['parts']:
            self.assertTrue(p['geometry'])
            for g in p['geometry']:
                self.assertIn(g['shape'],permitted)
                self.assertEqual(len(g['size']),3)
                self.assertTrue(all(n>0 for n in g['size']))

    def test_no_save_schema_data_changes(self):
        schema=(ROOT/'game/scripts/save/hm_save_state.gd').read_text()
        self.assertIn('SAVE_SCHEMA_VERSION: int = 1',schema)
        self.assertFalse(any('automation' in x['id'] for x in self.manifest['parts']))

    def test_ui_and_engine_suites_exist(self):
        runner=(ROOT/'tools/test_environment.py').read_text()
        for i in (18,19,20):
            self.assertIn("'18','19','20'", runner)
        ui=(ROOT/'game/scripts/main.gd').read_text()
        self.assertIn('hm_tool_radial',ui)
        self.assertIn('_inventory_summary()',ui)
        self.assertIn('HMBuildingPrefab.build',ui)

if __name__=='__main__':
    unittest.main()
