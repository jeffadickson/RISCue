#!/usr/bin/env python3
"""Prove the existing SECDED harness as a local Yosys/SBY/solver setup check."""
import hashlib,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
 out=ROOT/'build/formal-setup';out.mkdir(parents=True,exist_ok=True)
 cache=Path.home()/'.cache/riscue-formal-smoke';cache.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env['PATH']=str(ROOT/'.tools/oss-cad-suite/bin')+os.pathsep+env['PATH'];env['PYTHONNOUSERSITE']='1'
 sv2v=ROOT/'.tools/sv2v-Linux/sv2v';sources=[ROOT/'rtl/ft_pkg.sv',ROOT/'formal/ecc.sv'];result={'status':'incomplete','scope':'Existing combinational SECDED properties for arbitrary data and symbolic distinct single/double fault locations; this is not a pipeline recovery proof','sources_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}}
 for tool in ('yosys','sby','yosys-smtbmc','bitwuzla'):
  if not shutil.which(tool,path=env['PATH']):raise SystemExit('Missing '+tool+'; run make formal-tools')
 result['yosys_version']=subprocess.check_output(['yosys','-V'],env=env,text=True).strip();result['sby_version']=subprocess.check_output(['sby','--version'],env=env,text=True).strip()
 started=time.monotonic()
 with (cache/'ecc.v').open('w') as dst:subprocess.run([str(sv2v),'-E','Assert','-D','FORMAL',*[str(p) for p in sources]],stdout=dst,env=env,check=True,timeout=120)
 (cache/'ecc.sby').write_text('[options]\nmode prove\ndepth 1\ntimeout 180\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal ecc.v\nprep -top formal_ecc\n[files]\necc.v\n')
 with (out/'run.log').open('w') as log:
  try:
   run=subprocess.run(['sby','-f','ecc.sby'],cwd=cache,stdout=log,stderr=subprocess.STDOUT,env=env,timeout=210)
   result['raw_status']=(cache/'ecc/status').read_text().strip() if (cache/'ecc/status').exists() else 'ERROR';result['status']=result['raw_status'].split()[0];result['exit_code']=run.returncode
  except subprocess.TimeoutExpired:result['status']='TIMEOUT'
 result['seconds']=round(time.monotonic()-started,2);result['work_directory']=str(cache);(out/'results.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
 if result['status']!='PASS' or result.get('exit_code')!=0:raise SystemExit(1)

if __name__=='__main__':main()
