"""Runner-independent tests for prospective engine and human evidence gates."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('production_acceptance', ROOT/'tools/production_acceptance.py')
qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qa)


class AcceptancePreparationTests(unittest.TestCase):
    def test_all_live_engine_suites_wired(self):
        self.assertEqual([], qa.runner_assertions())

    def test_ten_distinct_source_viewpoints(self):
        filenames = [x['file'] for x in qa.capture_specs()]
        self.assertEqual(10, len(filenames))
        self.assertEqual(10, len(set(filenames)))

    def test_no_local_source_sha_claimed_as_verified(self):
        from unittest.mock import patch
        with patch.dict('os.environ', {'GITHUB_SHA': 'not-a-sha'}):
            self.assertEqual('UNPINNED_LOCAL_SOURCE', qa.source_ref())

    def test_missing_frames_fail_closed(self):
        with tempfile.TemporaryDirectory() as scratch:
            result, exit_code = qa.inspect_frames(Path(scratch))
        self.assertEqual(2, exit_code)
        self.assertEqual(10, len(result['errors']))
        self.assertFalse(result['human_visual_signoff'])

    def test_bad_frame_is_rejected(self):
        with tempfile.TemporaryDirectory() as scratch:
            p = Path(scratch) / 'phase-e-well.png'
            p.write_bytes(b'PNG' * 4000)
            result, status = qa.inspect_frames(Path(scratch))
        self.assertEqual(2, status)
        self.assertEqual('INVALID', result['frames']['phase-e-well.png']['status'])

    def test_screenshot_metadata_does_not_sign_off_art(self):
        with tempfile.TemporaryDirectory() as scratch:
            p = Path(scratch) / 'real.png'
            from PIL import Image
            image = Image.new('RGB', (1280, 720))
            image.putdata([((x * 13 + y * 3) % 256,
                            (x + y * 7) % 256, (x * 2 + y) % 256)
                           for y in range(720) for x in range(1280)])
            image.save(p)
            info = qa.png_metadata(p)
            self.assertEqual((1280,720), (info['width'], info['height']))
        self.assertFalse(qa.prepare()[0]['human_visual_signoff'])


if __name__ == '__main__':
    unittest.main()