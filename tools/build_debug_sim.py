#!/usr/bin/env python3
"""Build the real RTL JTAG target for OpenOCD remote_bitbang."""
import argparse,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rf-tmr',type=int,choices=(0,1),default=0);p.add_argument('--jobs',type=int,default=2);a=p.parse_args()
 tool=os.environ.get('VERILATOR') or shutil.which('verilator') or str(ROOT/'.tools/monitor-verilator/verilator')
 out=ROOT/'build/debug'/('sim-tmr' if a.rf_tmr else 'sim');out.mkdir(parents=True,exist_ok=True)
 names='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core ft_ecc_ram riscue_jtag_dtm riscue_debug_module riscue_debug_soc'.split()
 cmd=[tool,'--cc','--exe','-j',str(a.jobs),'-Wno-fatal','--top-module','riscue_debug_soc',f'-GRF_TMR={a.rf_tmr}','--Mdir',str(out)]
 cmd += [str(ROOT/'rtl'/(n+'.sv')) for n in names]+[str(ROOT/'tests/debug/remote_bitbang.cpp')]
 with (out/'build.log').open('w') as f:
  subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
  # GCC needs a real fallback header when a generated PCH is rejected.
  header=out/'Vriscue_debug_soc__pch.h'
  if header.exists():
   for suffix in ('fast','slow'):shutil.copyfile(header,out/(header.name+'.'+suffix))
  subprocess.run(['make','-C',str(out),'-f','Vriscue_debug_soc.mk','-j',str(a.jobs)],stdout=f,stderr=subprocess.STDOUT,check=True)
 print(out/'Vriscue_debug_soc')
if __name__=='__main__':main()
