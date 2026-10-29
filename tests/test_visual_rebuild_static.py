"""Source-level invariants only. Does not claim Godot or screenshot evidence."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class VisualRebuildSourceContract(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_existing_manual_dismantling_is_not_replaced(self):
        for rel in [
            'game/scripts/world/hm_coastal_foreshore_art.gd',
            'game/scripts/world/hm_phase_c_harbour_dressing.gd',
        ]:
            content = self.read(rel)
            with self.subTest(rel=rel):
                self.assertNotIn('HMRecoveredOutput.new()', content)
                self.assertNotIn('HMInspectTarget.new()', content)
                self.assertNotIn('CollisionShape3D.new()', content)

    def test_stable_collision_backed_vault_replaces_slab_only_for_undercroft(self):
        s = self.read('game/scripts/world/hm_underground_sites.gd')
        self.assertIn('false, false, true)', s)
        self.assertIn('"UndercroftVaultSlope_%d" % side', s)
        self.assertIn('if vaulted:', s)
        self.assertIn('else:\n\t\t_solid(parent, "RockCeiling_', s)
        self.assertIn('collision.shape = shape', s)

    def test_real_player_height_camera_replaces_lowered_beauty_shot(self):
        s = self.read('game/tests/test_phase_e_capture.gd')
        self.assertIn('Vector3(-1.6, 1.43, 2.8)', s)
        default_camera = s.split('"undercroft":', 1)[1].split('"harbour":', 1)[0]
        self.assertNotIn('Vector3(-1.6, 0.84, 2.8)', default_camera)
        self.assertIn('HOLLOWMERE_BEFORE_POSE_PARITY_ONLY', s)
        self.assertIn('phase-e-undercroft-legacy-pose.png', s)

    def test_staggered_coast_without_repeating_grid(self):
        s = self.read('game/scripts/world/hm_coastal_foreshore_art.gd')
        self.assertNotIn('i%47',s)
        self.assertIn('var groups: int = 9 + index % 4', s)
        self.assertIn('var cluster: int = int(i / 8)', s)
        self.assertIn('for i: int in range(94):', s)
        self.assertIn('for i: int in range(12):', s)

    def test_staggered_wallboard_sections_remain_part_owned(self):
        s = self.read('game/scripts/buildings/hm_architectural_detail.gd')
        self.assertIn('running_joint: float', s)
        self.assertIn('"Weatherboard_%02d_%02d"', s)
        self.assertIn('"IronFixingPeg_%02d"', s)
        self.assertNotIn('HMInspectTarget.new()', s)
        self.assertNotIn('CollisionShape3D.new()', s.split('static func _boards(', 1)[1].split('static func _framed_bay(', 1)[0])

    def test_underroof_ribs_are_pitched_not_flat_again(self):
        s = self.read('game/scripts/world/hm_underground_production_art.gd')
        self.assertIn('"UndercroftRakedRib_%d_%d"', s)
        self.assertNotIn('"UndercroftRoofRib_%d"', s)
        self.assertIn('Vector3(at.x,12.43,z)', s)

    def test_cottage_three_stripping_states_are_engine_checked(self):
        s = self.read('game/tests/test_phase_b_visual.gd')
        self.assertIn('half_stripped', s)
        self.assertIn('heavily_stripped', s)
        self.assertIn('life.reconcile(clean)', s)
        self.assertIn('life.recovered.is_empty()', s)

    def test_reference_export_groups_include_weathered_coastal_and_chapel_meshes(self):
        s = self.read('game/tests/export_reference_models.gd')
        self.assertIn('chapel/schoolroom_wing', s)
        self.assertIn('chapel/aldren_study', s)
        self.assertIn('BrinewickCoastalForeshore', s)
        self.assertIn('PhaseCGroundStratification', s)
        self.assertIn('if meshes < 30:', s)

    def test_existing_source_tests_and_unique_names_preserved(self):
        s = self.read('game/scripts/buildings/hm_architectural_detail.gd')
        t = self.read('game/scripts/world/hm_village_landmark_art.gd')
        self.assertIn('WeatheredOakRake_%d',s)
        self.assertIn('VacantToolHanger_%d',t)
        runner = self.read('tools/test_environment.py')
        self.assertIn('test_visual_rebuild_phase1.gd',runner)

if __name__ == '__main__':
    unittest.main()
