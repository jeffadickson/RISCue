#!/usr/bin/env python3
"""Compile the packet processor using the audited RISCue compiler profile."""
import json,os,subprocess
from pathlib import Path
from software_profile import load_profile
from check_elf import check
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'build/packet';out.mkdir(parents=True,exist_ok=True)
cc=os.environ.get('RISCV_GCC','riscv64-unknown-elf-gcc')
profile=load_profile();elf=out/'packet.elf'
subprocess.run([cc,*profile['compiler_flags'],'-nostdlib','-nostartfiles','-O2','-Wall','-Wextra','-Werror','-Wl,--no-relax','-T',str(ROOT/'firmware/packet/link.ld'),str(ROOT/'firmware/packet/start.S'),str(ROOT/'firmware/packet/main.c'),'-o',str(elf)],check=True)
audit=check(elf,profile,os.environ.get('RISCV_READELF','riscv64-unknown-elf-readelf'),os.environ.get('RISCV_OBJDUMP','riscv64-unknown-elf-objdump'))
(out/'isa-report.json').write_text(json.dumps(audit,indent=2)+'\n')
subprocess.run([os.environ.get('RISCV_OBJCOPY','riscv64-unknown-elf-objcopy'),'-O','binary',str(elf),str(out/'packet.bin')],check=True)
b=(out/'packet.bin').read_bytes();b+=bytes((-len(b))%4)
(out/'packet.hex').write_text(''.join(f'{int.from_bytes(b[i:i+4],"little"):08x}\n' for i in range(0,len(b),4)))
print(f'Packet firmware: {len(b)} bytes; ISA audit passed')
