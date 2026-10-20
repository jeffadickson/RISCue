#!/usr/bin/env python3
"""Compare existing implementations; legacy has a smaller ISA and combinational division."""
import argparse,datetime,hashlib,json,os,re,signal,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from pipeline_config import configuration
PIPE='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core'.split()
LEGACY='ft_pkg rv32_execute rv32im_ft_core'.split()
MODES=['LEGACY_RV32IM','TMR','PARITY_REPLAY','PLAIN']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--synthesis',action='store_true');p.add_argument('--timeout',type=int,default=300);p.add_argument('--output',type=Path);a=p.parse_args()
 out=a.output or ROOT/'build'/'architecture-comparison'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
 out.mkdir(parents=True,exist_ok=True);out=out.resolve();(out/'build').mkdir(exist_ok=True)
 env=os.environ.copy();env['PATH']=str(ROOT/'.tools/oss-cad-suite/bin')+os.pathsep+env['PATH']
 report={'scope':'Existing legacy RV32IM versus full-feature pipeline; not ISA/protection/timing equivalent. Core-only quick Series-7 resource estimates; no placement/timing.', 'output':str(out),'source_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [*(ROOT/'rtl').glob('*.sv'),ROOT/'tests/tb_architecture_compare.sv']},'clock_assumption':'Compare core clocks only; no measured Fmax or elapsed-time performance claim','memory_model':'Same 512-word single-port synchronous response model for all modes; ECC codec bypass only for PLAIN','benchmarks':[],'synthesis':[]}
 def save():(out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,log,cwd=out,limit=a.timeout):
  with log.open('w') as f:
   proc=subprocess.Popen(cmd,cwd=cwd,env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
   try:code=proc.wait(timeout=limit)
   except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait();raise
  if code:raise RuntimeError(str(cmd)+' failed; '+log.read_text()[-2200:])
 def flags(mode):return [] if mode=='LEGACY_RV32IM' else configuration(mode,'1' if mode=='PARITY_REPLAY' else '0','PIPELINED')['iverilog_flags']
 subprocess.run([sys.executable,str(ROOT/'tools/gen_program.py')],cwd=out,env=env,check=True)
 mixed_hex=(out/'build/program.hex').read_text();mixed_trace=(out/'build/program.trace').read_text()
 workloads=[('mixed_rv32im',mixed_hex,mixed_trace)]
 # A dependent ADDI stream isolates fetch/issue overhead without multiply/divide differences.
 instructions=[0x00108093]*200+[0x00100073];image=instructions+[0]*(512-len(instructions))
 trace=''.join(f'{4*i:08x} {instructions[i]:08x} 00000001 {i+1:08x}\n' for i in range(200))
 workloads.append(('dependent_addi',''.join(f'{x:08x}\n' for x in image),trace))
 executables={}
 for mode in MODES:
  names=LEGACY if mode=='LEGACY_RV32IM' else PIPE
  extra=['-DCOMPARE_LEGACY'] if mode=='LEGACY_RV32IM' else (['-DCOMPARE_PLAIN'] if mode=='PLAIN' else [])
  exe=out/(mode+'.vvp');run(['iverilog','-g2012','-s','tb_architecture_compare',*flags(mode),*extra,'-o',str(exe),*[str(ROOT/'rtl'/(n+'.sv')) for n in names],str(ROOT/'tests/tb_architecture_compare.sv')],out/(mode+'-compile.log'))
  executables[mode]=exe
 for label,image,trace in workloads:
  (out/(label+'.hex')).write_text(image);(out/(label+'.trace')).write_text(trace)
  (out/'build/program.hex').write_text(image);(out/'build/program.trace').write_text(trace);expected=len(trace.splitlines())
  for mode in MODES:
   log=out/(label+'-'+mode+'.log');run(['vvp',str(executables[mode]),'+expected='+str(expected)],log)
   match=re.search(r'COMPARE_PASS retired=(\d+) cycles=(\d+)',log.read_text());assert match,log.read_text()
   retired,cycles=map(int,match.groups());row={'mode':mode,'workload':label,'retired':retired,'cycles':cycles,'cycles_per_instruction':cycles/retired};report['benchmarks'].append(row);save();print(row,flush=True)
 if a.synthesis:
  for mode in MODES:
   dest=out/mode;dest.mkdir(exist_ok=True);names=LEGACY if mode=='LEGACY_RV32IM' else PIPE;top='rv32im_ft_core' if mode=='LEGACY_RV32IM' else 'riscue_pipeline_core'
   abc=dest/'abc.script';abc.write_text('strash\nif -K 6\n');script=dest/'synth.ys'
   reader='read_slang --best-effort-hierarchy --unroll-limit 16384 --top '+top+' -G RF_TMR=0 -G FI_ENABLE=0 '+('' if mode=='LEGACY_RV32IM' else '-G DEBUG_ENABLE=0 ')+' '.join(flags(mode))+' '+' '.join(str(ROOT/'rtl'/(n+'.sv')) for n in names)
   preserve='setattr -unset keep\nsetattr -unset DONT_TOUCH\nsetattr -mod -unset keep_hierarchy\n' if mode=='PLAIN' else 'setattr -set keep 1 t:$dff t:$adff t:$dffe t:$sdff t:$sdffe\n'
   script.write_text(reader+'\nhierarchy -check -top '+top+'\nproc\nmemory_map\nopt_expr\nopt_clean\nopt_dff\n'+preserve+'opt\nsynth_xilinx -family xc7 -top '+top+' -flatten -noiopad -noclkbuf -run begin:map_luts\nabc -lut 6 -script '+str(abc)+'\ntechmap -map +/xilinx/lut_map.v -map +/xilinx/cells_map.v -D LUT_WIDTH=6\nopt_lut_ins -tech xilinx\nsynth_xilinx -family xc7 -top '+top+' -noiopad -noclkbuf -run finalize:edif\ncheck -assert\ntee -o '+str(dest/'statistics.json')+' stat -json -top '+top+'\n')
   row={'mode':mode,'status':'incomplete','protection_audit':'not performed; resource comparison only'};start=time.monotonic();print('SYNTHESIS',mode,flush=True)
   try:
    run([str(ROOT/'.tools/oss-cad-suite/bin/yosys'),'-m','slang','-Q','-q','-s',str(script)],dest/'synthesis.log')
    stats=json.loads((dest/'statistics.json').read_text());cells=stats['design']['num_cells_by_type'];row.update(status='pass',LUTs=sum(v for k,v in cells.items() if k.startswith('LUT')),flip_flops=sum(v for k,v in cells.items() if k.startswith('FD')),DSPs=sum(v for k,v in cells.items() if k.startswith('DSP')),BRAMs=sum(v for k,v in cells.items() if k.startswith('RAMB')))
   except Exception as e:row.update(status='failed',error=str(e))
   row['seconds']=round(time.monotonic()-start,2);report['synthesis'].append(row);save();print(row,flush=True)
 save();print('Report:',out/'results.json',flush=True)
 if any(x['status']!='pass' for x in report['synthesis']):return 1
 return 0
if __name__=='__main__':raise SystemExit(main())
