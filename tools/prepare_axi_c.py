#!/usr/bin/env python3
"""Prepare existing built C images and independent result masks for AXI RAM tests."""
import json
from pathlib import Path
from multiplier_reference import fir_reference
from workload_reference import expected
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/axi-c';out.mkdir(parents=True,exist_ok=True)
x=0x12345678;product=0
for k in range(32):
    if 0x1021&(1<<k):product^=x<<k
smoke=[0x50415353,1496,213,5,((x>>7)|(x<<25))&0xffffffff,x.bit_count(),product&0xffffffff,x|0x80000000,256]
for name,words,golden in [('smoke',1024,dict(enumerate(smoke))),('workload',2048,expected()['mailbox']),('fir',2048,dict(enumerate(fir_reference()['mailbox'])))]:
    folder=ROOT/('build/c-'+name);meta=json.loads((folder/'metadata.json').read_text());data=(folder/'smoke.bin').read_bytes();assert len(data)<=words*4
    image=data.ljust(words*4,b'\0');(out/(name+'.hex')).write_text(''.join(f'{int.from_bytes(image[k:k+4],"little"):08x}\n' for k in range(0,len(image),4)))
    (out/(name+'.expected')).write_text(''.join(f'{golden[k]:08x}\n' if k in golden else 'xxxxxxxx\n' for k in range(32)))
    (out/(name+'.finish')).write_text(str(meta['finish_pc']))
print('Prepared smoke, workload and FIR for CPU -> AXI -> ECC RAM')
