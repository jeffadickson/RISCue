#!/usr/bin/env python3
"""Final local regression of the experimental drop-in integration."""
import os,subprocess,sys
from pathlib import Path
r=Path(__file__).resolve().parents[1]
for mode in ('TMR','PARITY_REPLAY'):
 env=os.environ.copy();env.update(PIPELINE_PROTECTION=mode,ALLOW_EXPERIMENTAL_PARITY='1' if mode=='PARITY_REPLAY' else '0')
 subprocess.run(['make','PYTHON='+sys.executable.replace(chr(92),'/'),'pipeline-smoke','pipeline-jump','pipeline-compile'],cwd=r,env=env,check=True)
subprocess.run([sys.executable,'tools/check_pipeline_campaign.py','final'],cwd=r,check=True)
subprocess.run([sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py'],cwd=r,check=True)
subprocess.run([sys.executable,'tools/build_manual.py','--check'],cwd=r,check=True)
print('PASS final both-mode smoke/jump/interface, 24 fault cases, Python and documentation regression')
