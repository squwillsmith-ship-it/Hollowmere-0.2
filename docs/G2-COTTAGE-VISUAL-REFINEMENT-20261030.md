# G2 cottage — targeted visual repair (30 October 2026)

**Status:** implemented and engine-tested as a corrective asset pass; **not** owner-approved final art or G2 gate completion.

**Verified exact game + authored asset source:** `85a4dd0898e0bd1775236fab2e718c48b3859faf`. This post-QA cleanup commit removes only 155 regenerated Godot `.import` files and extracted duplicate material previews. Asset authoring generated and fully tested on source revision `614a6be58b73e6b012cf360f1e6392050d33b264`; clean owned GLBs + texture maps published in CI followed by cache cleanup.

**Review evidence:** [Before/after comparison](https://drive.google.com/file/d/1jrPBuFCwFSjyEwGY68jRpyBRlBkcHGfd/view), [full reproducible Blender/model/material/test evidence](https://drive.google.com/file/d/1-pZ3UqGL5ri6Yb0C7y58B_jxl4lGnQq1/view).

## Implemented model repairs

1. **Side/cladding/stone:** elongated missing footings replaced with actual 2-course staggered stone perimeter under both side elevations, complete rear and front bays except the doorway. Weatherboarding now starts low enough to overlap its foundation and actually reaches corner trim; latest pass adds restrained exposed horizontal courses, visible vertical battens and a few diagonal timber braces.
2. **Roof:** structural rafters and battens moved below slate and the supporting sarking, eliminating the visually dominant timber ribs on top of the finished roof. The large ridge timber cap is replaced with small slate pieces; tile rows now have subtle nonidentical wear/stagger.
3. **Door:** hanging linen divided into overlapping fold strips with a fuller upper reach, stable door jambs and smaller wood header closing the otherwise visible slot.
4. **Aging / tonal hierarchy:** weathered timber and lime have subtle salt wear and the stone and slate now show restrained tonal variation, maintaining muted 1B/1C and avoiding new blue walls.
5. **Continuity:** all nine original HMInspectTarget part IDs, authoring hierarchy, part-owned GLB root meshes and existing colliders remain authoritative. No new salvage IDs, automation, output values, story changes, or upgrades.

## Validation

- Test [GitHub run 41012911961](https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41012911961) **success**: 71/71 test stages, including G2 imported asset ownership, existing nine-part cottage manual-initiated work and original warehouse regressions, save/reload, and 159 Python checks.
- Independent deterministic geometry checks in `tools/check_g2_cottage_visual_geometry.py` verify actual generated GLBs contain contiguous stone footings under the side walls, overlapping low wall cladding, complete corner join, door/gable height, roof surface spanning two slopes, roof structure below slate, nine owner IDs, 19 authored model GLBs and 8 two-map materials.
- Blender editable master rebuilt from current GLBs and 9 authentic 1280×720 Linux Mesa Forward+/Vulkan rendered screenshots passed (three close camera poses and 6 manual-transaction state frames).
- Real screenshot critique confirmed the formerly dark side-wall gap is filled with stone, the ridge and roof have no large overlay rafters, and later weatherboarding shows individually readably courses and bracing.

## Still unresolved

The current model is a usable and significantly better building-art iteration, **not a final production art approval**. Repeated geometry and some crude ridge/gable intersections remain visible, and heavily dismantled states have coarse remaining rear lime plaster. The warehouse remains provisional, real human-operated keyboard/salvage-hauling walkthrough and native Windows GPU test remain outstanding. Continue the G2 hero-art gate before G3 expansion. No environment trees/loose scenery required at this stage.
