#!/usr/bin/env python3
"""Step44 offline, dependency-free progression/economy/recovery audit.

No engine, graphics, CI runner, or actual gameplay required. This validates
authored data and a theoretical safe dismantling path. Exact Godot transaction
and player physics checks remain separate gates. No balancing values changed.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1] / "game" / "data" / "v1"
FAMILIES = {"timber", "stone", "fired_clay", "iron", "copper_bronze",
            "fibres", "glass", "mineral_fill"}
TIERS = {"hands": 1, "claw_hammer": 2, "crowbar": 3, "pickaxe": 3, "saw": 4}
ACT_TOOLS = {
    1: {"hands"},
    2: {"hands", "claw_hammer", "crowbar", "pickaxe"},
    3: set(TIERS),
    4: set(TIERS),
}

def read(name: str, root: Path) -> dict:
    return json.loads((root / (name + ".json")).read_text(encoding="utf-8"))

def analyze(root: Path = ROOT) -> tuple[dict, list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    tables = {n: read(n, root) for n in (
        "sample_parts", "landmark_parts", "tools", "materials",
        "upgrades", "requisitions", "story", "locations")}
    parts = tables["sample_parts"]["parts"] + tables["landmark_parts"]["parts"]
    tools = {t["id"]: t for t in tables["tools"]["tools"]}
    materials = {m["id"]: m for m in tables["materials"]["families"]}
    site_ids = {s["id"] for s in tables["locations"]["sites"]}
    story = {s["id"]: s for s in tables["story"]["discoveries"]}
    by_id = {p["id"]: p for p in parts}
    if len(by_id) != len(parts):
        errors.append("Duplicate stable part ID")
    if len(tables["sample_parts"]["parts"]) != 297:
        errors.append("Historical 297 definitions changed")
    if len(tables["landmark_parts"]["parts"]) != 54:
        errors.append("Inn/office must have 54 distinct new component definitions")
    if len(parts) != 351:
        errors.append("Expected 351 total saved part definitions")
    if set(tools) != set(TIERS) or set(materials) != FAMILIES:
        errors.append("Approved tool/family taxonomy drifted")
    if tables["materials"].get("condition_states") != ["intact", "damaged"]:
        errors.append("Salvage condition is not binary")
    rates = {key: int(value["credits_per_unit"]) for key, value in materials.items()}
    if any(v <= 0 for v in rates.values()):
        errors.append("Nonpositive material sale rate")
    raw_discount = tables["materials"]["damaged_value_multiplier_percent"]
    if not (0 <= raw_discount <= 100):
        errors.append("Invalid damaged sale percentage")
    if len(site_ids) != 21:
        errors.append("Canonical location count changed")
    if len(tables["requisitions"]["requisitions"]) != 4:
        errors.append("Expected one requisition per narrative act")
    if not all(x["fixture_only"] for x in tables["requisitions"]["requisitions"]):
        errors.append("Provisional requisitions incorrectly marked final")
    for i, part in enumerate(tables["landmark_parts"]["parts"]):
        if int(part.get("body_index", -1)) != i:
            errors.append("Landmark geometry index does not match stable component order")
        if not part.get("title"):
            errors.append("Landmark component missing geometry label")

    material_units = Counter()
    per_tool = Counter()
    per_site = Counter()
    output_sizes = Counter()
    total_base_credits = 0
    removable = []
    access_aids_used = Counter()
    for part in parts:
        pid = part["id"]
        tid = part.get("tool_id")
        tool = tools.get(tid, {})
        if tid not in TIERS or int(part.get("tier", -1)) != TIERS.get(tid):
            errors.append("Tool/tier mismatch: " + pid)
        if part.get("operation") not in tool.get("operations", []):
            errors.append("Tool/operation mismatch: " + pid)
        if part.get("site_id") not in site_ids:
            errors.append("Unknown salvage site: " + pid)
        if not isinstance(part.get("work_units"), int) or part["work_units"] <= 0:
            errors.append("Invalid manual work requirement: " + pid)
        if not isinstance(part.get("supports"), list):
            errors.append("Missing support graph array: " + pid)
        if not isinstance(part.get("requires_access_aids"), list):
            errors.append("Missing access requirements: " + pid)
        for aid in part.get("requires_access_aids", []):
            access_aids_used[aid] += 1
            if aid != "sling":
                errors.append("No player-operable placement for access aid: " + str(aid))
        for dep in part.get("supports", []):
            if dep == pid or dep not in by_id:
                errors.append("Invalid support reference: " + pid)
            elif by_id[dep].get("building_id") != part.get("building_id"):
                errors.append("Support crosses different buildings: " + pid)
        allocation = part.get("allocation", {})
        restored = Counter()
        suffixes = set()
        for output in part.get("outputs", []):
            suf = output.get("suffix")
            if not suf or suf in suffixes:
                errors.append("Repeated or missing recovered output ID: " + pid)
            suffixes.add(suf)
            qty = 0
            for family, value in output.get("allocation", {}).items():
                if family not in FAMILIES or not isinstance(value, int) or value <= 0:
                    errors.append("Invalid output units: " + pid)
                restored[family] += value
                qty += value
            # The protected harbour bell is a narrative finale fixture, not
            # a manually carried ordinary salvage parcel. Four isolated shed
            # fixtures are engineering-yard-only, not Brinewick loot.
            if not part.get("protected", False) and not pid.startswith("fixture/shed/"):
                output_sizes[qty] += 1
        if dict(restored) != allocation:
            errors.append("Output conservation failure: " + pid)
        if part.get("protected", False):
            continue
        removable.append(part)
        per_tool[tid] += 1
        per_site[part["site_id"]] += 1
        for family, value in allocation.items():
            material_units[family] += value
            total_base_credits += value * rates.get(family, 0)

    # The 4 shed fixtures are deliberately installed ONLY in the isolated
    # engineering yard. Brinewick uses all 282 village definitions, 9 cottage
    # fixtures and 54 landmark parts. Exclude the engineering-only fixtures
    # from actual-world capacity, economy and requisition reachability metrics;
    # retain their definitions for backwards-compatible save/test fixtures.
    engineering_only = [p for p in removable
                        if p["id"].startswith("fixture/shed/")]
    world_removable = [p for p in removable
                       if not p["id"].startswith("fixture/shed/")]
    world_units = Counter()
    world_value = 0
    for part in world_removable:
        for family, amount in part["allocation"].items():
            world_units[family] += amount
            world_value += amount * rates.get(family, 0)
    if len(engineering_only) != 4 or len(world_removable) != 345:
        errors.append("Normal Brinewick and engineering-yard part scope drifted")

    # Detect directed support cycles. Supports means this supporting part must
    # survive until all of its listed dependent pieces are removed.
    visiting, visited = set(), set()
    def visit(pid: str) -> None:
        if pid in visiting:
            errors.append("Structural dependency cycle: " + pid)
            return
        if pid in visited:
            return
        visiting.add(pid)
        for dep in by_id[pid].get("supports", []):
            if dep in by_id:
                visit(dep)
        visiting.remove(pid)
        visited.add(pid)
    for pid in by_id:
        visit(pid)

    # Conservative theoretical safe dismantling under each discovery tier:
    # never force support failure, never dismantle protected architecture.
    reach = {}
    for act, owned_tools in ACT_TOOLS.items():
        active = {p["id"] for p in world_removable}
        selected = []
        # Repeated passes are intentional: unordered component rows can still
        # have a valid acyclic path without relying on source-file ordering.
        while True:
            progress = False
            for p in world_removable:
                pid = p["id"]
                if pid not in active or p["tool_id"] not in owned_tools:
                    continue
                if any(dep in active for dep in p["supports"]):
                    continue
                # The existing sling is player-rigged by direct E interaction.
                # This is a theoretical upper bound, not a claim of navigation QA.
                if any(aid != "sling" for aid in p["requires_access_aids"]):
                    continue
                selected.append(p)
                active.remove(pid)
                progress = True
            if not progress:
                break
        sites = {p["site_id"] for p in selected}
        units = Counter()
        for p in selected:
            units.update(p["allocation"])
        reach[act] = {
            "safe_parts": len(selected),
            "sites": len(sites),
            "units": sum(units.values()),
            "by_family": dict(sorted(units.items())),
            "remaining": len(active)
        }

    # Even with all presently defined tools, every unprotected component must
    # admit some safe structural order using only ordinary player actions.
    if reach[4]["remaining"]:
        errors.append("Some ordinary salvage has no safe player release order")
    for req in tables["requisitions"]["requisitions"]:
        act = int(req["act"])
        available = reach[act]
        allowed = set(req.get("families", []))
        for family in sorted(allowed):
            if family not in FAMILIES:
                errors.append("Unknown requisition family " + family + " in " + req["id"])
            elif world_units.get(family, 0) == 0:
                errors.append("No current Brinewick salvage allocates accepted requisition family " +
                              family + " in " + req["id"] + "; remove this unattainable option or author real salvage")
        matching = sum(v for family, v in available["by_family"].items()
                       if not allowed or family in allowed)
        if matching < req["min_registered_units"]:
            errors.append("Insufficient safe salvage to meet " + req["id"])
        if available["sites"] < req["min_distinct_sites"]:
            errors.append("Insufficient potential recovery sites for " + req["id"])
        for tool in req["required_tool_ids"]:
            if tool not in ACT_TOOLS[act]:
                errors.append("Required tool discovered too late for " + req["id"])
        for flag in req["requires_flags"]:
            if flag not in story or story[flag]["minimum_act"] > act:
                errors.append("Story gate cannot be discovered by " + req["id"])

    # Every output must be manually liftable with current TWO pack_straps
    # upgrades (6 base units, +40% -> floor(8.4) = 8). Require enough
    # early low-capacity salvage for the 12+32 credit purchases; this is
    # potential economy, not a guarantee of walkable physical access.
    max_lot = max(output_sizes, default=0)
    cap_after_upgrades = 8
    if max_lot > cap_after_upgrades:
        errors.append("A salvage lot exceeds maximum manual pack capacity")
    cheap_credits = 0
    for part in world_removable:
        if part["tool_id"] not in ACT_TOOLS[2]:
            continue
        # Independent, safely unloadable parts only; no assumed risky collapse.
        if part["supports"] or part["requires_access_aids"]:
            continue
        for output in part["outputs"]:
            if sum(output["allocation"].values()) <= 6:
                cheap_credits += sum(qty * rates[family]
                                     for family, qty in output["allocation"].items())
    straps = next((u for u in tables["upgrades"]["upgrades"]
                   if u["id"] == "pack_straps"), None)
    total_strap_cost = sum(level["price"] for level in straps["levels"]) if straps else -1
    if total_strap_cost <= 0 or cheap_credits < total_strap_cost:
        errors.append("Early manual salvage cannot afford the capacity upgrades")
    if len(tables["requisitions"]["requisitions"]) == 4:
        if [r["act"] for r in tables["requisitions"]["requisitions"]] != [1, 2, 3, 4]:
            errors.append("Requisition act order drifted")
    max_upgrade_cost = sum(level["price"] for u in tables["upgrades"]["upgrades"]
                           for level in u["levels"])
    if total_base_credits < max_upgrade_cost:
        errors.append("Available salvage cannot ever fund all known upgrades")
    if any("new_capabilities" in u or "tier" in u for u in tables["upgrades"]["upgrades"]):
        errors.append("Upgrade illegally grants a new material tier")

    report = {
        "status": "PASS_STATIC" if not errors else "FAIL_STATIC",
        "engine_verified": False,
        "balance_approved": False,
        "original_definitions": len(tables["sample_parts"]["parts"]),
        "appended_landmark_definitions": len(tables["landmark_parts"]["parts"]),
        "total_definitions": len(parts),
        "ordinary_removable_definitions": len(removable),
        "normal_brinewick_removable_parts": len(world_removable),
        "engineering_yard_only_parts": len(engineering_only),
        "protected_definitions": len(parts) - len(removable),
        "recoverable_units": dict(sorted(material_units.items())),
        # Legacy catalogue-wide figures include 4 isolated engineering-yard
        # fixtures. They are NOT reachable in the normal Brinewick campaign.
        "total_recoverable_units": sum(material_units.values()),
        "maximum_potential_intact_sale_credits": total_base_credits,
        "normal_brinewick_units": dict(sorted(world_units.items())),
        "normal_brinewick_total_units": sum(world_units.values()),
        "normal_brinewick_maximum_intact_sale_credits": world_value,
        "maximum_known_upgrade_spend": max_upgrade_cost,
        "first_two_pack_upgrade_cost": total_strap_cost,
        "unloaded_small_lot_potential_credits": cheap_credits,
        "largest_single_output_units": max_lot,
        "output_sizes": dict(sorted(output_sizes.items())),
        "part_count_by_tool": dict(sorted(per_tool.items())),
        "required_access_aids": dict(sorted(access_aids_used.items())),
        "part_count_by_site": dict(sorted(per_site.items())),
        "safe_reachability_by_act": reach,
        "provisional_requisitions": True,
        "errors": errors,
        "warnings": warnings,
        "caveats": [
            "Legacy total_recoverable_units and maximum_potential_intact_sale_credits include engineering-yard-only fixtures; use normal_brinewick_* for campaign bounds",
            "Cannot prove actual physical path, ray, sling placement, carry, story pacing or human completion",
            "Static maximum credits ignore access, damage, optional processing and travel time",
            "Prices, quota thresholds, processing premium and component allocations are unapproved fixtures",
            "Requires exact-Godot transaction, save, player-path and graphics tests"
        ],
    }
    return report, errors

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, default=ROOT)
    parser.add_argument("--json", type=Path, help="Write repeatable report")
    args = parser.parse_args()
    report, errors = analyze(args.data_dir)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered, encoding="utf-8")
    print(rendered)
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
