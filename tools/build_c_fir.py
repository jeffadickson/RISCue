#!/usr/bin/env python3
"""Compile actual C, audit its linked ELF, and make simulation metadata."""
import hashlib,json,os,re,subprocess
from pathlib import Path
from software_profile import load_profile
from check_elf import check
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/c-fir';out.mkdir(parents=True,exist_ok=True)
profile=load_profile();cc=os.environ.get('RISCV_GCC','riscv64-unknown-elf-gcc');copy=os.environ.get('RISCV_OBJCOPY','riscv64-unknown-elf-objcopy');dump=os.environ.get('RISCV_OBJDUMP','riscv64-unknown-elf-objdump');read=os.environ.get('RISCV_READELF','riscv64-unknown-elf-readelf');nm=os.environ.get('RISCV_NM','riscv64-unknown-elf-nm')
elf=out/'smoke.elf';binary=out/'smoke.bin'
command=[cc,*profile['compiler_flags'],'-nostdlib','-nostartfiles','-O2','-Wall','-Wextra','-Werror','-Wl,--no-relax','-T',str(ROOT/'firmware/fir/link.ld'),str(ROOT/'firmware/fir/start.S'),str(ROOT/'firmware/fir/main.c'),'-o',str(elf)]
subprocess.run(command,check=True)
audit=check(elf,profile,read,dump);(out/'isa-report.json').write_text(json.dumps(audit,indent=2)+'\n')
subprocess.run([copy,'-O','binary',str(elf),str(binary)],check=True)
listing=subprocess.check_output([dump,'-d','-z','-M','no-aliases,numeric',str(elf)],text=True);(out/'smoke.dis').write_text(listing)
syms=subprocess.check_output([nm,str(elf)],text=True);finish=int(re.search(r'^([0-9a-fA-F]+)\s+\w\s+_finished$',syms,re.M).group(1),16)
meta={'symbols':{line.split()[2]:int(line.split()[0],16) for line in syms.splitlines() if len(line.split())==3 and line.split()[1].lower()=='t'},'compiler':subprocess.check_output([cc,'--version'],text=True).splitlines()[0],'command':command,'finish_pc':finish,'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'mailbox_address':0x1f00,'isa_report':audit}
(out/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta,indent=2))
