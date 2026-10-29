"""Non-engine architecture regression. Pinned Godot tests must also run."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def src(p):return (ROOT / p).read_text(encoding="utf-8")

class Step08Contract(unittest.TestCase):
    def test_step05_atomic_discovery(self):
        t=src("game/scripts/tools/hm_toolbelt.gd")
        for expected in ("HMTransactions.apply(", '"op": "find_tool"', '"user_initiated": true', '"source": "world_discovery"', "HMSaveState.fresh(", "select_slot", "cycle("):
            self.assertIn(expected,t)
    def test_selected_not_tier_only(self):
        t=src("game/scripts/interaction/hm_inspection_rules.gd")
        self.assertIn("[selected_tool_id]",t)
        self.assertIn("HMRules.can_use(",t)
        self.assertIn("Select ",t)
    def test_discovery_camera_and_user_gate(self):
        t=src("game/scripts/interaction/hm_inspector.gd")
        self.assertIn("aimed_tool_pickup(",t)
        self.assertIn("interaction_reach",t)
        app=src("game/scripts/main.gd")
        self.assertIn("request_find_tool(",app)
        self.assertIn("current_view == ViewState.PLAYING",app)
        self.assertIn("toolbelt.find_from_world(",app)
        self.assertIn("toolbelt.select_slot(",app)
    def test_tools_not_granted_by_upgrade_or_auto_pickup(self):
        t=src("game/scripts/tools/hm_toolbelt.gd")
        self.assertNotIn('HMLedger.purchase(',t)
        self.assertNotIn('"op": "purchase"',t)
        self.assertNotIn("HMRules.make_outputs",t)
    def test_mandatory_engine_gate(self):
        self.assertIn("test_step08.gd",src("tools/test_environment.py"))
        self.assertIn('("04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17")',src("tools/build.py"))
    def test_registered_input(self):
        t=src("game/scripts/player/hm_player_input.gd")
        for key in ("KEY_Q", "KEY_E", "KEY_1", "KEY_2", "KEY_3", "KEY_4", "KEY_5"):
            self.assertIn(key,t)

if __name__=="__main__":
    unittest.main()
