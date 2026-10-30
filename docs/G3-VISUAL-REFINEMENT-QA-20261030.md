# G3 follow-on visual refinement — verified QA, 30 October 2026

## Scope

This recovery-safe child of G3's model-first PR #14 remains in draft PR #15. It refines the same existing village, not a new settlement, gameplay tier, narrative, or salvage system.

- Added `HMG3ArchitecturalSignature`: deterministic lime patches, irregular repaired oak braces, stone bands and selected original-owner roof rake finishing across **eight existing installations**. Every visual lives on the previous static body or individually dismantlable saved part and introduces **zero new colliders, save IDs, loot or automation**.
- Refined the preexisting `HMCoastalProductionSurface` cliff strata with broken, low-poly mineral facets, retaining the same physical terrain and cart road.
- Lowered the default dense overcast fog `0.0031 → 0.0025`, ambient `0.33 → 0.27` and increased directional light `1.02 → 1.12` for muted 1B coastal contrast. Existing G4 atmosphere and story triggers not changed.
- Added `game/tests/test_g3_visual_signatures.gd` to real Godot regression runner.

## Verification — source tested

Official Godot 4.7.2 Linux Forward+/software Vulkan GitHub Actions run
https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41049038602

Exact engine-tested tree SHA `1cf67923f31cdeb1191ec407a60a5af959d3abf0`, with later **screenshot-only** commit `6e880c3a496e26f61325a755b2cc786db39c8b5b`.

- `qa-environment.json`: **83/83 passed**, comprising 76 non-render checks and 7 render/audit checks. New actual Godot visual signature ownership test passed.
- **23/23 real 1280×720 G3 camera frames** across 21 original site markers, night and heavy fog.
- Original **345 manually dismantlable saved part IDs** remained unchanged.
- All six inherited textured GLB sources and new G3 code passed import, save, physics and integration regression.

QA archive in restricted Hollowmere Drive: https://drive.google.com/file/d/1Mz7Mi9kpB2YC2LGT7QtTc1_XOocpMgw4/view

Six-site same-camera review: https://drive.google.com/file/d/1EEn_N1PDenNWdKAjuwcwffJUbksxlhkD/view

The new full-site contact is committed as `art/g3/qa/g3-final-visual-contact-20261030.jpg`.

## Honest visual gate

Actual comparison shows **modest** improvements in roof and façade edges, better relief and some terrain texture variation. The overall village still shows broad empty land, very simple distant building silhouettes and visibly planar terrace edges in several views. **Do not mark G3 fully artistically complete or production-approved.** Next milestone is a more substantially bespoke structure/terrain pass informed by the real screenshots. Per-owner art approval, native Windows GPU and human first-person dismantle/carry walk are still open. G4 draft has not been rebased onto this G3 child.

One-shot CI push trigger is retired in the close-out commit. Original PR #14 and both protected mains remain recoverable.
