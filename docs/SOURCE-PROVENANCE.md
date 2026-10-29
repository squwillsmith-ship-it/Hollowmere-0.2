# Hollowmere 0.2 — public source provenance

**Created:** 29 October 2026  
**Mirror source:** Visual Rebuild Batch03 offline working archive.  
**Original archive SHA-256:** `38b1cf84de4a553ac44c0de8d1513734f41813b17cb9563ef8c4126287271729`  
**Public QA ZIP SHA-256:** `7e56e54ab196e2d17773d1f209a6fc65218f5d3d4614ba0df0eebfc8a8f1a8c9`  
**Public QA ZIP Git blob SHA-1:** `a4179d248c6b47619c2f760c40f3fc945b2e90ae`

This mirror contains a curated source snapshot from the latest archived Visual Rebuild Batch03, not a `git clone` of the original repository. A fresh Git history prevents the original developer branches, commit author metadata, historical workflow artifacts and history bundles from being published in this mirror.

Only runnable source and test dependencies were retained: `game/`, `tools/`, `tests/`, `art/material_sources/`, selected third-party notices, engine-version lock and a per-file SHA-256 manifest. **205 source files** plus one manifest are in the archive. The ZIP was checked for traversal paths, per-file hash consistency and common credential patterns prior to publication. These checks do not certify licensing, complete absence of vulnerabilities or game runtime acceptance.

**Testing status:** no Godot 4.7.2 engine, physics, rendering, Windows GUI, save compatibility or visual sign-off tests were executed as part of this mirror's initial setup. Previous test results belong to separately identified source archives and must not be attributed to this snapshot.

**Workflow policy:** GitHub Actions is manual-only, with no push, pull request or schedule triggers. Each run must cite its source bundle checksum and actual renderer output. Do not add a Git history bundle or unpublished internal project documents to this mirror.

**Sync policy:** The mirror never automatically pulls from the private canonical repository. Update the source ZIP and checksum only from a newly reviewed source snapshot, and retain each source provenance record.
