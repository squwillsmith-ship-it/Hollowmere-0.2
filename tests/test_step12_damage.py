"""Source boundaries. Godot Step12 tests actual camera and staged saves."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def read(p): return (R/p).read_text()
class Contracts(unittest.TestCase):
    def test_deliberate_confirmation(self):
        s=read('game/scripts/main.gd')
        for x in ('risk_armed_part','risk_armed_until_ms', 'perform_risky_release_once(', '"armed": true', 'hm_risk_modifier', 'Time.get_ticks_msec()', 'perform_release_once('):
            self.assertIn(x,s)
    def test_limit_and_binary_damage(self):
        s=read('game/scripts/data/hm_support_graph.gd')
        self.assertIn('protected_ids',s)
        self.assertIn('truncated',s)
        t=read('game/scripts/save/hm_transactions.gd')
        self.assertIn('"damaged"',t)
        self.assertIn('local_origin',t)
    def test_no_passive_collection(self):
        s=read('game/scripts/main.gd')
        self.assertNotIn('"op": "pickup"',s)
        self.assertNotIn('"op": "sell"',s)
    def test_engine_gate(self):
        self.assertIn('test_step12.gd',read('tools/test_environment.py'))
        self.assertIn('"12"',read('tools/build.py'))
if __name__=='__main__': unittest.main()
