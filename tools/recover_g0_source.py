#!/usr/bin/env python3
"""Reconstruct the exact G0 source ZIP from immutable Git blobs (Python 3.11+; git).

Requires sibling docs/recovery/G0-SOURCE-MANIFEST-20261030.json from this
operations branch. No GitHub Actions, repository writes or secrets required.
"""
import argparse
import hashlib
import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

REPO = "https://github.com/squwillsmith-ship-it/Hollowmere-0.2.git"
REF = "recovery/g0-art-candidate-eddeaef2-20261030"
SHA = "eddeaef2f92edffc5954b41ccf46ba0847d6955f"
PRIVATE_REPO = "https://github.com/squwillsmith-ship-it/Hollowmere.git"
PRIVATE_REF = "recovery/g0-eddeaef2-exact-tree-20261030"
PRIVATE_SHA = "0fa7a8c917606219c6591de4c4282b1e3ad34928"


def git(cwd: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(cwd), *args], stderr=subprocess.PIPE)


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def recover(repo_url: str, manifest_path: Path, output: Path, *,
            ref: str = REF, expected_commit: str = SHA) -> dict:
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    if m.get("format") != "hollowmere-g0-source-manifest-v1" or m.get("source_commit") != SHA:
        raise ValueError("Wrong recovery manifest or source SHA")
    expected = {f["path"]: f for f in m["files"]}
    if len(expected) != len(m["files"]) or len(expected) != 219:
        raise ValueError("Duplicate or missing source paths")
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="hollowmere-g0-") as td:
        dest = Path(td) / "repo"
        subprocess.run(["git", "clone", "--quiet", "--single-branch", "--branch", ref,
                        "--depth", "1", "--no-checkout", repo_url, str(dest)], check=True)
        head = git(dest, "rev-parse", "HEAD").decode().strip()
        tree = git(dest, "rev-parse", "HEAD^{tree}").decode().strip()
        if head != expected_commit or tree != m["source_tree_sha"]:
            raise ValueError(f"Source ref mismatch: commit={head} tree={tree}")
        actual = {}
        for row in git(dest, "ls-tree", "-r", "-z", "--long", "HEAD").split(b"\0"):
            if not row:
                continue
            meta, raw_path = row.split(b"\t", 1)
            mode, kind, sha, size = meta.decode("ascii").split()
            path = raw_path.decode("utf-8")
            if kind != "blob":
                raise ValueError("Unexpected nonblob tree entry")
            actual[path] = {"path": path, "mode": mode, "blob": sha, "size": int(size)}
        if actual != expected:
            raise ValueError("Git tree does not match the complete G0 manifest")
        with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            for path in sorted(expected):
                if path.startswith("/") or ".." in Path(path).parts or "\\" in path:
                    raise ValueError(f"Unsafe source path: {path}")
                raw = git(dest, "show", f"HEAD:{path}")
                if len(raw) != expected[path]["size"] or git_blob_sha(raw) != expected[path]["blob"]:
                    raise ValueError(f"Git blob mismatch: {path}")
                z.writestr(path, raw)
        with zipfile.ZipFile(output) as z:
            if z.testzip() is not None or set(z.namelist()) != set(expected):
                raise ValueError("ZIP CRC/path verification failed")
            for path, entry in expected.items():
                if git_blob_sha(z.read(path)) != entry["blob"]:
                    raise ValueError(f"ZIP blob verification failed: {path}")
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(output.suffix + ".sha256").write_text(
        f"{digest}  {output.name}\n", encoding="utf-8")
    return {"path": str(output), "files": len(expected), "sha256": digest,
            "source_commit": SHA, "tree_sha": m["source_tree_sha"],
            "recovered_from_commit": head, "recovered_from_ref": ref,
            "size_bytes": output.stat().st_size}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--repo-url", default=REPO)
    parser.add_argument("--private-backup", action="store_true", help="Reconstruct from independent private repo tree")
    parser.add_argument("--output", type=Path, default=Path("Hollowmere-G0-eddeaef2-Source.zip"))
    a = parser.parse_args()
    repo_url = PRIVATE_REPO if a.private_backup else a.repo_url
    ref = PRIVATE_REF if a.private_backup else REF
    commit = PRIVATE_SHA if a.private_backup else SHA
    print(json.dumps(recover(repo_url, a.manifest, a.output, ref=ref, expected_commit=commit), indent=2))


if __name__ == "__main__":
    main()
