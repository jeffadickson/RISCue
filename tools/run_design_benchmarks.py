#!/usr/bin/env python3
"""Same compiled C binaries and memory latencies across five current-ISA variants."""
import argparse,datetime,hashlib,json,os,re,signal,subprocess,sys,time,zlib
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from pipeline_config import configuration
from software_profile import load_profile
from check_elf import check
from simulation_build import build_verilator
VARIANTS=[('pipeline-tmr','PIPELINED','TMR'),('pipeline-parity','PIPELINED','PARITY_REPLAY'),('pipeline-plain','PIPELINED','PLAIN'),('multicycle-tmr','MULTICYCLE','TMR'),('multicycle-plain','MULTICYCLE','PLAIN')]
RTL='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core'.split()
def expected_values():
 crc=zlib.crc32(bytes((i*37+11)&255 for i in range(32)))
 seed=0x1234567;data=[]
 for i in range(16):
  seed=(seed^(seed<<13))&0xffffffff;seed^=seed>>17;seed=(seed^(seed<<5))&0xffffffff;data.append(seed&65535)
 sort=sum(x*(i+1) for i,x in enumerate(sorted(data)))&0xffffffff
 state=0x13579bdf;mix=0
 for i in range(32):
  state=(state*1664525+1013904223)&0xffffffff
  mix^=((state>>(i&15))+state//((i&7)+1))&0xffffffff
 return [crc,sort,mix]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--simulator',choices=('verilator','iverilog'),default='verilator');p.add_argument('--synthesis',action='store_true');p.add_argument('--jobs',type=int,default=2);p.add_argument('--wait-states',default='0,3');p.add_argument('--output',type=Path);p.add_argument('--timeout',type=int,default=240);a=p.parse_args()
 out=(a.output or ROOT/'build/design-benchmarks'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S')).resolve();out.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(CORE_ARCH='PIPELINED',PIPELINE_PROTECTION='TMR',ALLOW_EXPERIMENTAL_PARITY='0');env.pop('MAKEFLAGS',None);env.pop('MAKEOVERRIDES',None)
 report={'scope':'Measured compiled C clock counts and exact-result checks, with architectural retirement hash comparison; no measured FPGA clock/power or standard CoreMark/Dhrystone score','simulator':a.simulator,'variants':VARIANTS,'binaries':[],'runs':[],'synthesis':[],'source_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [*[ROOT/'rtl'/(n+'.sv') for n in RTL],ROOT/'tests/tb_design_benchmarks.sv',ROOT/'firmware/benchmarks/kernels.c',ROOT/'tools/run_design_benchmarks.py']}}
 def save():(out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,log,cwd=ROOT,extra_env=None):
  start=time.monotonic()
  with log.open('w') as f:
   proc=subprocess.Popen(cmd,cwd=cwd,env=extra_env or env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
   try:code=proc.wait(timeout=a.timeout)
   except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait();raise
  if code:raise RuntimeError(log.read_text()[-2600:])
  return round(time.monotonic()-start,2)
 tools=ROOT/'.tools/riscv/root/usr/bin';prefix=str(tools/'riscv64-unknown-elf-');profile=load_profile()
 expectations=expected_values();kernels=['crc32','insertion_sort','integer_muldiv'];images=[]
 for kind,name in enumerate(kernels):
  folder=out/name;folder.mkdir(exist_ok=True);elf=folder/'benchmark.elf';binary=folder/'benchmark.bin'
  cmd=[prefix+'gcc',*profile['compiler_flags'],'-O2','-Wall','-Wextra','-Werror','-Wno-unused-variable','-nostdlib','-nostartfiles','-Wl,--no-relax','-DBENCH_KIND='+str(kind),'-T',str(ROOT/'firmware/smoke/link.ld'),str(ROOT/'firmware/smoke/start.S'),str(ROOT/'firmware/benchmarks/kernels.c'),'-o',str(elf)]
  run(cmd,folder/'compiler.log');audit=check(elf,profile,prefix+'readelf',prefix+'objdump');subprocess.run([prefix+'objcopy','-O','binary',str(elf),str(binary)],env=env,check=True)
  syms=subprocess.check_output([prefix+'nm',str(elf)],env=env,text=True);finish=int(re.search(r'^([0-9a-fA-F]+)\s+\w\s+_finished$',syms,re.M).group(1),16)
  raw=binary.read_bytes();assert len(raw)<=4096;raw=raw.ljust(4096,b'\0');image=folder/'program.hex';image.write_text(''.join(f'{int.from_bytes(raw[i:i+4],"little"):08x}\n' for i in range(0,4096,4)))
  (folder/'disassembly.txt').write_text(subprocess.check_output([prefix+'objdump','-d',str(elf)],env=env,text=True))
  report['binaries'].append({'kernel':name,'command':cmd,'compiler':subprocess.check_output([prefix+'gcc','--version'],env=env,text=True).splitlines()[0],'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'expected_checksum':expectations[kind],'finish_pc':finish,'isa_audit':audit})
  images.append((name,image,finish,expectations[kind]));save()
 exes={}
 report['simulation_builds']={}
 for label,arch,mode in VARIANTS:
  cfg=configuration(mode,'1' if mode=='PARITY_REPLAY' else '0',arch)
  print('BUILD',a.simulator,label,flush=True)
  if a.simulator=='verilator':
   exe,manifest=build_verilator(ROOT,ROOT/'tests/tb_design_benchmarks.sv',RTL,cfg['iverilog_flags'],label,out/(label+'-compile.log'),timeout=max(a.timeout,600))
   report['simulation_builds'][label]=manifest
  else:
   exe=out/(label+'.vvp')
   run(['iverilog','-g2012','-s','tb_design_benchmarks',*cfg['iverilog_flags'],'-o',str(exe),*[str(ROOT/'rtl'/(n+'.sv')) for n in RTL],str(ROOT/'tests/tb_design_benchmarks.sv')],out/(label+'-compile.log'))
  exes[label]=exe;save()
 references={}
 def simulate(task):
  name,image,finish,expected,waits,label=task
  log=out/(name+'-'+label+'-wait'+str(waits)+'.log')
  seconds=run(((['vvp',str(exes[label])] if a.simulator=='iverilog' else [str(exes[label])])+['+image='+str(image),f'+finish={finish:x}',f'+expected={expected:x}',f'+wait={waits}']),log)
  match=re.search(r'BENCH_PASS cycles=(\d+) instructions=(\d+) checksum=([0-9a-fA-F]+) trace=([0-9a-fA-F]+)',log.read_text());assert match,log.read_text()
  cycles,instructions=int(match[1]),int(match[2])
  branch=re.search(r'BRANCH_STATS conditional=(\d+) taken=(\d+) not_taken=(\d+) direct_jumps=(\d+) indirect_jumps=(\d+)',log.read_text());assert branch,log.read_text()
  stats=dict(zip(('conditional','taken','not_taken','direct_jumps','indirect_jumps'),map(int,branch.groups())))
  shadow=re.search(r'SHADOW_PREDICT correct16=(\d+) correct64=(\d+) correct256=(\d+) correct_btfnt=(\d+)',log.read_text());assert shadow
  stats['shadow_correct']=dict(zip(('entries16','entries64','entries256','backward_taken_forward_not_taken'),map(int,shadow.groups())))
  stats['static_not_taken_accuracy_percent']=round(100*stats['not_taken']/stats['conditional'],2) if stats['conditional'] else None
  return {'kernel':name,'variant':label,'branch_stats':stats,'memory_wait_states':waits,'cycles':cycles,'instructions':instructions,'CPI':round(cycles/instructions,4),'checksum':match[3],'retirement_hash':match[4],'simulator_seconds':seconds,'passed':True}
 tasks=[(name,image,finish,expected,waits,label) for name,image,finish,expected in images for waits in [int(v) for v in a.wait_states.split(',')] for label,arch,mode in VARIANTS]
 with ThreadPoolExecutor(max_workers=max(1,min(a.jobs,4))) as pool:
  futures=[pool.submit(simulate,t) for t in tasks]
  for future in as_completed(futures):
   try:row=future.result()
   except BaseException:
    for pending in futures:pending.cancel()
    raise
   key=row['kernel'];signature=(row['instructions'],row['checksum'],row['retirement_hash'],row['branch_stats'])
   if key in references:assert references[key]==signature,('Architectural trace differs',row,references[key])
   else:references[key]=signature
   report['runs'].append(row);save();print(row,flush=True)
 if a.synthesis:
  for label,arch,mode in VARIANTS:
   config_env=env.copy();config_env.update(CORE_ARCH=arch,PIPELINE_PROTECTION=mode,ALLOW_EXPERIMENTAL_PARITY='1' if mode=='PARITY_REPLAY' else '0')
   print('SYNTHESIS',label,flush=True)
   run([sys.executable,str(ROOT/'tools/synth_pipeline.py'),'--timeout',str(a.timeout)],out/(label+'-synthesis-console.log'),extra_env=config_env)
   report_path=ROOT/'build/yosys-kintex7/slang'/(arch+'-'+mode+'-rf0')/'results.json'
   result=json.loads(report_path.read_text());report['synthesis'].append({'variant':label,**result});save();print(label,result.get('resources'),flush=True)
 print('PASS design suite:',len(report['runs']),'compiled C runs with identical per-kernel retirement hashes');print('Report:',out/'results.json')
if __name__=='__main__':main()
