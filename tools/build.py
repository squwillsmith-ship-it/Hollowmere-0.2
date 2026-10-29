#!/usr/bin/env python3
"""Pinned, cross-platform build entry point. Python 3.10+; no packages needed."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
BUILD = ROOT / "build"


def run(args, name):
    result = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=300)
    (BUILD / f"{name}.log").write_text(result.stdout, encoding="utf-8")
    print(result.stdout, end="")
    if result.returncode or re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|Parse Error:)", result.stdout):
        raise RuntimeError(f"{name} failed: see build/{name}.log")
    return result.stdout


def verify_pe(path):
    with path.open("rb") as f:
        if f.read(2) != b"MZ":
            raise RuntimeError("Export is not a PE executable")
        f.seek(0x3c)
        offset = struct.unpack("<I", f.read(4))[0]
        f.seek(offset)
        if f.read(4) != b"PE\0\0" or struct.unpack("<H", f.read(2))[0] != 0x8664:
            raise RuntimeError("Export is not Windows x86-64")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["check", "windows"])
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    resolved = shutil.which(args.godot)
    if not resolved:
        raise RuntimeError("Godot not found. Supply --godot /path/to/pinned/editor")
    godot = str(Path(resolved).resolve())
    BUILD.mkdir(exist_ok=True)
    version = run([godot, "--version"], "version").strip()
    pin = (ROOT / "engine-version.txt").read_text().strip()
    if not (version == pin or version.startswith(pin + ".")):
        raise RuntimeError(f"Expected {pin}; got {version}")
    run([godot, "--headless", "--path", str(GAME), "--editor", "--quit"], "import")
    smoke = run([godot, "--headless", "--path", str(GAME), "--", "--smoke-test"], "smoke")
    if "HOLLOWMERE_SMOKE_OK" not in smoke:
        raise RuntimeError("Smoke test did not reach completion")
    # Run all milestone acceptance suites, not only the bootstrap scene.
    # Their presence in the ZIP never counts as having executed them.
    for step in ("04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17"):
        output = run([godot, "--headless", "--path", str(GAME), "--script",
                      f"res://tests/test_step{step}.gd"], f"test-step{step}")
        marker = (f"HOLLOWMERE_STEP{step}_TEST_OK" if step in ("06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17")
                  else f"HOLLOWMERE_STEP{step}_TESTS_OK")
        if marker not in output:
            raise RuntimeError(f"Step {step} engine suite did not confirm success")
    if args.action == "check":
        return
    windows = BUILD / "windows"
    windows.mkdir(exist_ok=True)
    # Remove only this build's outputs so a failed export cannot package an old executable.
    for p in windows.iterdir():
        if p.is_file():
            p.unlink()
        else:
            raise RuntimeError("Unexpected output directory; inspect before building")
    exe = windows / "Hollowmere.exe"
    run([godot, "--headless", "--path", str(GAME), "--export-release",
         "Windows Desktop", str(exe)], "export-windows")
    verify_pe(exe)
    pck = windows / "Hollowmere.pck"
    if not pck.is_file() or pck.stat().st_size < 64:
        raise RuntimeError("Missing or empty game data pack")
    shutil.copyfile(ROOT / "docs/PLAYER-README.txt", windows / "README.txt")
    shutil.copyfile(ROOT / "docs/THIRD-PARTY-NOTICES.txt", windows / "THIRD-PARTY-NOTICES.txt")
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
                            capture_output=True).stdout.strip() or "uncommitted"
    files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(windows.iterdir()) if p.is_file()}
    manifest = {"engineering_scope": "Brinewick Steps 26-30 integration", "engine": version, "source_commit": commit,
                "platform": "windows-x86_64", "configuration": "release",
                "native_windows_tested": False, "sha256": files}
    (windows / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive = BUILD / "Hollowmere-Windows-Brinewick-Engineering.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(windows.iterdir()):
            z.write(p, "Hollowmere/" + p.name)
    print(f"Created {archive}. Native Windows run remains unverified.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"BUILD FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
