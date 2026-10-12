#!/usr/bin/env python3
"""Cross-check signed-model fixes using Icarus and concrete ISA edge cases."""
import os,subprocess
from pathlib import Path
from prepare_formal_models import ROOT,prepare_models
build=ROOT/'build/model-context';build.mkdir(parents=True,exist_ok=True)
models=prepare_models(build/'models')
env=os.environ.copy();env['PATH']=str(ROOT/'.tools/oss-cad-suite/bin')+os.pathsep+env['PATH']
for patched in (False,True):
 source=models if patched else ROOT/'third_party/riscv-formal/insns'
 binary=build/('patched' if patched else 'original')
 args=['iverilog','-g2012','-DRISCV_FORMAL_XLEN=32','-DRISCV_FORMAL_ILEN=32']
 if patched:args+=['-DPATCHED_MODEL']
 args+=['-s','tb_formal_model_context','-o',str(binary),str(ROOT/'rtl/ft_pkg.sv'),str(ROOT/'rtl/rv32_execute.sv'),str(source/'insn_div.v'),str(source/'insn_rem.v'),str(ROOT/'tests/tb_formal_model_context.sv')]
 subprocess.run(args,env=env,check=True);subprocess.run(['vvp',str(binary)],env=env,check=True)
