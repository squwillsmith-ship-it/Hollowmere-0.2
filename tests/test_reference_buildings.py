"""Reference cottage and harbour warehouse are now built from procedural architectural detail profiles."""
import json
from pathlib import Path
from unittest import TestCase
DATA=Path(__file__).resolve().parents[1]/"game"/"data"/"v1"
class ReferenceBuildingProductionTests(TestCase):
 def test_real_cottage_window_apertures_and_disassembly_ids(self):
  c=json.loads((DATA/"buildings/cottage_working_01.json").read_text())
  self.assertEqual(len(c["parts"]),9)
  self.assertEqual({p["id"] for p in c["parts"]},
     {"fixture/house/"+s for s in ("curtain","shutters","cladding","slate_patch","beam","stone_block","front_infill","rear_infill","threshold")})
  front=next(p for p in c["parts"] if p["id"]=="fixture/house/front_infill")
  self.assertEqual(len(front["geometry"]),9)
  self.assertTrue(all(g["detail_profile"]=="patch_plaster" for g in front["geometry"][:8]))
  self.assertEqual(front["geometry"][-1]["shape"],"gable_panel")
  shutters=next(p for p in c["parts"] if p["id"]=="fixture/house/shutters")
  self.assertEqual([round(g["position"][0],2) for g in shutters["geometry"]],[-1.14,1.14])
  roof=next(p for p in c["parts"] if p["id"]=="fixture/house/slate_patch")
  self.assertEqual([g["rotation"][2] for g in roof["geometry"]],[28,-28])
 def test_both_physical_warehouses_have_detailed_surface_profiles(self):
  world=json.loads((DATA/"brinewick_district_builds.json").read_text())
  for name in ("district/old_warehouse","district/expanded_warehouse"):
   s=next(x for x in world["installations"] if x["id"]==name)
   parts=[g for g in s["geometry"] if g.get("removable_part_id")]
   self.assertGreaterEqual(len(parts),40)
   self.assertTrue(all(g.get("detail_profile") in ("weatherboards","framed_bay","slate","patch_plaster","stonework") for g in parts))
   self.assertGreater(sum(g["detail_profile"]=="slate" for g in parts),10)
   for g in parts:
    if g["detail_profile"]=="slate":
     self.assertEqual(g["rotation"][2],27 if g["offset"][0]<0 else -27)
 def test_site_scene_uses_procedural_detail_on_real_inspect_targets(self):
  script=(DATA.parent.parent/"scripts"/"world"/"hm_brinewick_sites.gd").read_text()
  cottage=(DATA.parent.parent/"scripts"/"buildings"/"hm_building_prefab.gd").read_text()
  for t in (script,cottage):
   self.assertIn("HMArchitecturalDetail.decorate",t)
  self.assertIn("extends RefCounted",(DATA.parent.parent/"scripts"/"buildings"/"hm_architectural_detail.gd").read_text())
