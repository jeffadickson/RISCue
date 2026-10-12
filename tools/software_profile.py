#!/usr/bin/env python3
"""Validated software profile shared by Make and upstream builders."""
import argparse,json,re
from pathlib import Path
DEFAULT=Path(__file__).resolve().parents[1]/'docs/software-profile.json'
def load_profile(path=DEFAULT):
    p=json.loads(Path(path).read_text())
    if p['abi']!='ilp32' or p['endianness']!='little':raise ValueError('Only little-endian ILP32 supported')
    if not re.fullmatch(r'rv32[imc]+(?:_z[a-z0-9]+)*',p['isa']):raise ValueError('Invalid profile ISA')
    flags=p['compiler_flags']
    if flags.count('-march='+p['isa'])!=1 or flags.count('-mabi='+p['abi'])!=1:raise ValueError('ISA/ABI flags disagree with profile')
    if sum(f.startswith('-march=') for f in flags)!=1 or sum(f.startswith('-mabi=') for f in flags)!=1:raise ValueError('Conflicting ISA/ABI flags')
    if not all(re.fullmatch(r'-[A-Za-z0-9_=.,+-]+',f) for f in flags):raise ValueError('Unsafe compiler flag')
    return p
def generate_make(p):
    return '# Generated from docs/software-profile.json; do not edit.\nRISCUE_PROFILE_FLAGS := '+' '.join(p['compiler_flags'])+'\n'
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--profile',type=Path,default=DEFAULT);a.add_argument('--make',type=Path);a=a.parse_args()
    p=load_profile(a.profile)
    if a.make:
        a.make.parent.mkdir(parents=True,exist_ok=True);text=generate_make(p)
        if not a.make.exists() or a.make.read_text()!=text:a.make.write_text(text)
    else:print(' '.join(p['compiler_flags']))
