"""Static safety guards; behavioral acceptance requires pinned Godot test_audit_repairs.gd."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
class AuditRepairs(unittest.TestCase):
    def test_migration_is_hash_pinned(self):
        source=(ROOT/"game/scripts/save/hm_save_store.gd").read_text()
        for token in ("_migrate_additive_parts(", "JSON.stringify(old_tables, \"\", true).sha256_text() != previous_hash", "HMSaveState.validate(prior_catalog, old_save)", "HMSaveState.validate(catalog, migrated)"):
            self.assertIn(token,source)
    def test_pose_is_player_scoped(self):
        source=(ROOT/"game/scripts/main.gd").read_text()
        self.assertIn("has_checkpointed_player_pose()",source)
        self.assertIn("POSE_CHECKPOINT_SECONDS",source)
        self.assertIn("checkpoint_player_pose(player.read_pose())",source)
    def test_negative_engine_suite_registered(self):
        source=(ROOT/"tools/test_environment.py").read_text()
        self.assertIn("test_audit_repairs.gd",source)
    def test_original_fixture_data_not_rewritten(self):
        source=(ROOT/"game/data/v1/sample_parts.json").read_text()
        self.assertIn("TEST_FIXTURES_NOT_PLACED_IN_WORLD",source)
