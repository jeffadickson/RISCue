#!/usr/bin/env python3
import os,subprocess,sys
from pathlib import Path
r=Path(__file__).resolve().parents[1]
for mode in ('TMR','PARITY_REPLAY'):
 env=os.environ.copy();env.update(PIPELINE_PROTECTION=mode,ALLOW_EXPERIMENTAL_PARITY='1' if mode=='PARITY_REPLAY' else '0')
 subprocess.run(['make','PYTHON='+sys.executable.replace(chr(92),'/'),'test-axi-core-errors','test-axi-master-bridge','test-axi-ecc-ram','test-monitor-disabled'],cwd=r,env=env,check=True)
print('PASS pipeline interface integration in both protection modes')
