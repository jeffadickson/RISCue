#!/usr/bin/env python3
"""Directed compact-state correction and illegal-phase checks."""
import argparse,itertools,json,subprocess
from pathlib import Path
from simulation_build import build_verilator
r=Path(__file__).resolve().parents[1];out=r/'build/multicycle-faults';out.mkdir(exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--simulator',choices=('verilator','iverilog'),default='verilator');args=parser.parse_args()
codes=[0,15,51,60,85,90]
assert min((a^b).bit_count() for a,b in itertools.combinations(codes,2))>=3
rtl='ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core'.split()
if args.simulator=='verilator':
 exe,manifest=build_verilator(r,r/'tests/tb_multicycle_faults.sv',rtl,[],'compact-faults',out/'compile.log')
 (out/'simulation-build.json').write_text(json.dumps(manifest,indent=2)+'\n')
 command=[str(exe)]
else:
 cmd=['iverilog','-g2012','-s','tb_multicycle_faults','-o',str(out/'sim')]+[str(r/'rtl'/(x+'.sv')) for x in rtl]+[str(r/'tests/tb_multicycle_faults.sv')]
 p=subprocess.run(cmd,capture_output=True,text=True);(out/'compile.log').write_text(p.stdout+p.stderr);assert p.returncode==0,p.stderr[-2000:]
 command=['vvp',str(out/'sim')]
p=subprocess.run(command,capture_output=True,text=True,timeout=600);(out/'run.log').write_text(p.stdout+p.stderr)
print(p.stdout);assert p.returncode==0 and 'PASS compact state:' in p.stdout,p.stdout+p.stderr
