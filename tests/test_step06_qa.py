"""Harness contract tests; these do not compile or simulate the Godot runtime."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
ENV_TOOL = ROOT / 'tools' / 'test_environment.py'
spec = importlib.util.spec_from_file_location('hollowmere_test_environment', ENV_TOOL)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class QASetupTests(unittest.TestCase):
    def test_engine_archive_is_exact_official_release_with_fixed_hash(self):
        self.assertEqual(runner.VERSION, '4.7.2.stable')
        self.assertEqual(runner.ASSET, 'Godot_v4.7.2-stable_linux.x86_64.zip')
        self.assertEqual(runner.EXPECTED_SHA256,
                         'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4')
        self.assertTrue(runner.DOWNLOAD_URL.startswith('https://github.com/godotengine/godot/releases/download/4.7.2-stable/'))

    def test_available_runner_knows_real_godot_test_steps(self):
        source = ENV_TOOL.read_text()
        for filename in ['test_step06_physics.gd', 'test_step06_capture.gd']:
            self.assertIn(filename, source)
        self.assertIn("f'res://tests/test_step{i}.gd'", source)
        for phrase in ['subprocess.run', 'returncode', 'marker not in output', 'EXPECTED_SHA256']:
            self.assertIn(phrase, source)

    def test_ci_is_source_controlled_and_read_only(self):
        workflow = (ROOT / '.github/workflows/hollowmere-engine-tests.yml').read_text()
        self.assertIn('permissions:', workflow)
        self.assertIn('contents: read', workflow)
        self.assertIn('actions/upload-artifact@v4', workflow)
        self.assertIn('test_environment.py check', workflow)
        self.assertIn('test_environment.py render', workflow)
        self.assertIn('--install', workflow)

    def test_godot_physics_suite_tests_real_movement_not_only_formula(self):
        tests = (ROOT / 'game/tests/test_step06_physics.gd').read_text()
        for phrase in ['Input.action_press("hm_forward")', 'await physics_frame',
                       'Input.action_press("hm_jump")', 'pause_stage',
                       'HOLLOWMERE_STEP06_PHYSICS_OK']:
            self.assertIn(phrase, tests)

    def test_render_capture_rejects_uniform_image(self):
        source = (ROOT / 'game/tests/test_step06_capture.gd').read_text()
        for term in ['get_texture().get_image()', 'save_png', 'sampled.size() < 3',
                     'HOLLOWMERE_STEP06_RENDER_OK']:
            self.assertIn(term, source)

    def test_wrong_engine_does_not_pass_doctor(self):
        # Mock the version probe instead of executing a POSIX shell script on Windows.
        # This verifies the real runner's fail-closed decision on both operating systems.
        with patch.object(runner, 'find_godot', return_value=str(ENV_TOOL)), patch.object(
                runner, 'log_step', return_value=(True, '4.7.1.stable\\n')), patch.object(
                sys, 'argv', ['test_environment.py', 'doctor', '--godot', str(ENV_TOOL)]):
            self.assertEqual(runner.main(), 3)
        report = json.loads((ROOT / 'build/qa-environment.json').read_text())
        self.assertFalse(report['engine_installed'])
        self.assertFalse(report['engine_tested'])

    def test_missing_engine_cannot_be_claimed_as_successful_check(self):
        with patch.object(runner, 'find_godot', return_value=None), patch.object(
                sys, 'argv', ['test_environment.py', 'check']):
            self.assertEqual(runner.main(), 2)
        report = json.loads((ROOT / 'build/qa-environment.json').read_text())
        self.assertFalse(report['engine_installed'])
        self.assertFalse(report['engine_tested'])


if __name__ == '__main__':
    unittest.main()
