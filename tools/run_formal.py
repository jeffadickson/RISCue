#!/usr/bin/env python3
"""Prepare and run formal jobs. Failures/timeouts are never reported as proofs."""
import argparse,json,os,shutil,subprocess,time,signal,fcntl
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('group',choices=['ecc','ram','monitor','fault','isa','all','prepare','cover','execute','pipeline','pipeline-prepare','muldiv','injector']);p.add_argument('--jobs',type=int,default=2);p.add_argument('--timeout',type=int,default=300);p.add_argument('--instruction',action='append');p.add_argument('--build-dir',default='build/formal');a=p.parse_args()
if a.jobs<1 or a.timeout<1:p.error('--jobs and --timeout must be positive')
env=os.environ.copy();suite=ROOT/'.tools/oss-cad-suite';env['PATH']=str(suite/'bin')+os.pathsep+env['PATH'];env['PYTHONNOUSERSITE']='1'
sv2v=os.environ.get('SV2V',str(ROOT/'.tools/sv2v-Linux/sv2v'))
for tool in ['sby','yosys','bitwuzla']:
 if not shutil.which(tool,path=env['PATH']):raise SystemExit('Missing '+tool+'; run make formal-tools')
if not Path(sv2v).exists() and not shutil.which(sv2v):raise SystemExit('Missing sv2v; run make formal-tools')
build=(ROOT/a.build_dir).resolve()
if not build.is_relative_to(ROOT/'build'):p.error('--build-dir must be inside build/')
build.mkdir(parents=True,exist_ok=True)
lock=(build/'.run.lock').open('w')
try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError:raise SystemExit('Another formal run is active; wait for it to finish.')

def convert(files,out,defines=(),prefix=''):
 cmd=[sv2v,'-E','Assert','-D','FORMAL']
 for d in defines:cmd+=['-D',d]
 with out.open('w') as dst:
  if prefix:dst.write(prefix)
  subprocess.run(cmd+[str(ROOT/f) for f in files],check=True,stdout=dst,env=env)
 if out.stat().st_size==0:raise SystemExit('sv2v produced empty output')
def job(name,files,top,mode='prove',depth=4,params=''):
 v=build/(name+'.v');convert(files,v)
 cfg=build/(name+'.sby')
 cfg.write_text(f'[options]\nmode {mode}\ndepth {depth}\ntimeout {a.timeout}\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv {v.name}\n{params}\nprep -flatten -top {top}\nchformal -early\nasync2sync\ndffunmap\n[files]\n{v}\n')
 return cfg
jobs=[]
from prepare_formal_models import prepare_models
models=prepare_models(build/'models')
if a.group=='muldiv':
 for funct3,name in enumerate(['mul','mulh','mulhsu','mulhu','div','divu','rem','remu']):
  jobs.append(job('multicycle_'+name,['rtl/ft_pkg.sv','rtl/riscue_pipeline_pkg.sv','rtl/riscue_muldiv.sv','formal/muldiv.sv'],'formal_muldiv','bmc',40,f'chparam -set FUNCT3 {funct3} formal_muldiv'))
  jobs.append(job('cover_multicycle_'+name,['rtl/ft_pkg.sv','rtl/riscue_pipeline_pkg.sv','rtl/riscue_muldiv.sv','formal/muldiv.sv'],'formal_muldiv','cover',40,f'chparam -set FUNCT3 {funct3} formal_muldiv'))
if a.group=='injector':
 jobs.append(job('injector',['rtl/ft_pkg.sv','rtl/riscue_pipeline_pkg.sv','rtl/fi_campaign_controller.sv','formal/injector.sv'],'formal_injector','bmc',28))
 jobs.append(job('cover_injector',['rtl/ft_pkg.sv','rtl/riscue_pipeline_pkg.sv','rtl/fi_campaign_controller.sv','formal/injector.sv'],'formal_injector','cover',28))
