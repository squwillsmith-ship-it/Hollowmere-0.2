#!/usr/bin/env python3
"""Unattended Windows *windowed* Godot 4.7.2 rendering attempt.
Outputs indicate real framebuffer evidence only, never human playtest signoff.
"""
from pathlib import Path
import argparse, json, os, platform, subprocess, time, hashlib
from PIL import Image

R=Path(__file__).resolve().parents[1]
B=R/"build"/"windows-visual"
B.mkdir(parents=True,exist_ok=True)
groups=[
 ("smoke","res://tests/test_step06_capture.gd","HOLLOWMERE_SCREENSHOT","HOLLOWMERE_STEP06_RENDER_OK",["step06-engine-frame.png"]),
 ("ten","res://tests/test_phase_e_capture.gd","HOLLOWMERE_UNDERGROUND_RENDER_DIR","HOLLOWMERE_PHASE_E_RENDER_OK",
  ["phase-e-"+k+".png" for k in ["well","mine","undercroft","bell","harbour","headland","inn","mine_office","chapel","shore"]]),
 ("reference","res://tests/test_reference_capture.gd","HOLLOWMERE_REFERENCE_RENDER_DIR","HOLLOWMERE_REFERENCE_RENDER_OK",
  ["reference-cottage.png","reference-warehouse.png"]),
]
def main():
 p=argparse.ArgumentParser()
 p.add_argument("--godot",required=True)
 args=p.parse_args()
 exe=str((R/args.godot).resolve())
 summary={"source":os.environ.get("GITHUB_SHA"),"platform":platform.platform(),
          "graphics_tests":{},"native_windows_windowed_editor_attempted":True,
          "exported_game_gui_not_tested":True,"human_playtest":False,"audio_review":False}
 passed_any=False
 for method,driver in [("forward_plus","vulkan"),("gl_compatibility","opengl3")]:
  where=B/method
  where.mkdir(exist_ok=True,parents=True)
  results=[]
  for key,script,envname,marker,expected in groups:
   local=os.environ.copy()
   local[envname]=str(where/expected[0]) if key=="smoke" else str(where)
   command=[exe,"--audio-driver","Dummy","--rendering-method",method,
            "--rendering-driver",driver,"--path",str(R/"game"),"--script",script]
   t0=time.monotonic()
   try:
    x=subprocess.run(command,env=local,cwd=R,capture_output=True,text=True,errors="replace",timeout=300)
    rc=x.returncode; logs=x.stdout+"\n"+x.stderr
   except subprocess.TimeoutExpired as e:
    rc=124;logs=str(e)
   (where/("qa-"+key+".log")).write_text(logs)
   found=[]
   for filename in expected:
    f=where/filename
    if not f.is_file():
     continue
    try:
     with Image.open(f) as im:
      im.load()
      if im.width>=640 and im.height>=360:
       found.append(filename)
    except Exception:
     pass
   good=rc==0 and marker in logs and len(found)==len(expected)
   results.append({"group":key,"success":good,"exit":rc,"frames":found,
                   "expected":len(expected),"seconds":round(time.monotonic()-t0,2)})
   print("WINDOWS_GUI",method,key,"PASS" if good else "FAIL",len(found),"/",len(expected),flush=True)
   if not good:
    print("\n".join(logs.splitlines()[-25:]),flush=True)
    break
  summary["graphics_tests"][method]={"results":results,"all_passed":len(results)==len(groups) and all(v["success"] for v in results)}
  passed_any |= summary["graphics_tests"][method]["all_passed"]
 (B/"qa-windows-graphics.json").write_text(json.dumps(summary,indent=2))
 return 0 if passed_any else 1
if __name__=="__main__":
 raise SystemExit(main())
