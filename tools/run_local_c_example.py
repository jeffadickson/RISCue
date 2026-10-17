#!/usr/bin/env python3
"""Run the existing compiled C mailbox example on both pipeline variants."""
import json,os,subprocess,sys
from pathlib import Path
r=Path(__file__).resolve().parents[1]
cc=r/'.tools/riscv/root/usr/bin/riscv64-unknown-elf-gcc'
if not cc.exists():subprocess.run([sys.executable,str(r/'tools/setup_c_toolchain.py')],check=True)
env=os.environ.copy();env['PATH']=str(cc.parent)+os.pathsep+env['PATH']
env['PIPELINE_PYTHON']=str(Path.home()/'.venvs/riscue/bin/python')
for mode in ('TMR','PARITY_REPLAY'):
 env.update(PIPELINE_PROTECTION=mode,ALLOW_EXPERIMENTAL_PARITY='1' if mode=='PARITY_REPLAY' else '0')
 subprocess.run(['make','c-smoke','PYTHON='+sys.executable],cwd=r,env=env,check=True)
print('PASS compiled C smoke in both pipeline modes and both RF modes')
