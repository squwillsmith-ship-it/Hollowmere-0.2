"""Source-only Step21 checks. Engine-side shader/import checks live in test_step21.gd."""
from pathlib import Path
import json, struct, unittest
R = Path(__file__).resolve().parents[1]
BASE = R/'game/assets/materials/step21'
SOURCES = json.loads((R/'art/material_sources/step21_materials.json').read_text())
class Step21Materials(unittest.TestCase):
    def test_all_texels_and_variants(self):
        self.assertEqual(len(SOURCES['materials']), 6)
        for key, spec in SOURCES['materials'].items():
            for channel in ('albedo','roughness'):
                data=(BASE/f'{key}_{channel}.png').read_bytes()
                self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(struct.unpack('>II',data[16:24]),(512,512))
                self.assertLess(len(data), 300_000)
            if 'timber' in key:
                self.assertEqual(spec['family'],'timber')
        self.assertEqual(set(SOURCES['materials']) - {'cream_infill','patched_infill'},
                         {'aged_timber','weathered_timber','dark_timber','salt_grey_timber'})
    def test_glb_source_and_maps(self):
        data=(BASE/'step21_material_swatches.glb').read_bytes()
        self.assertEqual(data[:4], b'glTF')
        self.assertEqual(struct.unpack('<I',data[4:8])[0],2)
        self.assertEqual(struct.unpack('<I',data[8:12])[0],len(data))
        self.assertLess(len(data), 4_000_000)
    def test_prefab_and_save_unchanged(self):
        prefab=(R/'game/scripts/buildings/hm_building_prefab.gd').read_text()
        self.assertIn('HMMaterialLibrary.get_shared',prefab)
        self.assertIn('visual.material_override = material',prefab)
        self.assertIn('"rough_stone"',prefab)
        manifest=json.loads((R/'game/data/v1/buildings/cottage_working_01.json').read_text())
        self.assertGreaterEqual(len(manifest['parts']), 9)
        self.assertIn('fixture/house/curtain', [p['id'] for p in manifest['parts']])
    def test_active_render_and_engine_test(self):
        runner=(R/'tools/test_environment.py').read_text()
        self.assertIn('test_step21.gd',runner)
        self.assertIn('test_step21_capture.gd',runner)
        self.assertIn('step21-materials-',runner)