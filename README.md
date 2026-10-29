# Hollowmere 0.2 — public QA mirror

A **clean-history, public testing mirror** for the in-development Godot game *Hollowmere*, set in Brinewick. This is a **development snapshot**, not a stable release or proof of completed visual/gameplay QA.

## Current source

- Snapshot: **Visual Rebuild Batch03 (29 October 2026)**, from the private working-source archive.
- Source bundle: [`source/Hollowmere-0.2-Batch03-public-QA-source.zip`](source/Hollowmere-0.2-Batch03-public-QA-source.zip)
- SHA-256: `7e56e54ab196e2d17773d1f209a6fc65218f5d3d4614ba0df0eebfc8a8f1a8c9`
- Contents: **205 source files** (plus one SHA-256 manifest): `game/`, `tools/`, `tests/`, `art/material_sources/`, required runtime assets and minimal notices.
- Excludes: the original Git history, historical Actions artifacts, private production plans, draft documentation, private Drive links and recovery bundles.

The bundle contains an actual Godot project at `game/project.godot`. Extract it locally to access the source tree. The separate **canonical private development repository** and Google Drive are intentionally not linked or synchronized automatically.

## Automated testing

[Manual-only Godot QA](.github/workflows/manual-godot-qa.yml) is configured with **`workflow_dispatch` only**. Commits and pull requests never start tests automatically.

When deliberately launched, the job first verifies the source archive and its per-file SHA-256 manifest, then prepares the pinned Godot 4.7.2 Standard environment, performs real engine and Python checks, attempts rendering, and saves diagnostics. Tests **have not been run on this Batch03 mirror** as part of setup. Software-rendered images do not establish Forward+/Vulkan or Windows GUI acceptance.

For manual local development, unzip the source bundle into a fresh directory and open `game/project.godot` in Godot **4.7.2 Standard**. See the included `docs/PLAYER-README.txt` for controls.

## Copyright and third-party notices

Copyright © 2026 Hollowmere project owner. All rights reserved for original code, visual art, game data, story and assets unless otherwise expressly indicated. **Public access does not constitute an open-source licence or permission to redistribute or commercially reuse project materials.** The source bundle retains applicable third-party notices.

## Status

Mirror staging only: no workflows, test suites, engine runs, releases or deployment have been triggered. The public mirror is a deliberately separate snapshot; the original repository remains private.
