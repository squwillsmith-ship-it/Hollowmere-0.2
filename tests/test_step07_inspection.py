"""Static Step07 contract checks. Real Godot physics must also pass CI."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def load(path):
    return (ROOT / path).read_text(encoding="utf-8")

class Step07Contracts(unittest.TestCase):
    def test_target_is_stable_authored_id(self):
        self.assertIn("@export var part_id: String", load("game/scripts/interaction/hm_inspect_target.gd"))
        self.assertIn("catalog.by_part_id(part_id)", load("game/scripts/interaction/hm_inspection_rules.gd"))

    def test_raycast_line_of_sight(self):
        code = load("game/scripts/interaction/hm_inspector.gd")
        for phrase in ("intersect_ray(", "PhysicsRayQueryParameters3D.create", "actor.get_rid()", "interaction_reach", "as HMInspectTarget"):
            self.assertIn(phrase, code)

    def test_never_mutates_salvage(self):
        for path in ("game/scripts/interaction/hm_inspector.gd", "game/scripts/interaction/hm_inspection_rules.gd"):
            code = load(path)
            for forbidden in ("register_unloaded(", "sell_registered(", "release_part(", "make_outputs(", "HMTransactions.", "HMSaveStore."):
                self.assertNotIn(forbidden, code)

    def test_gates_are_explained(self):
        code = load("game/scripts/interaction/hm_inspection_rules.gd")
        for phrase in ("protected_part", "HMRules.can_use(", "Remove these first:", "missing_aids", "Out of reach"):
            self.assertIn(phrase, code)

    def test_integration(self):
        app = load("game/scripts/main.gd")
        for phrase in ("inspection_changed.connect", "set_enabled_inspection(true)", "set_enabled_inspection(false)", "reticle"):
            self.assertIn(phrase, app)
        self.assertIn('KEY_F', load("game/scripts/player/hm_player_input.gd"))
        self.assertIn('test_step07.gd', load("tools/test_environment.py"))
        self.assertIn('("04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17")', load("tools/build.py"))

if __name__ == "__main__":
    unittest.main()
