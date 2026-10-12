#!/usr/bin/env python3
"""Fetch checksum-pinned Ubuntu Noble GCC/binutils into .tools/riscv.
Explicit opt-in; no system installation. Linux x86-64 and dpkg-deb required.
"""
import hashlib,platform,shutil,subprocess,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'.tools/riscv'
PACKAGES=[('gcc','g/gcc-riscv64-unknown-elf/gcc-riscv64-unknown-elf_13.2.0-11ubuntu1+12_amd64.deb','47d4670801c391c65513e2002a19280c6bbdba158f5a467ac5100bff813de0e3'),('binutils','b/binutils-riscv64-unknown-elf/binutils-riscv64-unknown-elf_2.42-1ubuntu1+6_amd64.deb','d42d42efdaa0563155d0e1263675852255b20864cc525db9265247a5dec2ce30')]
if platform.system()!='Linux' or platform.machine() not in ('x86_64','AMD64') or not shutil.which('dpkg-deb'):raise SystemExit('Requires Linux x86-64 and dpkg-deb; otherwise install a native RISC-V GCC/binutils toolchain')
ROOT.mkdir(parents=True,exist_ok=True)
for name,path,expected in PACKAGES:
    deb=ROOT/(name+'.deb')
    if not deb.exists() or hashlib.sha256(deb.read_bytes()).hexdigest()!=expected:
        tmp=deb.with_suffix('.tmp')
        with urllib.request.urlopen('https://archive.ubuntu.com/ubuntu/pool/universe/'+path,timeout=60) as src,tmp.open('wb') as out:shutil.copyfileobj(src,out)
        if hashlib.sha256(tmp.read_bytes()).hexdigest()!=expected:tmp.unlink();raise SystemExit(name+' checksum mismatch')
        tmp.replace(deb)
    subprocess.run(['dpkg-deb','-x',str(deb),str(ROOT/'root')],check=True)
print('Toolchain extracted:',ROOT/'root/usr/bin')
