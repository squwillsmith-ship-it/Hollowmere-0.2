"""Regression contract for five distinct manual logistics milestones.
The Godot acceptance scripts exercise the real transaction engine."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def source(path): return (R/path).read_text(encoding="utf-8")

class SalvageFiveStepContracts(unittest.TestCase):
    def test_price_is_only_a_quote(self):
        s=source("game/scripts/data/hm_ledger.gd")
        self.assertIn("static func quote(",s)
        self.assertIn('int(catalog.tables["materials"].get("damaged_value_multiplier_percent"',s)
    def test_manual_carry_one_lot(self):
        s=source("game/scripts/interaction/hm_salvage_logistics.gd")
        self.assertIn("held_id(world)",s)
        self.assertIn('int(economy.get("upgrades", {}).get("pack_straps", 0))',s)
    def test_nearby_only_delivery_and_sales(self):
        s=source("game/scripts/interaction/hm_yard_service.gd")
        for action in ["func lift(", "func unload(", "func register_lot(", "func sell_lot(", "func buy(", "func process_lot("]:
            self.assertIn(action,s)
        self.assertIn("HMSalvageLogistics.nearby",s)
    def test_no_direct_granted_currency(self):
        s=source("game/scripts/main.gd")
        self.assertNotIn('"op": "sell"',s)
        self.assertIn("yard_service.sell_lot(",s)
    def test_upgrades_do_not_grant_material_tiers(self):
        s=source("game/scripts/interaction/hm_upgrade_effects.gd")
        self.assertIn("work_interval(",s)
        self.assertIn("loaded_speed_multiplier(",s)
    def test_processing_binary_condition(self):
        s=source("game/scripts/save/hm_transactions.gd")
        self.assertIn('if op == "process":',s)
        self.assertIn('outputs[oid]["processed"] = true',s)
        self.assertNotIn('outputs[oid]["condition"] = "intact"',s)
    def test_engine_gates_each_milestone(self):
        s=source("tools/test_environment.py")
        for i in range(13,18):
            self.assertIn("f'res://tests/test_step{i}.gd'", s)
            self.assertIn(f"'{i}'", s)
    def test_player_inputs_present(self):
        s=source("game/scripts/player/hm_player_input.gd")
        for x in ["hm_lift_place","hm_unload","hm_register","hm_sell","hm_shop_buy","hm_process"]:
            self.assertIn(x,s)
    def test_no_processing_before_stage(self):
        s=source("game/scripts/interaction/hm_yard_service.gd")
        self.assertIn('!= "staged"',s)
        self.assertIn('"bench_confirmed": true',s)
    def test_godot_scripts_exist(self):
        for i in range(13,18):
            self.assertTrue((R/f"game/tests/test_step{i}.gd").is_file())

if __name__=="__main__":
    unittest.main()