if a.group in ('execute','all'):
 for funct3,name in enumerate(['mul','mulh','mulhsu','mulhu','div','divu','rem','remu']):
  v=build/('execute_'+name+'.v')
  convert(['rtl/ft_pkg.sv','rtl/rv32_execute.sv',str(models/('insn_'+name+'.v')),'formal/execute_m.sv'],v,
   ['RISCV_FORMAL_XLEN=32','RISCV_FORMAL_ILEN=32','M_FUNCT3=3\'d'+str(funct3),'M_MODEL=rvfi_insn_'+name])
  cfg=v.with_suffix('.sby')
  cfg.write_text(f'[options]\nmode prove\ndepth 1\ntimeout {a.timeout}\n[engines]\nsmtbmc bitwuzla\n[script]\nread_verilog -formal -sv {v.name}\nprep -top formal_execute_m\n[files]\n{v}\n')
  jobs.append(cfg)
if a.group in ('ecc','all'):jobs.append(job('ecc',['rtl/ft_pkg.sv','formal/ecc.sv'],'formal_ecc',depth=1))
if a.group in ('ram','all'):
 for bit in range(39):jobs.append(job(f'ram_single_{bit:02d}',['rtl/ft_pkg.sv','rtl/ft_ecc_ram.sv','formal/ram.sv'],'formal_ram','bmc',10,f'chparam -set DOUBLE 0 -set BIT_A {bit} formal_ram'))
 jobs.append(job('ram_double',['rtl/ft_pkg.sv','rtl/ft_ecc_ram.sv','formal/ram.sv'],'formal_ram','bmc',10,'chparam -set DOUBLE 1 formal_ram'))
if a.group in ('monitor','all'):jobs.append(job('monitor',['rtl/ft_event_monitor.sv','formal/monitor.sv'],'formal_monitor',depth=6))
if a.group in ('fault','all'):
 for tmr in (0,1):jobs.append(job('fault_'+str(tmr),['rtl/ft_pkg.sv','rtl/rv32_execute.sv','rtl/rv32im_ft_core.sv','formal/core_fault.sv'],'formal_core_fault','bmc',12,f'chparam -set RF_TMR {tmr} formal_core_fault'))
if a.group in ('isa','all','prepare','pipeline','pipeline-prepare'):
 pipeline=a.group.startswith('pipeline')
 stage=build/'riscv-formal';stage.mkdir(exist_ok=True)
 upstream=ROOT/'third_party/riscv-formal'
 for folder in ('checks',):
  link=stage/folder
  if not link.exists():link.symlink_to(upstream/folder,target_is_directory=True)
 link=stage/'insns'
 if link.is_symlink():link.unlink()
 if not link.exists():link.symlink_to(models,target_is_directory=True)
 core=stage/('cores/ftpipeline' if pipeline else 'cores/ftcore');core.mkdir(parents=True,exist_ok=True)
 shutil.copy(ROOT/('formal/pipeline_checks.cfg' if pipeline else 'formal/checks.cfg'),core/'checks.cfg');shutil.copy(ROOT/('formal/pipeline_wrapper.sv' if pipeline else 'formal/rvfi_wrapper.sv'),core/'wrapper.sv')
 macros=(upstream/'checks/rvfi_macros.vh').read_text()
 # Preserve the macros for upstream wrapper, but expand the core's optional ports before conversion.
 tmp=build/'rvfi_macros.sv';tmp.write_text(macros)
 cmd=[sv2v,'-E','Assert','-D','FORMAL','-D','RISCV_FORMAL','-D','RISCV_FORMAL_NRET=1','-D','RISCV_FORMAL_XLEN=32','-D','RISCV_FORMAL_ILEN=32',str(tmp)]+[str(ROOT/f) for f in (['rtl/ft_pkg.sv','rtl/riscue_pipeline_pkg.sv','rtl/riscue_rvc.sv','rtl/riscue_execute.sv','rtl/riscue_muldiv.sv','rtl/riscue_pipeline_core.sv','formal/pipeline_wrapper.sv'] if pipeline else ['rtl/ft_pkg.sv','rtl/rv32_execute.sv','rtl/rv32im_ft_core.sv','formal/rvfi_wrapper.sv'])]
 with (core/'core.v').open('w') as dst:subprocess.run(cmd,stdout=dst,check=True,env=env)
 if (core/'core.v').stat().st_size==0:raise SystemExit('sv2v produced empty core')
 subprocess.run(['python3',str(stage/'checks/genchecks.py')],cwd=core,check=True,env=env)
 for cfg in (core/'checks').glob('*.sby'):
  cfg.write_text(cfg.read_text().replace('chformal -early', 'chformal -early\nasync2sync\ndffunmap').replace('[options]\n', '[options]\ntimeout '+str(a.timeout)+'\n'))
 if a.group in ('isa','all','pipeline'):
  candidates=sorted((core/'checks').glob('*.sby'))
  jobs += [j for j in candidates if not a.instruction or j.stem in ['insn_'+n+'_ch0' for n in a.instruction]]
  if a.instruction and not jobs:raise SystemExit('No matching ISA job')
  if pipeline:
   for original in list(jobs):
    if not original.stem.startswith('insn_'):continue
    cfg=original.with_name('cover_'+original.name)
    cfg.write_text(original.read_text().replace('mode bmc','mode cover').replace('skip 64\n','').replace('depth 65','depth 64').replace('RISCV_FORMAL_CHECK_CYCLE 64','RISCV_FORMAL_CHECK_CYCLE 63'))
    jobs.append(cfg)
