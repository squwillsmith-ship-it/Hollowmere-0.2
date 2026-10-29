"""Village components: physical targets and catalogued IDs must match 1:1."""
import json
import unittest
from pathlib import Path
D=Path(__file__).resolve().parents[1]/"game"/"data"/"v1"

class BrinewickIntegrationTests(unittest.TestCase):
 def test_authored_geometry_and_stable_save_ids(self):
  installations=json.loads((D/"brinewick_district_builds.json").read_text())["installations"]
  parts=json.loads((D/"sample_parts.json").read_text())["parts"]
  by_id={p["id"]:p for p in parts}
  physical=[]
  for group in installations:
   for geometry in group["geometry"]:
    pid=geometry.get("removable_part_id")
    if not pid:continue
    self.assertIn(pid,by_id)
    self.assertEqual(by_id[pid]["site_id"],group["site_id"])
    self.assertFalse(group.get("protected_story",False))
    physical.append(pid)
  self.assertEqual(len(physical),282)
  self.assertEqual(len(physical),len(set(physical)))
  self.assertEqual(set(physical),{pid for pid in by_id if pid.startswith("village/")})
 def test_no_story_or_service_sale(self):
  installations=json.loads((D/"brinewick_district_builds.json").read_text())["installations"]
  for group in installations:
   if group.get("protected_story") or group["id"] in ("service/landing_pier","service/boatyard_base","harbour/navigation_light"):
    self.assertFalse(any("removable_part_id" in geometry for geometry in group["geometry"] if geometry["name"] not in ("LooseRopeCoil","StormThrownPlankA","StormThrownPlankB","DiscardedRopeEnd","DriftwoodPieceA","DriftwoodPieceB")))

if __name__=="__main__":unittest.main()
