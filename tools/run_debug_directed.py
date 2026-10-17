#!/usr/bin/env python3
"""Directed debug safety cases and debug-disabled pipeline regression."""
import hashlib,json,os,shutil,subprocess
from pathlib import Path
from pipeline_config import configuration
ROOT=Path(__file__).resolve().parents[1]
protection=configuration()
def main():
 tool=os.environ.get('VERILATOR') or shutil.which('verilator') or str(ROOT/'.tools/monitor-verilator/verilator')
 names='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core ft_ecc_ram ft_event_monitor riscue_pipeline_soc riscue_jtag_dtm riscue_debug_module riscue_debug_soc'.split()
 files=[str(ROOT/'rtl'/(n+'.sv')) for n in names]
 report_path=ROOT/'build'/('debug-directed-'+protection['pipeline_protection']+'.json')
 report_path.write_text(json.dumps({'passed':False,'status':'incomplete'})+'\n')
 results=[]
 cases=[('tb_debug','tests/debug/tb_debug.sv',{})]
 for rf in (0,1):
  cases.append(('tb_pipeline_smoke','tests/tb_pipeline_smoke.sv',{'RF_TMR':rf}))
  for early in (0,1):cases.append(('tb_pipeline_jump','tests/tb_pipeline_jump.sv',{'RF_TMR':rf,'EARLY_JUMP':early}))
 if os.environ.get('DEBUG_ONLY')=='1':cases=cases[:1]
 for top,tb,params in cases:
  label=top+''.join(f'-{k}{v}' for k,v in params.items());out=Path(os.environ.get('RISCUE_DEBUG_BUILD_ROOT',str(ROOT/'build/debug')))/protection['pipeline_protection']/label;out.mkdir(parents=True,exist_ok=True)
  cmd=[tool]+protection['iverilog_flags']+['--cc','--main','--exe','--timing','--public-flat-rw','-Wno-fatal','--top-module',top,'--Mdir',str(out)]+[f'-G{k}={v}' for k,v in params.items()]+files+[str(ROOT/tb)]
  with (out/'build.log').open('w') as log:
   subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
   header=out/(f'V{top}__pch.h')
   if header.exists():
    for suffix in ('fast','slow'):shutil.copyfile(header,out/(header.name+'.'+suffix))
   subprocess.run(['make','-C',str(out),'-f',f'V{top}.mk','-j','2'],stdout=log,stderr=subprocess.STDOUT,check=True)
  run=subprocess.run([str(out/('V'+top))],capture_output=True,text=True,timeout=30)
  output=run.stdout+run.stderr;(out/'run.log').write_text(output)
  record={'name':label,'passed':run.returncode==0 and 'PASS' in output,'output':output};results.append(record);print(output,flush=True)
  if not record['passed']:raise SystemExit('FAILED '+label)
 (ROOT/'build'/('debug-directed-'+protection['pipeline_protection']+'.json')).write_text(json.dumps({'passed':True,'configuration':protection,'runs':results,'core_sha256':hashlib.sha256((ROOT/'rtl/riscue_pipeline_core.sv').read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':main()
