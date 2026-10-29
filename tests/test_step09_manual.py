"""Static architecture guards; actual physics and save tests run in Godot."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(name): return (ROOT/name).read_text(encoding="utf-8")

class Step09Contracts(unittest.TestCase):
    def test_atomic_work_and_durable_save(self):
        t=read("game/scripts/work/hm_work_session.gd").split("func release_once(")[0]
        for required in ('"op": "partial_work"', '"cycles": 1', '"user_initiated": true', 'store.commit(event)', 'HMTransactions.apply(', 'HMRules.can_use('):
            self.assertIn(required,t)
        for forbidden in ('"op": "release"', '"op": "pickup"', 'HMRules.make_outputs(', 'HMLedger.sell_registered('):
            self.assertNotIn(forbidden,t)
    def test_work_requires_physical_hit_every_time(self):
        t=read("game/scripts/main.gd")
        for expected in ('Input.is_action_pressed("hm_work")', 'inspector.probe()', 'work_session.work_once(info', 'work_needs_release', 'work_cooldown', 'current_view != ViewState.PLAYING', 'Input.MOUSE_MODE_CAPTURED'):
            self.assertIn(expected,t)
    def test_no_automatic_release(self):
        t=read("game/scripts/main.gd")
        self.assertNotIn('HMTransactions.apply(',t)
        self.assertNotIn('"op": "release"',t)
    def test_save_is_normal_runtime_only(self):
        t=read("game/scripts/main.gd")
        self.assertIn('not OS.get_cmdline_args().has("--script")',t)
        self.assertIn('work_session.initialize(',t)
        self.assertIn('inspector.work_records',t)
    def test_pinned_godot_engine_suite_is_required(self):
        self.assertIn("test_step09.gd",read("tools/test_environment.py"))
        self.assertIn('("04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17")',read("tools/build.py"))
        self.assertIn('MOUSE_BUTTON_LEFT',read("game/scripts/player/hm_player_input.gd"))

if __name__ == "__main__":
    unittest.main()
