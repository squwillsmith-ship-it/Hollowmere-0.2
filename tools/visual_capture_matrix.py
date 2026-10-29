#!/usr/bin/env python3
"""Capture real Godot viewports for Brinewick, never simulate frames.

This is a repeatable software-display DIAGNOSTIC. Image file validity and
source correspondence do not imply visual approval, path accessibility,
native Windows rendering, or measured gameplay framerate.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import time
from PIL import Image, ImageDraw, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
TEN = ["well", "mine", "undercroft", "bell", "harbour", "headland", "inn",
       "mine_office", "chapel", "shore"]
CAPTURES = [
    ("smoke", "res://tests/test_step06_capture.gd", "HOLLOWMERE_SCREENSHOT",
     "HOLLOWMERE_STEP06_RENDER_OK", ["step06-engine-frame.png"]),
    ("materials", "res://tests/test_step21_capture.gd", "HOLLOWMERE_MATERIAL_RENDER_DIR",
     "HOLLOWMERE_STEP21_RENDER_OK", ["step21-materials-neutral.png", "step21-materials-coastal.png"]),
    ("blockout", "res://tests/test_step25_capture.gd", "HOLLOWMERE_BLOCKOUT_RENDER_DIR",
     "HOLLOWMERE_STEP25_RENDER_OK", ["step25-brinewick-aerial.png", "step25-brinewick-harbour.png"]),
    ("reference", "res://tests/test_reference_capture.gd", "HOLLOWMERE_REFERENCE_RENDER_DIR",
     "HOLLOWMERE_REFERENCE_RENDER_OK", ["reference-cottage.png", "reference-warehouse.png"]),
    ("ten_views", "res://tests/test_phase_e_capture.gd", "HOLLOWMERE_UNDERGROUND_RENDER_DIR",
     "HOLLOWMERE_PHASE_E_RENDER_OK",
     ["phase-e-" + x + ".png" for x in TEN] + ["phase-e-undercroft-legacy-pose.png"]),
    ("teardown", "res://tests/test_visual_rebuild_teardown_capture.gd",
     "HOLLOWMERE_TEARDOWN_RENDER_DIR", "HOLLOWMERE_VISUAL_TEARDOWN_RENDER_OK",
     ["teardown-" + x + "-" + phase + ".png"
      for x in ("cottage", "warehouse") for phase in ("intact", "half", "heavy")]),
    ("sites", "res://tests/test_visual_21_sites_capture.gd",
     "HOLLOWMERE_SITE_RENDER_DIR", "HOLLOWMERE_SITE_CAPTURE_OK",
     ["site-%02d-%s.png" % (i, mode) for i in range(1, 22)
      for mode in ("wide", "near")]),
]

def validate(path: Path) -> dict:
    with Image.open(path) as img:
        img.load()
        if img.width < 640 or img.height < 360:
            raise ValueError("Frame resolution too low")
        reduced = img.convert("RGB").resize((64, 36))
        pixels = list(reduced.getdata())
        distinct = len(set(pixels))
        if distinct < 12:
            raise ValueError("Frame nearly uniform, only %d distinct sampled colors" % distinct)
        mean = [round(v, 2) for v in ImageStat.Stat(reduced).mean]
        extreme = sum(1 for r,g,b in pixels if max(r,g,b) < 8 or min(r,g,b) > 247) / len(pixels)
        return {"width": img.width, "height": img.height, "bytes": path.stat().st_size,
                "sampled_colors": distinct, "mean_rgb": mean,
                "near_black_or_white_fraction": round(extreme, 4),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

def montage(out: Path, paths: list[Path], filename: str, cols: int = 5) -> str | None:
    paths = [p for p in paths if p.exists()]
    if not paths:
        return None
    tile_w, tile_h, caption_h = 320, 180, 27
    rows = (len(paths) + cols - 1) // cols
    img = Image.new("RGB", (tile_w*cols, (tile_h+caption_h)*rows), (34,38,40))
    draw = ImageDraw.Draw(img)
    for index, path in enumerate(paths):
        with Image.open(path) as frame:
            frame = frame.convert("RGB")
            frame.thumbnail((tile_w, tile_h))
            x = (index % cols)*tile_w
            y = (index // cols)*(tile_h+caption_h)
            img.paste(frame, (x+(tile_w-frame.width)//2,y+(tile_h-frame.height)//2))
            draw.text((x+7,y+tile_h+5), path.stem, fill=(240,240,225))
    dest = out / filename
    img.save(dest)
    return dest.name

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--godot", required=True)
    p.add_argument("--mode", choices=["forward_plus", "gl_compatibility"], required=True)
    args = p.parse_args()
    out = BUILD / ("visual-" + args.mode)
    out.mkdir(parents=True, exist_ok=True)
    engine = str((ROOT / args.godot).resolve()) if not Path(args.godot).is_absolute() else args.godot
    driver = "vulkan" if args.mode == "forward_plus" else "opengl3"
    cmd_base = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24",
                engine, "--verbose", "--audio-driver", "Dummy",
                "--rendering-method", args.mode, "--rendering-driver", driver,
                "--path", str(ROOT/"game")]
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    env["GODOT_HEADLESS"] = "false"
    report = {"mode": args.mode, "driver_requested": driver, "source": env.get("GITHUB_SHA"),
              "engine": engine, "platform": platform.platform(),
              "hardware_gpu_accepted": False,
              "native_windows_graphics_tested": False,
              "measured_gameplay_fps": None,
              "human_visual_signoff": False, "captures": {}, "frames": {},
              "failures": [], "all_passed": False}
    captured = []
    for name, gd, var, marker, wanted in CAPTURES:
        localenv = env.copy()
        localenv[var] = str((out/wanted[0]).resolve()) if name == "smoke" else str(out.resolve())
        start = time.monotonic()
        try:
            proc = subprocess.run(cmd_base + ["--script", gd], cwd=ROOT, env=localenv,
                                  capture_output=True, text=True, errors="replace", timeout=540)
            code, logs = proc.returncode, proc.stdout+"\n"+proc.stderr
        except subprocess.TimeoutExpired as e:
            code, logs = 124, "TIMEOUT in " + name + "\n" + str(e)
        (out / ("qa-"+name+".log")).write_text(logs, encoding="utf-8")
        found = []
        for file in wanted:
            path = out/file
            if not path.exists():
                report["failures"].append(name+": no "+file)
                continue
            try:
                report["frames"][file] = validate(path)
                found.append(path)
                captured.append(path)
            except Exception as exc:
                report["failures"].append(name+": invalid "+file+": "+str(exc))
        marker_ok = marker in logs
        ok = code == 0 and marker_ok and len(found) == len(wanted)
        report["captures"][name] = {"passed": ok, "process_exit": code,
              "success_marker": marker_ok, "found": len(found), "expected": len(wanted),
              "seconds": round(time.monotonic()-start, 2)}
        if not ok:
            report["failures"].append(name+": exit="+str(code)+
                    " marker="+str(marker_ok)+" files="+str(len(found))+"/"+str(len(wanted)))
        print(name, "PASS" if ok else "FAIL", len(found), "/", len(wanted),
              "elapsed", report["captures"][name]["seconds"], flush=True)
        if code != 0:
            print("\n".join(logs.splitlines()[-40:]), flush=True)
        if name == "smoke" and not ok:
            print("Renderer failed at first smoke frame; remaining groups skipped.")
            break
    digests = {}
    for file, frame in report["frames"].items():
        h = frame["sha256"]
        if h in digests:
            report["failures"].append("Identical pixel-files: "+file+" and "+digests[h])
        digests[h] = file
    # Actual wide/full overview sheets for human inspection.
    report["overview"] = montage(out,[out/("phase-e-"+v+".png") for v in TEN],
                                  "contact-10-canonical-views.png",5)
    report["sites_overview"] = montage(out,[out/("site-%02d-wide.png" % i) for i in range(1,22)],
                                  "contact-21-site-wide.png",5)
    report["sites_near"] = montage(out,[out/("site-%02d-near.png" % i) for i in range(1,22)],
                                  "contact-21-site-near.png",5)
    report["teardown_overview"] = montage(out,
                    [out/("teardown-"+v+"-"+q+".png") for v in ("cottage","warehouse")
                     for q in ("intact","half","heavy")],"contact-6-teardown-states.png",3)
    report["all_passed"] = (len(report["captures"]) == len(CAPTURES)
                              and all(v["passed"] for v in report["captures"].values())
                              and not report["failures"])
    (out/"qa-visual-matrix.json").write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    print("VISUAL_MATRIX", args.mode, "PASSED" if report["all_passed"] else "FAILED",
          len(report["frames"]), "frames", len(report["failures"]), "issues")
    return 0 if report["all_passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
