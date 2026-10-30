# G0 — Source recovery checkpoint (30 October 2026)

## Authority and exact source

- **Project:** Hollowmere / Brinewick
- **Repository:** `squwillsmith-ship-it/Hollowmere-0.2` (public QA mirror, NOT the private original).
- **Source commit:** `eddeaef2f92edffc5954b41ccf46ba0847d6955f`
- **Git tree:** `d63029396662b3029201dc289da15b16755f0d74`
- **Recovery branch:** `recovery/g0-art-candidate-eddeaef2-20261030` — checked to point to the exact source SHA.
- **Source inventory:** 219 blobs, 3,716,742 uncompressed blob bytes. Complete per-file `mode / Git blob SHA-1 / size` inventory in `G0-SOURCE-MANIFEST-20261030.json`.
- **Tested source parent:** `45bb1eabd4c6f189aaa08649a7e9a7810f6a57a9`. The clean commit differs ONLY by removing `.github/workflows/hollowmere-art-oneshot-20261029.yml`, verified with GitHub compare. All game/test binaries are unchanged.
- **Test evidence:** https://github.com/squwillsmith-ship-it/Hollowmere-0.2/actions/runs/40958425121 — official Godot 4.7.2 on Linux software Vulkan, 66 genuine PNG frames and substantial engine/Python regression green. **Visual acceptance FAIL**; no real Windows GUI/GPU or manual full teardown signoff.
- **Source archive on Google Drive:** **NOT YET UPLOADED**, because the current assistant runtime cannot transfer GitHub source ZIP bytes to connected Drive; this is explicitly tracked rather than substituting an earlier ZIP.

## Recover an exact and independently verifiable source ZIP

With Python 3.11+ and Git, use this *operations* branch's `tools/recover_g0_source.py` with its same-branch `docs/recovery/G0-SOURCE-MANIFEST-20261030.json`:

```sh
python tools/recover_g0_source.py \
  --manifest docs/recovery/G0-SOURCE-MANIFEST-20261030.json \
  --output Hollowmere-G0-eddeaef2-Source.zip
```

The script clones the dedicated source branch without remote writes, verifies the exact HEAD SHA and Git tree, compares the entire 219-file Git tree against the manifest, reconstructs a binary-preserving ZIP, checks every Git blob hash, tests ZIP CRC/path coverage, and produces a separate `.sha256` file.

The reconstruction code passed a local *synthetic 219-file mixed-binary* test including corrupt-manifest rejection. It **has not** been successfully run against the actual remote source within the assistant session because container DNS access to GitHub is unavailable. Do not mark the finished ZIP as downloaded/uploaded until its bytes and digest have been checked.

To recover source without the script, clone the recovery branch and verify the SHA using Git:

```sh
git clone --branch recovery/g0-art-candidate-eddeaef2-20261030 \
  --single-branch https://github.com/squwillsmith-ship-it/Hollowmere-0.2.git Hollowmere-G0
git -C Hollowmere-G0 rev-parse HEAD
git -C Hollowmere-G0 rev-parse HEAD^{tree}
```

## Safety and promotion conditions

- This checkpoint is a recoverable *working art candidate*, not a polished/released build or a decision to merge draft PR #6.
- PR #5/6 retain their stacked ancestry; operations PR #7 remains independent on public `main`.
- Original private canonical repo, public default `main`, save schema and data have not been modified.
- Never force-push or reuse this recovery branch for active art; branch protection cannot be guaranteed by this recovery marker alone.
- Before fully closing the independent Drive mirror task: run the script on a networked host, compare the resulting ZIP against the 219-file manifest, upload ZIP + SHA256 to the existing restricted Drive `04 - Source Code` folder, fetch it back and re-check digest, then update Index/Status/Handoff.
- G1 may proceed from an isolated **new** branch on the pinned commit without treating pending art acceptance as passed.
