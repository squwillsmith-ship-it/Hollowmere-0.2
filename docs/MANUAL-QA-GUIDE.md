# Hollowmere 0.2 — manual QA guide (integrated production workflow v2)

The public repository is a clean-history **testing mirror**, not the original private canonical repository. Both Actions workflows remain **manual-only** through `workflow_dispatch`. Pushing, creating a PR or editing visual source does not start CI. Source commits and result artifacts must be linked by exact SHA.

## Recommended testing tiers

| Tier | When | Required check | Acceptance limitation |
| --- | --- | --- | --- |
| Q0 — local source check | Every source edit | Static/asset manifest, Python unit tests, data and ID invariants | Does not prove Godot parsed or drew it |
| Q1 — focused engine check | Small integrated functional change | Official Godot 4.7.2 import, focused physics/save tests; use relevant local camera tests where available | Automated green is not visual approval |
| Q2 — visual acceptance candidate | Terrain or building iteration | Same exact player-eye camera, old/new images, real intact and player-dismantled states, access/haul test | Needs human image critique and owner art signoff |
| Q3 — integration milestone | District/asset bundle | Full Godot/Python regression and complete screenshot matrix; run manual QA with capture_frames=true | Linux software Vulkan/OpenGL is not Windows GPU QA |
| Q4 — release signoff | Final Windows candidate | Native GUI/GPU/audio/input/manual all-act playthrough, save recovery and measured performance | A headless Windows export cannot substitute |

The supplied manual QA workflow runs its full engine/data checks even when `capture_frames=false`; the toggle only avoids the additional heavy render stage. Focused Q1 subsets require the existing local/test scripts and should not be described as a faster CI job unless explicitly implemented.

## Using GitHub Actions

1. Confirm target branch and record **full 40-character commit SHA**. Different stacked draft PRs are not interchangeable with main.
2. Manually dispatch **Hollowmere — manual Godot 4.7.2 QA**. The default is no screenshot capture, no Windows job. Set `capture_frames=true` for art/integration review and `windows_headless=true` only when necessary.
3. Inspect Godot editor/import, physics, data, Python results and render logs. Check source SHA, OS, renderer, actual screenshot count and failures; do not transfer older passing evidence to newer source.
4. For a Windows export, manually dispatch **Hollowmere — manual Windows export (unverified GUI)** and inspect the resulting engineering build. This is NOT a user-playtested or Windows GPU-approved candidate.
5. Save selected immutable evidence in restricted Hollowmere Drive before Actions artifact expiry; the QA and successful export artifacts retain 14 days, export failure logs 7 days in the proposed v2 workflow.
6. Only after human review, update the canonical Drive Roadmap, Development Status and Chat Work Handoff. Label implemented-tested, implemented-untested, visually rejected, and accepted separately.

## Production visual gate

The first benchmark is a continuous harbour shoreline → warehouse → cottage route. Improve terrain massing/architecture and actual removable pieces before broad decorative detail. Deliver editable model sources, GLBs, Godot scenes, stable part/visual-owner mapping, source-matched camera comparison, real player-operated teardown, collision/haul tests and preserved saves. A screenshot can be technically valid yet architecturally unacceptable.

## Security / cost controls

- Never add `push`, `pull_request`, `schedule`, `pull_request_target` or other implicit triggers to public workflows without an explicit policy change.
- Keep `permissions: contents: read`, `persist-credentials: false`, no secrets and no upload of private repository history or restricted Drive content.
- Use standard hosted runners for public QA where possible. Minutes may be free, but storage, artifact retention, concurrency and unnecessary reruns still matter.
- Do not merge open PR stacks or overwrite recovery checkpoints without ancestry, exact-source QA and owner review.
- Preserve visual acceptance separately from engine/parser completion. No native Windows GUI, sound or performance approval may be inferred from headless testing.
