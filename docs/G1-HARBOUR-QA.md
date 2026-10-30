# G1 Harbour benchmark — independent visual acceptance pending

**Source base:** eddeaef2f92edffc5954b41ccf46ba0847d6955f (public draft PR #6).
**Branch:** art/g1-harbour-terrain-20261030. Private original and public main must not be modified by this work.

## Implementation
- The lower-terrain rectangular land block is replaced by a deterministic, continuous mesh from coastal seabed to the lower village's pre-existing 2m foundation datum.
- Independent mesh-based collision follows the tidal slope instead of retaining an invisible land box; physics triangles are lower resolution than visual triangles.
- Upper north/south western plateau edges are moved inland and graded through separately colliding rock embankments, leaving the central cart-ramp cutting in place.
- A connected physical earth-and-stone walking corridor leads from the existing quay boardwalk past the working base to the old warehouse and lower cottage. It has its own simplified collision, separate from render subdivisions.
- Quay stone facing is visually supported below its existing permanent deck and remains open at the pier. Existing harbour installations and individually dismantlable building components retain their IDs and ownership.
- The old general-purpose scene art remains for districts not yet rebuilt in G1.

## Independent validation and acceptance
- **Required engine validation**: `godot --headless --path game --script res://tests/test_g1_harbour_route.gd` plus the existing Step25, harbour, production-world and save tests. Use the exact pinned Godot 4.7.2 Standard binary after import.
- **Required render validation**: with software display and Vulkan, set `HOLLOWMERE_G1_CAPTURE_DIR` then run `--script res://tests/test_g1_harbour_capture.gd` at 1280×720. Capture the same five fixed poses against pre-G1 baseline, compare actual frames, and record renderer, SHA, source and art judgement.
- **Required first-person QA**: walk from pier/landing via quay, warehouse door and cottage frontage, using player capsule and carried salvage; check collisions, foundation edges, path seams and shoreline.
- **Gate not accepted** until screenshots have been inspected and the owner approves the visual benchmark. Linux software Vulkan is not Windows GPU or human-play evidence.

## Open risks
- New concave static terrain and colliding route must be parser/engine/physics checked before merge. No new Godot run was made in the authoring session unless evidence is attached separately.
- Mitered joins and coast-road transitions are deterministic authored geometry rather than final Blender/GLB art; refine based on real first-person frames.
- This is the harbour hero district, not 21-site G3 expansion, G2 cottage/warehouse asset production or Windows G7 acceptance.
