#!/usr/bin/env python3
"""Real GDB -> OpenOCD -> JTAG pins -> Verilated RTL acceptance test."""
import argparse,json,os,shutil,subprocess,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def tool(env,local,name):
 value=os.environ.get(env) or (str(ROOT/local) if (ROOT/local).exists() else shutil.which(name))
 if not value:raise SystemExit('Missing '+name+'; run make debug-tools')
 return value

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rf-tmr',type=int,choices=(0,1),default=0);a=p.parse_args()
 out=ROOT/'build/debug';out.mkdir(parents=True,exist_ok=True)
 report_path=ROOT/'verification'/('debug-gdb-tmr.json' if a.rf_tmr else 'debug-gdb-ecc.json')
 report_path.write_text(json.dumps({'passed':False,'status':'incomplete'})+'\n')
 gcc=tool('RISCV_CC','.tools/riscv/root/usr/bin/riscv64-unknown-elf-gcc','riscv64-unknown-elf-gcc')
 elf=out/'example.elf'
 subprocess.run([gcc,'-march=rv32imc_zicsr_zifencei','-mabi=ilp32','-g','-O0','-ffreestanding','-nostdlib','-mno-relax','-Wl,--no-relax','-T',str(ROOT/'tests/debug/link.ld'),str(ROOT/'tests/debug/start.S'),str(ROOT/'tests/debug/example.c'),'-o',str(elf)],check=True)
 oc=tool('OPENOCD','.tools/debug/openocd','openocd');gdb=tool('GDB','.tools/debug/gdb-multiarch','gdb-multiarch')
 model=out/('sim-tmr' if a.rf_tmr else 'sim')/'Vriscue_debug_soc'
 logs=[];processes=[];tag='tmr' if a.rf_tmr else 'ecc'
 try:
  for name,cmd in [('sim',[str(model)]),('openocd',[oc,'-f',str(ROOT/'debug/openocd-sim.cfg')])]:
   f=(out/f'{tag}-{name}.log').open('w');logs.append(f)
   processes.append(subprocess.Popen(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT))
   time.sleep(.3)
  result=subprocess.run([gdb,'--batch','-q',str(elf),'-x',str(ROOT/'tests/debug/check.gdb')],cwd=ROOT,capture_output=True,text=True,timeout=90)
  output=result.stdout+result.stderr;(out/f'{tag}-gdb.log').write_text(output)
  passed=result.returncode==0 and 'PASS RIScue GDB end-to-end' in output
  report={'passed':passed,'rf_tmr':a.rf_tmr,'gdb_returncode':result.returncode,'checks':[x for x in output.splitlines() if x.startswith('PASS')],
    'gdb':subprocess.check_output([gdb,'--version'],text=True).splitlines()[0],
    'openocd':subprocess.run([oc,'--version'],capture_output=True,text=True).stderr.splitlines()[0],
    'elf_sha256':hashlib.sha256(elf.read_bytes()).hexdigest(),
    'rtl_sha256':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((ROOT/'rtl').glob('*.sv')) if 'debug' in path.name or 'jtag' in path.name or 'pipeline' in path.name}}
  (ROOT/'verification'/f'debug-gdb-{tag}.json').write_text(json.dumps(report,indent=2)+'\n')
  print(output)
  if not passed:raise SystemExit('GDB acceptance FAILED; inspect build/debug logs')
 finally:
  for process in reversed(processes):
   process.terminate()
   try:process.wait(timeout=5)
   except subprocess.TimeoutExpired:process.kill();process.wait()
  for f in logs:f.close()
if __name__=='__main__':main()
