"""Engine-independent static/contract validation for the Step 6 controller.

IMPORTANT: these checks do not simulate Godot's CharacterBody3D or test GDScript.
A pinned-engine test runner lives at game/tests/test_step06.gd.
"""
import math
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / 'game/scripts/player/hm_first_person.gd').read_text()
INPUT = (ROOT / 'game/scripts/player/hm_player_input.gd').read_text()
MAIN = (ROOT / 'game/scripts/main.gd').read_text()
SCENE = (ROOT / 'game/scenes/player.tscn').read_text()
PROJECT = (ROOT / 'game/project.godot').read_text()


class ControllerContractTests(unittest.TestCase):
    def test_preserves_forward_plus_and_scene(self):
        self.assertIn('rendering_method="forward_plus"', PROJECT)
        self.assertIn('run/main_scene="res://scenes/main.tscn"', PROJECT)
        self.assertRegex(PROJECT, r'config/version="0\.0\.(17|20-dev|20-qa)"')
        self.assertTrue((ROOT / 'game/scenes/main.tscn').exists())

    def test_capsule_camera_local(self):
        self.assertIn('type="CharacterBody3D"', SCENE)
        self.assertIn('type="CapsuleShape3D"', SCENE)
        self.assertIn('type="Camera3D"', SCENE)
        self.assertIn('path="res://scripts/player/hm_first_person.gd"', SCENE)
        self.assertIn('collision_layer = 2', SCENE)
        self.assertIn('collision_mask = 1', SCENE)

    def test_manual_movement_and_normalization(self):
        self.assertIn('Input.get_vector', PLAYER)
        self.assertIn('move_and_slide()', PLAYER)
        self.assertIn('flat = flat.normalized()', PLAYER)
        self.assertIn('ground_acceleration', PLAYER)
        self.assertIn('ground_deceleration', PLAYER)
        self.assertIn('velocity.y -= gravity_strength * delta', PLAYER)

    def test_camera_pitch_clamped_and_not_headbobbed(self):
        self.assertIn('clampf(', PLAYER)
        self.assertIn('pitch_limit_degrees', PLAYER)
        self.assertIn('rotate_y(', PLAYER)
        self.assertNotIn('headbob', PLAYER.lower())
        self.assertIn('Input.MOUSE_MODE_CAPTURED', PLAYER)

    def test_all_expected_inputs_present(self):
        for key in ('KEY_W', 'KEY_A', 'KEY_S', 'KEY_D', 'KEY_SHIFT', 'KEY_SPACE'):
            with self.subTest(key=key):
                self.assertIn(key, INPUT)
        self.assertIn('InputMap.has_action', INPUT)

    def test_disabled_state_stops_velocity(self):
        self.assertIn('movement_enabled = enabled', PLAYER)
        self.assertRegex(PLAYER, r'if not enabled:\s+velocity = Vector3.ZERO')
        self.assertIn('if not movement_enabled:', PLAYER)
        self.assertIn('show_menu()', MAIN)
        self.assertIn('pause_stage()', MAIN)
        self.assertIn('resume_stage()', MAIN)
        self.assertIn('Input.MOUSE_MODE_VISIBLE', MAIN)

    def test_world_has_actual_colliders(self):
        self.assertIn('StaticBody3D.new()', MAIN)
        self.assertIn('CollisionShape3D.new()', MAIN)
        self.assertIn('BoxShape3D.new()', MAIN)
        self.assertIn('"SolidGround"', MAIN)
        self.assertIn('"CollisionWall"', MAIN)
        self.assertIn('"RoofBeam"', MAIN)
        self.assertIn('"SupplyCrate"', MAIN)
        self.assertIn('"RoofPlank"', MAIN)

    def test_pose_compatible_with_step05(self):
        self.assertIn('func read_pose()', PLAYER)
        self.assertIn('func restore_pose(', PLAYER)
        self.assertIn('"position": [global_position.x, global_position.y, global_position.z]', PLAYER)
        self.assertIn('"yaw": rotation.y', PLAYER)
        self.assertIn('"position": [0.0, 0.0, 0.0], "yaw": 0.0', (ROOT / 'game/scripts/save/hm_save_state.gd').read_text())
        self.assertIn('is_inf', PLAYER)
        self.assertIn('is_nan', PLAYER)

    def test_no_automatic_salvage_or_economy(self):
        for forbidden in ('HMLedger.', 'HMTransactions.', 'HMSaveStore.', '\"op\": \"pickup\"', 'register_all'):
            with self.subTest(name=forbidden):
                self.assertNotIn(forbidden, PLAYER)
                self.assertNotIn(forbidden, MAIN)

    def test_speed_reference_math(self):
        # A mathematical reference check, not a GDScript runtime assertion.
        forward = (0., -1.)
        diagonal = (1., -1.)
        unit = lambda vec: (vec[0]/max(1., math.hypot(*vec)), vec[1]/max(1., math.hypot(*vec)))
        self.assertEqual(unit(forward), (0., -1.))
        self.assertAlmostEqual(math.hypot(*unit(diagonal)), 1.0)
        self.assertAlmostEqual(math.hypot(*(v*4.4 for v in unit(diagonal))), 4.4)

    def test_ui_has_real_transitions(self):
        for method in ('show_stage', 'show_menu', 'pause_stage', 'resume_stage'):
            self.assertRegex(MAIN, rf'func {method}\(\) -> void:')
        self.assertIn('get_tree().quit(0)', MAIN)
        self.assertIn('HOLLOWMERE_SMOKE_OK', MAIN)
        self.assertTrue((ROOT / 'game/tests/test_step06.gd').is_file())


if __name__ == '__main__':
    unittest.main(verbosity=2)
