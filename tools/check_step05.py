#!/usr/bin/env python3
"""Run Step 4+5 Python validation without implying GDScript runtime validation."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
cmd=[sys.executable,'-m','unittest','discover','-s','tests','-p','test_step0*.py','-v']
print('Validating Python schema and Step 5 persistence contract (NOT Godot compilation)',flush=True)
raise SystemExit(subprocess.call(cmd,cwd=root))
