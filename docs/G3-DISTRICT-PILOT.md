# G3 second pass — roof geometry, protected chapel gables, expanded architectural site kit

**Owner G2 gate, 30 October 2026:** G2 is now **provisionally approved as a build-on architectural foundation**, not final Windows/human/manual-carry/art signoff. Its tested baseline remains `870cdb5c887c4bf8217aab6075a1ff4a668d15e3`, draft PR9. G3 is explicitly authorised and remains unfinished.

**G3 second-pass tested implementation SHA:** `e956b5d4c004f0defc7b857f1fb7a7b450fb32b6`, child branch `art/g3-district-pilot-20261030` and draft PR10. Canonical 21 site markers, 345 original catalogue-backed manual salvage part IDs, tool tiers, save schema, four-act narrative and two endings unchanged.

## Actual G3 geometry and art changes
- **64 physically oriented roof assemblies corrected**: six canonical building installations `chapel/ordinary_hall` (2), `district/mara_home` (14), `district/upper_cottage_cluster_study` (10), `craft/tomas_workshop` (14), `harbour/office` (12) and `harbour/net_store` (12) had outward-rising pitched roofs. All now slope inward toward the proper ridgeline in the *original collision-backed part*; neither warehouse roof, already correctly sloped, was modified.
- **Chapel structural closure**: fascia seats at the real outer eaves, narrow slate-capped ridge and two solid visually backed protected stone gables close the unsupported opening under the corrected chapel roof. Gables attach to the existing original `SouthEntranceWest` and `NorthEndMasonry` owners, render-only, no new collision/part/story entities. Exact-camera real Godot [before/after](https://drive.google.com/file/d/1EhGyFV-xXsiGpzLPPsf5rd9itCYER8_4/view).
- **Six additional architecture profiles added to existing original owners**: `service/landing_pier`, `service/boatyard_base`, `district/upper_cottage_cluster_study`, `chapel/schoolroom_wing`, `chapel/aldren_study`, `harbour/navigation_light`. These extend the earlier five pilots to **11 installations across 10 distinct sites**, with local pier bracing, boatyard shelter trim, upland frames, schoolroom entrance, protected study edging and navigational masonry supports. They are restrained 1B/1C noncolliding Godot visual detailing, **not** finished new Blender-authored G3 hero GLBs. They are owned by original static/removable bodies and disappear automatically where their original manually salvaged owners are released.
- **Inspection improvements:** unchanged initial cameras retained where useful; office camera moved outside old warehouse, chapel shown from a readable gable angle, study, schoolroom and beacon reframed in `game/tests/test_g3_pilot_capture.gd`.

## Test evidence — verified, not artistic acceptance
- Official pinned **Godot 4.7.2 Standard** Linux Mesa Forward+/Vulkan [run #41019089753](https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41019089753) **SUCCESS: 74/74 full QA stages** including 159 Python regression cases, physics, actual 64 individual roof-body rotations/collider extents, G3 11-installation/10-site ownership tests, original 21 sites and 345 salvage IDs.
- **11 genuine 1280×720 Vulkan site screenshots** independently PNG pixel validated in same run; rendered from actual game, no composited/synthetic model substitutions. **372/372 non-workflow Git blob SHAs** match source and isolated run branch exactly.
- [Full run's 11 screenshots, import logs, engine QA archive](https://drive.google.com/file/d/10bI2mkSvH_9pQXHbrg-6Q6_WL9ZZQ0JB/view), [11-site visual review](https://drive.google.com/file/d/13yVn2kxqKofyzOnWUlXgdXBjE079mm36/view), [real chapel before/after](https://drive.google.com/file/d/1EhGyFV-xXsiGpzLPPsf5rd9itCYER8_4/view).

## Visual acceptance status and next work
G2 **owner PROVISIONALLY APPROVED**, not final. G3 **SECOND PASS IMPLEMENTED + ENGINE TESTED**, **NOT final G3 approval**. Ten sites have recognizable local architecture treatment, the other 11 still need coordinated silhouette/art/haul-route attention. Screenshots show many other provisional original blockout surfaces and especially a schoolroom shot partly obscured by neighbouring roofing; contact sheets are evidence, not aesthetic signoff. Continue G3 waterfront/civic/upland/industrial coherent exterior art and placement, lighting/fog/day-night, manual player walking/carrying, Windows hardware acceptance, and production-quality bespoke meshes where warranted. Do not add blue walls, reveal the entity, or automate dismantling. Keep draft PR unmerged until owner approves.

---

# G3 five-site architectural pilot — 30 October 2026

**Source:** `art/g3-district-pilot-20261030`, initial tested code SHA `13dea08652f37941524c2f785d7376d3e21feeda`. Parent: G2 engineered/repaired source `870cdb5c887c4bf8217aab6075a1ff4a668d15e3`, in draft PR #9 (never merged to public/private main).

**Scope:** G3's complete roadmap covers coherent 21-site settlement art plus waterfront/civic/upland/industrial traversal, special silhouettes, day-night-fog views and dismantling. This commit only starts G3 with five directly implemented world architectural pilots:
- Harbour office at site03, salt-worn ledger-room framed openings
- Net store at site06, diagonal supports for actual drying frames
- Tomas's workshop at site11, reinforced workshop corner frames
- Chapel ordinary hall at site13, restrained protected masonry string courses
- Mara's dwelling at site08, irregular repaired infill braces

Each pilot mesh is non-colliding and attached to an existing original `StaticBody3D` or `HMInspectTarget`. Nothing changes the story canon, narrative triggers, manual work, catalogue-backed 345 saved part IDs, physical collision, binary damage values or the 21 canonical site positions.

**QA:** [Official pinned 4.7.2 Godot run #41015740431](https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/41015740431) passed **73/73 full QA stages**, including original 159 Python checks and new G3 21-site/345-owner tests, and captured **5/5 authentic software Forward+/Vulkan 1280x720 site images**. Git comparison confirms the QA runner and source match **370/370 non-workflow source blobs** exactly. One-shot QA workflow removed after pass. [Full QA render/log archive](https://drive.google.com/file/d/1UHr16kpN9y3CXwQoC97jbcGyuXr-v4Iy/view) | [five-view visual contact sheet](https://drive.google.com/file/d/1mfRCGlXz_y4BUIzo2LwB_odzN5GxodWu/view).

**Aesthetic verdict:** The new accents help establish distinct local identities but remain pilot geometry. The original chapel roof projection in its screenshot is still visibly excessive and badly grounded to the roof shell, not a closed visual gate. Other 16 sites remain provisional, no bespoke G3 Blender/GLB district kit, whole-village visual acceptances or native Windows GPU/human manual carry playthrough. Don't confuse five green frame captures with full 21-site G3 approval.

**Next ordered G3 tickets:** 
1. G3-A waterfront: chapel/office/net-store/boatyard/jetty architectural coherence and scale, correcting roof silhouette and elevation joins.
2. G3-B civic: chapel, schoolroom, study exterior/story continuity; keep sacred narrative and protected elements unchanged.
3. G3-C upland: Mara's home, upper cluster and hillside path, varied building silhouettes and safe carry approach.
4. G3-D industrial: workshop, warehouses, mine-related sites and plausible haul access.
5. G3-E integration: all 21 wide/eye/day/fog/night views, manual salvage interactions, Windows real GPU, owner review.

**User authorization:** User requested completing remaining G2 model fixes and moving to G3, not unconditional final acceptance of G2 or G3 visual quality.
