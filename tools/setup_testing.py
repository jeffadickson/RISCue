#!/usr/bin/env python3
"""Prepare a local cocotb venv from pinned test requirements; no tests run."""
import subprocess,venv
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
env=ROOT/'.tools/test-python';py=env/'bin/python'
if not py.exists():venv.EnvBuilder(with_pip=True).create(env)
subprocess.run([str(py),'-m','pip','install','-r',str(ROOT/'requirements-test.txt')],check=True)
print('Testing Python:',py)
