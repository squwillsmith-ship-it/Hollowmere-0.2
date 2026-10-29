"""Phase B offline/authoring assertions; they do NOT certify Godot rendering."""
from __future__ import annotations
import json
import unittest
from pathlib import Path
import numpy as np
from PIL import Image
from tools.generate_phase_b_surfaces import make_pair

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'game/data/v1'
ASSETS = ROOT / 'game/assets/materials/phase_b'
SURF = json.loads((ROOT/'art/material_sources/phase_b_surfaces.json').read_text())


class PhaseBVisualAuthoring(unittest.TestCase):
    def test_five_reproducible_pbr_pairs(self):
        self.assertEqual(set(SURF['profiles']), {'stone','slate','timber','lime','deck'})
        for key, config in SURF['profiles'].items():
            alb, rough = make_pair(key, config, 512)
            with Image.open(ASSETS/(key+'_albedo.png')) as actual:
                self.assertEqual(actual.size, (512,512))
                self.assertEqual(actual.mode, 'RGB')
                self.assertTrue(np.array_equal(np.array(actual),np.array(alb)),key)
            with Image.open(ASSETS/(key+'_roughness.png')) as actual:
                self.assertEqual(actual.size, (512,512))
                self.assertTrue(np.array_equal(np.array(actual),np.array(rough)),key)

    def test_muted_materials_not_photorealistic_or_metallic(self):
        for key, detail in SURF['profiles'].items():
            self.assertGreaterEqual(detail['roughness'], 0.90)
            with Image.open(ASSETS/(key+'_albedo.png')) as image:
                x=np.asarray(image, dtype=np.uint8)
                self.assertLess(int(x.max())-int(x.min()), 40)
                self.assertGreater(int(x.min()), 210)

    def test_existing_material_and_save_authority_unchanged(self):
        original = (ROOT/'game/scripts/buildings/hm_material_library.gd').read_text()
        self.assertIn('"Step21 material images not imported', original)
        self.assertNotIn('"rough_stone", "grey_slate"', original)
        parts=json.loads((DATA/'buildings/cottage_working_01.json').read_text())['parts']
        self.assertEqual(len(parts),9)
        self.assertEqual(len({p['id'] for p in parts}),9)
        new_parts=json.loads((DATA/'landmark_parts.json').read_text())['parts']
        self.assertEqual(len(new_parts),54)
        self.assertEqual(len({p['id'] for p in new_parts}),54)

    def test_visual_trim_owned_by_catalogue_part(self):
        detail=(ROOT/'game/scripts/buildings/hm_architectural_detail.gd').read_text()
        landmark=(ROOT/'game/scripts/world/hm_village_landmark_art.gd').read_text()
        for marker in ('gable_trim(', 'CornerKnee', 'IronHingeStrap', 'BondedStone_', 'HewnBeamIronPeg'):
            self.assertIn(marker, detail)
        for marker in ('OldInnSignBracket', 'InnFrontLimePier', 'WattleOuterLath', 'AttachedGableOakRake'):
            self.assertIn(marker, landmark)
        self.assertNotIn('HMInspectTarget.new()', detail)
        self.assertIn('var solid: HMInspectTarget = _part_body(parent,title)',landmark)
        self.assertIn('solid.add_child(collision)',landmark)

    def test_runtime_material_wiring_is_present_and_backwards_compatible(self):
        p=(ROOT/'game/scripts/world/hm_settlement_production_art.gd').read_text()
        q=(ROOT/'game/scripts/buildings/hm_building_prefab.gd').read_text()
        r=(ROOT/'game/scripts/buildings/hm_phase_b_materials.gd').read_text()
        self.assertIn('HMPhaseBMaterials.make_tinted(surface_key,Color.WHITE)',p)
        self.assertIn('HMPhaseBMaterials.make_tinted(profile, PALETTE',q)
        self.assertIn('HMMaterialLibrary.get_shared',q)
        self.assertIn('uv1_triplanar = true',r)
        self.assertIn('vertex_color_use_as_albedo = facets',r)

    def test_no_added_salvage_or_narrative_definitions(self):
        # The candidate must change visuals, not balance, quarry/story or tools.
        for filename in ('tools.json','upgrades.json','requisitions.json','story.json','sample_parts.json'):
            self.assertTrue((DATA/filename).is_file())
        self.assertNotIn('HMTransactions.apply(', (ROOT/'game/scripts/buildings/hm_phase_b_materials.gd').read_text())


if __name__ == '__main__':
    unittest.main()
