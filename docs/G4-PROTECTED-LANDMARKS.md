# Hollowmere — G4 protected-story visual composition, initial implementation

**30 October 2026.** Owner: "Finish G3 then start G4." This is the first actual code/visual G4 implementation, **not G4 completion or owner approval**. G1 and G2 are owner-provisionally approved, final manual/Windows QA open. G3 established all 21 original site contexts and retained all 345 original salvage IDs, source `d91ce1ca1ef71e781ba9114870d17d62e52eefac`, official [G3 run #41020819075](https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41020819075) **74/74 tests and 23 actual Vulkan frames**. G3 wide-scene art remains aesthetically open after real screenshot review. G3 parent draft PR #10 unmerged.

## G4 actual implementation

- `game/scripts/world/hm_g4_protected_composition.gd` attaches only low-poly noncolliding stone, timber and **3 subtle indirect practical light nodes** to the existing protected `HMUndergroundSites` owner tree. Exactly seven location IDs preserved: `well_listening`, `mine_seal`, `undercroft`, `bell_house`, `containment_machine`, `tide_outfall`, `escape_berth`.
- The gallery is edged without blocking descent; mine frames sit along original walls and do not intrude into the sealed corridor; the undercroft gets wall-edge trim but no mid-height ceiling slab; the bell house stays roofless; tidal apparatus remains an existing manually operated quest mechanism, not passive harvesting; the berth stays ambiguous about Mara's survival.
- `game/scripts/world/hm_brinewick_blockout.gd` integrates this after canonical underground, campaign and original audio structures load. `game/tests/test_g4_protected_composition.gd` verifies **seven** original noncolliding architectural groups, **three** low-energy lights, same two original finale choices, 10+ evidence clues, existing auditory beds/responses, unchanged **345** salvage owners and **21** site markers. `game/tests/test_g4_protected_capture.gd` renders **seven authentic Vulkan frames**. The G4 full test is registered with `tools/test_environment.py`.

## QA

Official pinned **Godot 4.7.2 Standard**, software Forward+/Vulkan [run #41021592036](https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41021592036) **SUCCESS 75/75 regression stages**, including the new G4 preservation test and prior G3/G2 world/physics/salvage/story tests, with **7/7 genuine 1280×720 G4 images** passing PNG and pixel variation checks. The isolated QA-run Git tree matched the source at **378/378 non-workflow blob SHAs**. Engine-tested source SHA: `bf14f9a9807117be7d1b83f962c8bce5e5910e58`.
- [Verified full G4 logs and Vulkan screenshots on restricted Google Drive](https://drive.google.com/file/d/1NNv9Tja43v4nJIQD8xt2TMmK35jEVTkK/view)
- [Seven original Godot scene captures visual review](https://drive.google.com/file/d/1uvjn9RxOBRdw6hy1CD-J0CWi0IBWbnRu/view)

**G4 visual audit:** The mine/well stone textures and overhead surface currently read too brightly from this test renderer; the undercroft camera shows a foreground obstruction rather than a suitable inspection of vault clearance. Correct next. Remaining G4 tickets: human-scale approach and overhead collision for mine gallery, well descent/undercroft; distinct close/long/night/fog shots and a true listening/audio spatial review; preserve two finale work targets and subtle horror with no direct entity representation. Renderer pass != listening/player validation. `HMG4ProtectedComposition` is a controlled start, not yet production-final.

**Branch:** `art/g4-protected-landmarks-20261030`, draft PR #11, child of G3 tested code. Neither protected public nor private `main` has been modified.
