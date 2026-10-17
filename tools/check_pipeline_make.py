#!/usr/bin/env python3
import subprocess
from pathlib import Path
r=Path(__file__).resolve().parents[1]
for args,ok,needle in [([],True,'RISCUE_PIPELINE_PROTECTION=0'),(['PIPELINE_PROTECTION=TYPO'],False,'Invalid PIPELINE_PROTECTION'),(['PIPELINE_PROTECTION=PARITY_REPLAY'],False,'requires ALLOW_EXPERIMENTAL_PARITY=1'),(['PIPELINE_PROTECTION=PARITY_REPLAY','ALLOW_EXPERIMENTAL_PARITY=1'],True,'RISCUE_PIPELINE_PROTECTION=1')]:
 p=subprocess.run(['make','-n','pipeline-smoke',*args],cwd=r,capture_output=True,text=True)
 assert (p.returncode==0)==ok and needle in p.stdout+p.stderr,(args,p.stdout,p.stderr)
 print('PASS Make selection',args)

p=subprocess.run(['make','-n','pipeline-smoke','PIPELINE_PROTECTION=PLAIN'],cwd=r,capture_output=True,text=True)
assert p.returncode==0 and '-DRISCUE_PLAIN_MEMORY' in p.stdout and 'RISCUE_PIPELINE_PROTECTION=2' in p.stdout
print('PASS PLAIN Make selection')
