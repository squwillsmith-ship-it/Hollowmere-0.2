#!/usr/bin/env python3
"""Offline repeatable Step 4 data validation and report emitter."""
import json, subprocess, sys, hashlib, datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files=sorted((ROOT/'game/data/v1').glob('*.json'))
report={
 'milestone':'04',
 'date_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'data_file_count':len(files),
 'data_file_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
 'test_command':'python -m unittest discover -s tests -p test_step04*.py -v',
 'engine_headless':'NOT_RUN: exact pinned Godot binary is not installed in this environment',
 'native_windows':'NOT_RUN: no Windows test machine',
}
p=subprocess.run([sys.executable,'-m','unittest','discover','-s','tests','-p','test_step04*.py','-v'],cwd=ROOT,capture_output=True,text=True)
report['data_tests_exit_code']=p.returncode
report['data_test_output']=p.stdout+p.stderr
path=ROOT/'build-evidence/step04-data-validation.json'
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(report,indent=2)+'\n')
print(report['data_test_output'])
print('Evidence:',path)
sys.exit(p.returncode)
