#!/usr/bin/env python3
"""Copy pinned models and fix signed DIV/REM expression context explicitly.

Never edits the upstream checkout. Unsigned ternary alternatives otherwise
coerce the signed division/remainder operands to unsigned under Verilog rules.
"""
import shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def prepare_models(destination):
 destination=Path(destination)
 shutil.copytree(ROOT/'third_party/riscv-formal/insns',destination,dirs_exist_ok=True)
 for name,operator in [('div','/'),('rem','%')]:
  p=destination/('insn_'+name+'.v');s=p.read_text()
  expression=f'$signed(rvfi_rs1_rdata) {operator} $signed(rvfi_rs2_rdata)'
  if s.count(expression)!=1:raise RuntimeError('Unexpected pinned '+name+' model; inspect patch')
  s=s.replace(expression,'signed_result')
  declaration=f'  wire signed [`RISCV_FORMAL_XLEN-1:0] signed_result = {expression};\n'
  marker='  // '+name.upper()+' instruction\n'
  if marker not in s:raise RuntimeError('Missing model patch location')
  s=s.replace(marker,marker+declaration)
  p.write_text(s)
 return destination
