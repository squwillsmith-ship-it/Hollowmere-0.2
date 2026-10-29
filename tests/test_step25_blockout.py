"""Step25 static authority checks (not Godot collision proof)."""
import json, pathlib, unittest
R=pathlib.Path(__file__).parents[1]
class BlockoutContract(unittest.TestCase):
    def test_all_site_functions_are_provisional(self):
        world=json.loads((R/'game/data/v1/brinewick_step25_blockout.json').read_text())
        canon=json.loads((R/'game/data/v1/locations.json').read_text())
        ids=[p['id'] for p in world['sites']]
        self.assertEqual(len(ids),21)
        self.assertEqual(set(ids),{x['id'] for x in canon['sites']})
        self.assertTrue(all(x['unapproved_footprint'] for x in world['sites']))
        self.assertEqual(len(ids),len(set(ids)))
        self.assertTrue(all(len(s['position']) == 3 for s in world['sites']))
    def test_runtime_scene(self):
        self.assertTrue((R/'game/scenes/brinewick_blockout.tscn').exists())
        src=(R/'game/scripts/world/hm_brinewick_blockout.gd').read_text()
        self.assertIn('LowerToUpperRamp',src)
        self.assertIn('UpperToHeadlandRamp',src)
        self.assertIn('site_nodes[id] = marker',src)
        self.assertNotIn('HMTransactions.apply',src)
