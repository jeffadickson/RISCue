#!/usr/bin/env python3
"""Derive packed-layout FI windows from the same RTL declarations as the core."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sizes={};layouts={}
for filename in ('rtl/ft_pkg.sv','rtl/riscue_pipeline_pkg.sv'):
    source=re.sub(r'//[^\n]*','',(ROOT/filename).read_text())
    for body,name in re.findall(r'typedef\s+struct\s+packed\s*\{(.*?)\}\s*(\w+)\s*;',source,re.S):
        fields=[]
        for statement in body.split(';'):
            statement=statement.strip()
            if not statement:continue
            m=re.fullmatch(r'(logic|\w+_t)\s*(?:signed\s*)?(?:\[(\d+):(\d+)\]\s*)?(.+)',statement,re.S)
            if not m:raise ValueError(statement)
            typ,hi,lo,names=m.groups();width=(abs(int(hi)-int(lo))+1 if hi else 1) if typ=='logic' else sizes[typ]
            for field in names.split(','):fields.append({'field':field.strip(),'width':width})
        width=sum(f['width'] for f in fields);offset=width
        for f in fields:offset-=f['width'];f['lsb']=offset;f['msb']=offset+f['width']-1
        sizes[name]=width;layouts[name]=fields
bits=sizes['state_t'];windows=(bits+511)//512
result={'abi':2,'core_bits':bits,'core_windows':[{'index':n,'lsb':512*n,'width':min(512,bits-512*n)} for n in range(windows)],'core_fields':layouts['state_t'],'slot_fields':layouts['slot_t'],'arithmetic_bits':sizes['md_state_t'],'arithmetic_fields':layouts['md_state_t']}
(ROOT/'docs/injection-map.json').write_text(json.dumps(result,indent=2)+'\n')
print('FI ABI 2:',bits,'core bits;',windows,'windows;',sizes['md_state_t'],'arithmetic bits')
