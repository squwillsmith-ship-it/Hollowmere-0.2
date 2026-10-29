"""Offline source invariants; NOT a substitute for a Godot graphics/physics run."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / 'game/scripts/world'

class Batch03SourceRegression(unittest.TestCase):
    def test_roadskins_do_not_replace_legacy_physics(self):
        text=(WORLD/'hm_coastal_road_wear.gd').read_text()
        for forbidden in ('StaticBody3D.new()', 'CollisionShape3D.new()',
                          'HMInspectTarget.new()', 'HMRecoveredOutput.new()'):
            self.assertNotIn(forbidden,text)
        self.assertIn('solid.add_child(skin)',text)
        self.assertIn('shape_node.shape as BoxShape3D',text)
        self.assertIn('dressed_roads += 1',text)
    def test_road_follows_physical_grades(self):
        world=(WORLD/'hm_brinewick_blockout.gd').read_text()
        self.assertIn('road_wear.build(roads)',world)
        road=(WORLD/'hm_coastal_road_wear.gd').read_text()
        self.assertIn('var y: float = size.y * 0.5 + 0.037',road)
        self.assertIn('solid.add_child(skin)',road)
        self.assertNotIn('body.position =',road)
        self.assertNotIn('solid.position =',road)
    def test_faceted_open_boat_keeps_seaward_position(self):
        harbour=(WORLD/'hm_phase_c_harbour_dressing.gd').read_text()
        self.assertIn('origin + Vector3(-13.4,-1.5,-2.0)',harbour)
        self.assertIn('_clinker_hull(st,boat)',harbour)
        self.assertIn('hull_planks += 1',harbour)
        self.assertNotIn('CollisionShape3D.new()',harbour)
    def test_new_godot_test_is_registered(self):
        script=(ROOT/'tools/test_environment.py').read_text()
        self.assertIn('res://tests/test_visual_rebuild_batch03.gd',script)
        self.assertIn('HOLLOWMERE_VISUAL_BATCH03_OK',script)

if __name__ == '__main__':
    unittest.main()
