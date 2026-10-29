# Hollowmere — Nonvisual QA, 29 October 2026

**Source candidate:** Visual Rebuild Batch03 clean public mirror; original private repo and canonical restricted Drive source were not changed.

**Exact game-code test commit:** `849fcda0f2efa6dd90e2f8f3e82fc90942bd7794` on branch `qa/nonvisual-20261029`. This SHA was built and tested on Linux and Windows.

**Final successful run:** https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/40917406744 (all 3 jobs green).

## Tests actually run

- Linux Ubuntu 24.04: Godot 4.7.2 Standard `4.7.2.stable.official.ed1daf0bf`, 68/68 recorded QA stages PASSED; 159 Python regression tests PASSED.
- Windows Server 2022: Godot 4.7.2 Standard `4.7.2.stable.official.ed1daf0bf`, 68/68 recorded QA stages PASSED; 159 Python regression tests PASSED.
- Both runs included real Godot headless import, typed scripts, scene/bootstrap, actual physics, manual targeting/tools/work sessions, modular dismantling/support/damage, carrying/deposits/economy, upgrades, four-act transactions, site/route collision, Brinewick Batch03 integration, legacy and current save migration, Step44 progression/economy and Step45 save recovery.
- Windows export job PASSED: native x86-64 candidate EXE and PCK, independently checked against the four SHA256 entries in its build manifest; package uses the same exact game-code SHA.
- Each platform's machine-readable report contains 68 named test stages, all passing, with `engine_tested=true`, `render_tested=false`. A 69-file log artifact contains the 68 logs plus one report. Expected negative-test messages about missing/wrong Godot versions in the Python log are fixtures, not failing QA.
- No screenshots or visual rendering were requested or executed.

## Issues discovered and corrected

1. Initial CI dependency configuration lacked `scipy` required by modern `trimesh` for generated GLB surfaces, and Windows `py -3` selected Python 3.15 instead of the requested 3.11. Fixed in the isolated QA workflow and the future manually-dispatched workflows; these are test-environment changes.
2. `tests/test_step06_qa.py` expected a private-only workflow path excluded from the clean public mirror. Test now supports either the private or the manual-only public workflow while retaining the source-controlled/read-only assertions.
3. **Actual Batch03 runtime defect**: existing road slabs' `CollisionShape3D` children had auto-generated names, so `HMCoastalRoadWear` reported eight missing original physical road slabs during the Step25 test. Added explicit `shape.name = "CollisionShape3D"` to `HMBrinewickBlockout._box`. No dimensions, physics channels, salvage IDs, save fields, tool progression or story content changed.
4. Reran all tests and Windows export on corrected game-code commit `849fcda0`; all passed. One-shot push-trigger workflow was removed afterward to return the public mirror to manual-only tests.

## Artifacts archived to restricted Google Drive

Under `05 - Builds & Testing`:

- Linux headless logs: https://drive.google.com/file/d/1pxkMjlR3y2uGfQJKaLCBJQ6TlXZjxPL-/view
- Windows headless logs: https://drive.google.com/file/d/1pzn7WGY9gqBoaZZ4xTlHFhM2lb9ieGBR/view
- Windows export package + manifest: https://drive.google.com/file/d/1IDisT1hXuxvbtqPLctLd4xmkRLkoGpnR/view

## Acceptance boundaries

- Pass means the **existing automated nonvisual coverage** passed; not a comprehensive manual end-to-end playthrough.
- Not tested: real graphical Windows game launch, keyboard/mouse feel, gamepad, audio/horror listening and mix, visual reconstruction, true Forward+/Vulkan frames, performance, memory profiling, long-haul traversal by a human or release readiness.
- The public mirror is an isolated testing copy, not the authoritative private development history. The changes remain on the QA branch pending review and sync into the canonical source; the test outcome does not automatically promote Visual Rebuild phases or Steps 44–48 to completed.
- Historical Batch03 offline source SHA256: `38b1cf84de4a553ac44c0de8d1513734f41813b17cb9563ef8c4126287271729`.
