"""Source-level Phase C checks: these do not substitute for Godot/Forward+."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
WORLD = GAME / 'scripts/world'

class PhaseCVisualContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((GAME/'data/v1/brinewick_step25_blockout.json').read_text())
        cls.district = json.loads((GAME/'data/v1/brinewick_district_builds.json').read_text())
        cls.landmark = json.loads((GAME/'data/v1/landmark_parts.json').read_text())
        cls.cottage = json.loads((GAME/'data/v1/buildings/cottage_working_01.json').read_text())
        cls.world = (WORLD/'hm_brinewick_blockout.gd').read_text()

    def test_original_site_ids_unique_and_unchanged(self):
        ids = [s['id'] for s in self.layout['sites']]
        self.assertEqual(ids, [f'brinewick/site_{i:02d}' for i in range(1, 22)])

    def test_landmark_persistent_ids_are_unique_and_54(self):
        ids = [p['id'] for p in self.landmark['parts']]
        self.assertEqual(len(ids), 54)
        self.assertEqual(len(ids),len(set(ids)))

    def test_cottage_original_nine(self):
        text=(GAME/'tests/test_phase_b_visual.gd').read_text()
        self.assertIn('life.installed.size() == 9',text)

    def test_new_modules_are_real_scene_nodes(self):
        names=['HMPhaseCGroundDetail','HMPhaseCHarbourDressing',
               'HMPhaseCUndergroundDetail','HMPhaseCVillageDressing']
        for name in names:
            with self.subTest(name=name):
                self.assertIn(name+'.new()',self.world)
        self.assertIn('HMPhaseCSurfaceDetail.new()', (WORLD/'hm_brinewick_sites.gd').read_text())

    def test_one_class_per_script(self):
        sources=list(WORLD.glob('hm_phase_c_*.gd'))
        self.assertEqual(len(sources),5)
        for f in sources:
            self.assertEqual(len(re.findall(r'^class_name ', f.read_text(),re.M)),1)

    def test_noncolliding_physical_contract(self):
        for f in WORLD.glob('hm_phase_c_*.gd'):
            with self.subTest(file=f.name):
                s=f.read_text()
                self.assertNotIn('CollisionShape3D.new()',s)
                self.assertNotIn('StaticBody3D.new()',s)
                self.assertNotIn('HMInspectTarget.new()',s)
                self.assertNotIn('HMRecoveredOutput.new()',s)
                self.assertNotIn('collision_layer =',s)

    def test_district_details_owned_by_existing_parts(self):
        s=(WORLD/'hm_phase_c_surface_detail.gd').read_text()
        self.assertIn('body.add_child(art)',s)
        self.assertIn('if body == null',s)
        self.assertNotIn('group.add_child(art)',s)

    def test_ground_detail_parent_and_no_collider(self):
        s=(WORLD/'hm_phase_c_ground_detail.gd').read_text()
        self.assertIn('body.add_child(surface)',s)
        self.assertIn('holder == roads',s)

    def test_seaward_harbour_location(self):
        s=(WORLD/'hm_phase_c_harbour_dressing.gd').read_text()
        self.assertIn('Vector3(-13.4,-1.5,-2.0)',s)
        self.assertIn('brinewick/site_06',s)
        self.assertNotIn('get_yard_station_positions',s)

    def test_protected_detail_avoids_scene_mutation(self):
        s=(WORLD/'hm_phase_c_underground_detail.gd').read_text()
        for zone in ('well_listening','mine_seal','undercroft','bell_house'):
            self.assertIn(zone,s)
        self.assertNotIn('part_id',s)

    def test_dressing_site_coverage_and_neutral_status(self):
        s=(WORLD/'hm_phase_c_village_dressing.gd').read_text()
        self.assertIn('for key: Variant in keys',s)
        self.assertIn('covered_sites += 1',s)
        self.assertNotIn('HMStoryClue.new()',s)

    def test_engine_suite_registered(self):
        t=(ROOT/'tools/test_environment.py').read_text()
        self.assertIn('res://tests/test_phase_c_visual.gd',t)
        self.assertIn('HOLLOWMERE_PHASE_C_VISUAL_OK',t)

if __name__=='__main__':
    unittest.main()
