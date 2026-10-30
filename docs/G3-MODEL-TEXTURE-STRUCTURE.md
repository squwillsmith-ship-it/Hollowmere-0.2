# G3 — Model → Texture → Structure (30 October 2026)

This is a **new isolated, recoverable draft implementation**, not final G3 art acceptance.

## Reusable authored models first
Six real glTF 2.0 binary (GLB) unit-envelope architectural models:
- stone wall courses oriented along x and z
- staggered salt-worn timber boarding along x and z
- framed/diagonally braced lime infill panels along x and z

Geometry is UV-mapped and face-normalled with individually authored lapped panels, staggered stone courses and braces, not cosmetic flat colours over unchanged box faces. GLB meshes can be imported into Blender for editing; `art/g3/kit_manifest.json` preserves the authored model variants, source manifest and their Git object identifiers. **Native Blender .blend files are not yet provided for this G3 set**.

## Materials second
Three new 128×128 PBR texture pairs: fieldstone, weathered oak and lime. Authored albedo and glTF ORM source PNGs are in `game/assets/materials/g3`; the corresponding textures are embedded in their own GLB surfaces for predictable imports. Muted 1B Balanced Facets colour grades and low-contrast 1C wear only. These supplement rather than delete the completed G2 textures/112 GLBs.

## Full existing structures third
`HMG3TexturedStructureAssembly` reads the original 21-site district manifest, selects wall/frame/pier/masonry part owners at ten existing installations, assigns the proper orientation and scales the unit GLB model to exact ORIGINAL render/collision dimensions, hides only old box skins, and leaves the collider-backed physical owners intact. All original 345 saved IDs and manual dismantling rules are unchanged. G2 hero assets and 64 roof owners are explicitly preserved; no new automatic collection, blocked entrance, fabricated plot object or building site is introduced.

## Scope and validation
- Implemented code: `game/scripts/world/hm_g3_textured_structure_assembly.gd`
- Integrated into `hm_brinewick_sites.gd` after G3 original roof layer.
- New actual-engine ownership suite `test_g3_model_texture_structure.gd` registered in `tools/test_environment.py`. Assert six imported variants, ten original installations, collider/saved ID continuity, and GLB scene imports.
- This branch has **not yet passed Godot 4.7.2 execution / visual screenshot review / native Windows human carry route**. Do not call it production-approved; earlier 75/75 results apply to its verified G3 parent, not to these changes.
- Next: run pinned manual QA from this branch, inspect 21 site day/fog/night, repair any import/material seams, then obtain owner art approval. G4 draft PR12 is based on an older G3 parent and needs careful integration afterward.

## QA-driven corrective material and evidence pass — 30 October 2026

First pinned Godot 4.7.2 QA run on G3 new GLB branch #41031156815 found four boatyard shelter owners were named with normalized decimal points; the first suite stopped at the original step-25 scene construction. Fixed with direct owner/shape/offset resolution, preserving the original four physical bodies and no new IDs. Follow-up run #41031619601 passed the **entire Godot engine suite and new imported model/owner test**. It produced 23 genuine 1280x720 Vulkan site/night/fog PNGs. Actual rendered frames identified overly orange/flat wall surfaces and repeated remote massing. The G3 material palette is now made more salt-weathered and low-chroma: RGB wood baseline (95,89,81), stone (111,110,101), lime (179,172,158), with authored fine weathering; identical updated PNG albedo is embedded into every affected glTF scene. G3 image style still not accepted as final. An additional Python test asserts embedded/source texture parity. The screenshot QA report also now retains previously verified test outcomes when the render action writes its report. Rerender/retest new palette required. G4 branches are not merged, protected mains preserved.


## Verification close-out — 30 October 2026 (same G3 code and asset tree)

- Initial new-GLB engine QA https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41031156815 exposed four boatyard shelter-post lookup warnings. Resolved by direct original-body matching with position/shape fallback, preserving the original static physics bodies. The initial run is correctly recorded as FAILED, not counted as green.
- Model-owner/physics correction Godot 4.7.2 run https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41031619601 PASSED its full regression suite and 23 actual site/night/fog PNGs; its images showed over-warm timber and residual blockout.
- Final muted albedo/embedded GLB parity and report-retention pass Godot 4.7.2 CI https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41033465811 SUCCESS: `qa-environment.json` recorded **82/82 successful checks including 75 non-render checks and 7 rendering/audit checks**; separate direct G3 capture produced **23/23 original-site/night/fog Vulkan PNGs**. New GLB test output `HOLLOWMERE_G3_MODEL_TEXTURE_STRUCTURE_OK owners_preserved=345 models=6`. Latest runtime materials, original part ownership, collisions, catalogue and save tests all passed. The tests were performed using the **real pinned official Godot 4.7.2** on Linux software Forward+/Vulkan, not native Windows GPU.
- Test archive stored on restricted Google Drive: https://drive.google.com/file/d/1Eyl0pNpyiDS55fPc6x8WIWyI2Ac_Gc5H/view ; actual same-camera material before/after https://drive.google.com/file/d/1ET-QqhUU1xqvDHDfs70FUYyBqb5LFAp_/view . 21-site contact image stored under `art/g3/qa/g3-model-rebuild-contact-20261030.jpg` in the draft source branch.
- Corrected G3 faces remain at **10 original installations / 122 existing structural sections** (104 pre-existing manually removable, 18 original static). All 345 saved IDs still present. **G1/G2 provisionally approved status preserved.**
- Remaining art limitations despite green QA: oversimple distant building silhouettes, overly planar coast/terraces, some exposed large flat panels and overly low-contrast daytime atmosphere. Native Windows physical GPU and real-human first-person carry/removal route plus G3 owner final art approval remain OPEN. G3 should not be marked completed or accepted. G4 PR12 remains on an older G3 branch and requires a careful source integration pass.
- One-shot push-trigger QA workflow was removed once evidence was captured. Existing manual QA remains available. Historical test commit `7b893f0c4b67697844a5cd50edca2a5f768bc613` and later screenshot-only commit retain the exact tested source for recovery; protected public/private mains remain unchanged.
