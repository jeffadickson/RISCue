#!/usr/bin/env python3
"""Real-binutils negative tests: hidden instruction and broader file metadata."""
import os,subprocess
from pathlib import Path
from check_elf import check
from software_profile import load_profile
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/elf-negative';out.mkdir(parents=True,exist_ok=True)
p=load_profile();cc=os.environ.get('RISCV_GCC','riscv64-unknown-elf-gcc');read=os.environ.get('RISCV_READELF','riscv64-unknown-elf-readelf');dump=os.environ.get('RISCV_OBJDUMP','riscv64-unknown-elf-objdump')
for name,flags,source,diagnostic in [
    ('hidden-a',p['compiler_flags'],ROOT/'tests/fixtures/elf_hidden_a.S','amoadd.w'),
    ('advertised-a',['-march=rv32imac_zicsr_zifencei','-mabi=ilp32'],ROOT/'tests/fixtures/elf_hidden_a.S','Unsupported required extension a')]:
    elf=out/(name+'.elf');subprocess.run([cc,*flags,'-nostdlib','-nostartfiles','-Wl,-Ttext=0',str(source),'-o',str(elf)],check=True)
    try:check(elf,p,read,dump)
    except ValueError as e:
        assert diagnostic in str(e),(name,str(e));print('PASS expected rejection:',name,str(e))
    else:raise AssertionError(name+' unexpectedly accepted')
