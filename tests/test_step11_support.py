"""Step11 structural QA; pinned Godot suite tests actual collision and rules."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def source(p): return (ROOT/p).read_text()
class Contract(unittest.TestCase):
    def test_source_authority(self):
        g=source('game/scripts/data/hm_support_graph.gd')
        self.assertIn('class_name HMSupportGraph',g)
        self.assertIn('func direct_dependents(',g)
        self.assertIn('func cascade(',g)
        self.assertIn('func release_diagnostic(',g)
        self.assertIn('protected_ids',g)
    def test_no_automatic_damage(self):
        g=source('game/scripts/data/hm_support_graph.gd')
        for name in ('HMTransactions.apply(', '"op": "release"', 'queue_free(', 'HMLedger'):
            self.assertNotIn(name,g)
    def test_rules_share_graph(self):
        self.assertIn('HMSupportGraph.release_diagnostic(',source('game/scripts/data/hm_rules.gd'))
        self.assertIn('HMSupportGraph.release_diagnostic(',source('game/scripts/interaction/hm_inspection_rules.gd'))
    def test_engine_suite_required(self):
        self.assertIn('test_step11.gd',source('tools/test_environment.py'))
        self.assertIn('"11"',source('tools/build.py'))
if __name__=='__main__':unittest.main()
