#!/usr/bin/env python3
"""Run all extant engine-independent Step04/05/06 contract suites."""
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
command = [sys.executable, '-m', 'unittest', 'discover', '-s', str(root/'tests'), '-p', 'test_step0*.py', '-v']
print('Running:', ' '.join(command), flush=True)
raise SystemExit(subprocess.call(command, cwd=root))
