"""Structural guards; full release/physics/save tests run inside pinned Godot."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(p):return (ROOT/p).read_text(encoding="utf-8")

class Step10Contracts(unittest.TestCase):
    def test_separate_release_is_manual_only(self):
        code=read('game/scripts/work/hm_work_session.gd')
        for x in ('func release_once(', '"user_initiated": true', '"op": "release"', 'confirm_risk: bool = false', 'HMRules.inspect_release(', 'store.commit(event)'):
            self.assertIn(x,code)
    def test_recoverable_outputs_are_physical_but_not_auto_collected(self):
        code=read('game/scripts/interaction/hm_part_lifecycle.gd')
        for x in ('HMRecoveredOutput.new()', 'installed', 'recovered', 'world_released', 'staged', 'collision_layer = 1', 'reconcile(state: Dictionary)'):
            self.assertIn(x,code)
        for forbidden in ('"op": "pickup"', '"op": "sell"', '"op": "register"', '"op": "unload"'):
            self.assertNotIn(forbidden,code)
    def test_saved_stable_provenance_and_no_duplication(self):
        code=read('game/scripts/save/hm_transactions.gd')
        for x in ('"spawn_origin"', '"position"', '"world_released"', 'HMRules.make_outputs'):
            self.assertIn(x,code)
        self.assertIn('recovered.has(', read('game/tests/test_step10.gd'))
        self.assertIn('HMSaveState.validate(catalog, b.state)', read('game/tests/test_step10.gd'))
    def test_validated_physical_interaction_input(self):
        code=read('game/scripts/main.gd')
        for x in ('perform_release_once(', 'request_release(', 'inspector.probe()', 'lifecycle.reconcile(toolbelt.state)', 'pending_release', 'current_view != ViewState.PLAYING'):
            self.assertIn(x,code)
        self.assertIn('KEY_R', read('game/scripts/player/hm_player_input.gd'))
    def test_ci_gates(self):
        self.assertIn('test_step10.gd',read('tools/test_environment.py'))
        self.assertIn('("04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17")',read('tools/build.py'))

if __name__ == '__main__':unittest.main()
