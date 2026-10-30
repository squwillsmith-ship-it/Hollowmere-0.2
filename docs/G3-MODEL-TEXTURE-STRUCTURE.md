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
