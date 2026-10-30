# G4 — Protected Story Architecture / Initial Implementation
Date: 30 October 2026

## Authority, prerequisites and branch
This is the first G4 story environment art pass, NOT a final G4 landmark or horror sign-off. Base G3 exact Godot-tested code c2611d726680d26cbbc261c34e3fefe1cf4f714e (75/75 suite stages, 21 physical sites + two atmosphere captures; 376/376 tested non-workflow Git blobs). G2 owner-provisionally approved but native Windows and human manual carried-salvage still open. G3 has complete mechanical scene coverage but still conspicuous provisional art in its 21-site QA contact sheet: bare shoreline, sparse village/civic layouts and plain outlying geometry; do NOT mark final G3 art accepted. Existing G3 draft PR #10 and G2 draft PR #9 remain unmerged.

G4 implementation branch: art/g4-protected-story-visuals-20261030, draft PR #12. Protected public/private main not altered. User requested continuing into G4 after G3 engineering work.

## What was actually implemented
- game/scripts/world/hm_g4_protected_story_visuals.gd — HMG4ProtectedStoryVisuals. Installs subtle fitted old stone/wood/iron wear on ORIGINAL protected, colliding architectural owners, never as new salvage targets:
  1. Well rim voussoirs, respecting well aperture and listening route;
  2. Mine posts and roof ties, then weathered seams on permanent closed inner seal (entity still never shown);
  3. Undercroft vault edge and roofless bell-house stone capitals;
  4. Outfall wing walls, tidal mechanism stand clamps, empty escape landing.
- game/scripts/world/hm_brinewick_blockout.gd — hooks G4 visuals into actual Godot stage AFTER the original underground/Phase C physical collision/materials. It has no new audio emitters, story clues, ending work, new part IDs, automatic harvesting or collision shapes.
- game/tests/test_g4_protected_visuals.gd — asserts four protected zones, actual mesh owning old static bodies, original HMUndergroundAudio player/response objects, two finale nodes, 21 original sites, 345 manual salvage IDs and unchanged save validation.
- game/tests/test_g4_visual_capture.gd — first-person approach screenshots of well gallery, mine inner seal, undercroft and bell-house in software Forward+/Vulkan. Corrected camera origins after first visual review: capture must be INSIDE the playable gallery and approach inner seal from smaller X, not shoot outer walls.
- tools/test_environment.py — includes G4 focused test in full world/physics/economy/save regression.

## Verification and limitations
Initial official Godot 4.7.2 Standard test run: https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41021925763 — SUCCESS 76/76 test stages, including existing Python159 and 4 actual real 1280x720 Vulkan snapshots. Initial snapshots exposed poor camera directions; this is a QA view problem, not evidence that underground art is visually acceptable. Focused corrected-camera retest on an isolated QA branch is part of current workflow. Verify its concrete run and screenshots before claiming the correction passed.

G4 art remains EARLY: full mine/gallery readable night/mist lighting, realistic environmental sound placement, player walking/carrying/overhead clearance, all story clue sightlines, protected finale access/physics and both ending transitions still require actual QA and owner art approval. The underground entity stays unseen and horror remains predominantly auditory.
