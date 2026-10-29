# Hollowmere 0.2 — manual QA guide

The repository is a **public, clean-history test mirror**. Its workflow is `workflow_dispatch` only; there are **no** automatic triggers. No testing is implied by uploading files.

## Intended when the owner authorizes execution
1. Select the exact public mirror branch and commit SHA.
2. Start `Hollowmere — manual Godot 4.7.2 QA` from GitHub Actions. Choose whether to include renderer capture.
3. Read the exact runner logs, parser results, Godot/physics assertions, Python tests and screenshot artifacts; do not confuse a generated image with visual approval.
4. For a Windows headless check, select the optional Windows job; for a Windows export, manually start the dedicated Windows export workflow. No build can replace owner-operated GUI/controls/audio acceptance on a real Windows PC.
5. Update internal Drive Development Status/Chat Work Handoff with **what actually passed**, source SHA and renderer, distinguishing OpenGL Compatibility from Forward+/Vulkan.

## Guardrails
- Do not automatically run on `push`, `pull_request`, `schedule`, `pull_request_target` or other events.
- Use `permissions: contents: read` for workflows and avoid secrets entirely.
- Never upload original Git history, complete source bundles or internal Drive documentation as public artifacts.
- Preserve all test evidence with the actual commit SHA, graphics backend and hardware context.
- A successful CI run is **not** a completed 48-step milestone or visual/art signoff.
