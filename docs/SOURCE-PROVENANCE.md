# Hollowmere 0.2 — source provenance and acceptance boundaries

**Date:** 29 October 2026  
**Source candidate:** Visual Rebuild Batch03 (offline, unmerged)  
**Private source ZIP SHA-256:** `38b1cf84de4a553ac44c0de8d1513734f41813b17cb9563ef8c4126287271729`  
**Public mirror import:** 209 selected files, comprising 183 text/config/source files and 26 binary art/material files.

## Public QA mirror intent
This is a *clean-history* manual QA mirror, NOT the canonical development history or a final/released game. The original private repository and restricted Drive workspace retain internal design decisions, original Git history, handoffs, historical archives and testing artifacts. Do not confuse the public mirror's Git commit SHA with the provenance of the previous private source.

## Allowed source scope
Included are the `game/` Godot project and data, `tests/`, `tools/`, editable art/material sources and reference exports, pinned engine version, selected runtime/toolchain documents and third-party notices. Source imported from a separately backed-up, privately archived Batch03 snapshot.

Excluded: original `.git/` ancestry, `history-through-346985b7.bundle`, batch manifests and recovered backup metadata, internal design/progress/reference documents, private Drive shortcuts, historical CI workflow artifacts, full-history backup workflows and any previous PR metadata. A narrow credential-pattern check on the selected files found no matches. This is not a proof of third-party rights or exhaustive expert secret auditing.

## Actual verification status
Earlier corrected Batch02 source was Godot-engine tested with 67/67 stages successful (OpenGL Compatibility capture). New Batch03 geometry/road and clinker-boat edits were only Python/static-tested in the private working archive; they have NOT yet been engine-validated in the public repository. Forward+/Vulkan, native Windows GUI, continuous hauling across all 21 site functions, human visual/audio acceptance and final-release quality are still open.

**No QA workflows, Godot tests or Windows exports have been run on this mirror as part of initial publication setup.** Existing workflows are opt-in `workflow_dispatch` only, with no automatic push/PR triggers.

## Public status and rights
Copyright © 2026 Hollowmere project owner, all rights reserved for original project code and artwork unless explicitly stated otherwise. No general reuse, redistribution or modification licence is granted by public visibility. Third-party Godot notices appear in `docs/THIRD-PARTY-NOTICES.txt`. A comprehensive asset-by-asset licensing review remains necessary before any distribution beyond this development/testing mirror.

## Safe future synchronization
Update this mirror only by selecting and auditing a current restricted-Drive source checkpoint, checking its manifest, preparing a fresh clean import that omits history/internal records, and recording the exact new source archive SHA-256 and test status. Never overwrite a good mirror commit simply because the internal work-in-progress is newer. Do not silently run Actions after pushing.