if a.group in ('prepare','pipeline-prepare'):raise SystemExit(0)
if a.group in ('cover','all'):
 core=build/'riscv-formal/cores/ftcore'
 if not (core/'checks').exists():raise SystemExit('Run make formal-prepare before instruction covers')
 for original in sorted((core/'checks').glob('insn_*.sby')):
  if a.instruction and original.stem not in ['insn_'+n+'_ch0' for n in a.instruction]:continue
  cfg=original.with_name('cover_'+original.name)
  cfg.write_text(original.read_text().replace('mode bmc','mode cover').replace('skip 12\n','').replace('depth 13','depth 7').replace('RISCV_FORMAL_CHECK_CYCLE 12','RISCV_FORMAL_CHECK_CYCLE 6').replace('timeout 300','timeout '+str(a.timeout)))
  jobs.append(cfg)
if a.group in ('ram','monitor','fault','execute','all'):
 for original in list(jobs):
  if original.stem!='monitor' and not original.name.startswith(('ram_','fault_','execute_')):continue
  if original.stem.startswith('ram_single_') and original.stem!='ram_single_00':continue
  cfg=original.with_name('cover_'+original.name)
  cfg.write_text(original.read_text().replace('mode bmc','mode cover').replace('mode prove','mode cover'))
  jobs.append(cfg)

# Limit parallelism and retain per-job output and status.
from concurrent.futures import ThreadPoolExecutor

def run(cfg):
 started=time.time();out=cfg.parent/(cfg.stem+'.console.log');dest=cfg.parent/cfg.stem
 try:
  with out.open('w') as log:
   process=subprocess.Popen(['sby','-f',str(cfg)],cwd=cfg.parent,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
   try:process.wait(timeout=a.timeout+30)
   except subprocess.TimeoutExpired:
    os.killpg(process.pid,signal.SIGTERM);process.wait();raise
  status=(dest/'status').read_text().strip() if (dest/'status').exists() else 'ERROR'
 except subprocess.TimeoutExpired:status='TIMEOUT'
 item={'job':cfg.stem,'status':status,'seconds':round(time.time()-started,2),'log':str(out.relative_to(ROOT))}
 print(json.dumps(item),flush=True);return item
with ThreadPoolExecutor(max_workers=a.jobs) as pool:results=list(pool.map(run,jobs))
(build/('results-'+a.group+'.json')).write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if results and all(x['status'].split()[0]=='PASS' for x in results) else 1)
