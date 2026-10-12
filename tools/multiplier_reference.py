#!/usr/bin/env python3
"""Independent arbitrary-precision references and deterministic operand sets."""
import random
from pathlib import Path
MASK=0xffffffff
EDGES=[0,1,MASK,0x80000000,0x7fffffff,0xaaaaaaaa,0x55555555,0x00010000]
def signed(x):return x-(1<<32) if x&0x80000000 else x
def multiply(op,a,b):
    if op==0:return (a*b)&MASK
    product=(signed(a) if op in (1,2) else a)*(signed(b) if op==1 else b)
    return (product>>32)&MASK
def full_core_pairs():
    rng=random.Random(0x4d554c)
    return [(a,b) for a in EDGES for b in EDGES]+[(rng.getrandbits(32),rng.getrandbits(32)) for _ in range(64)]
def vectors():
    for a in range(-128,128):
        for b in range(-128,128):
            for op in range(4):yield op,a&MASK,b&MASK,multiply(op,a&MASK,b&MASK)
    rng=random.Random(0x4d554c)
    for a,b in [(a,b) for a in EDGES for b in EDGES]+[(rng.getrandbits(32),rng.getrandbits(32)) for _ in range(512)]:
        for op in range(4):yield op,a,b,multiply(op,a,b)
def fir_reference():
    coeff=[32767,-32768,16384,-8192,4096,-2048,1024,-512,256,-128,64,-32,16,-8,4,-2,1,-1,12345,-23456,30000,-30000,777,-999,42,-73,8191,-8193,2047,-2049,17,-19]
    state=0x31415926;samples=[]
    for _ in range(35):
        state^=(state<<13)&MASK;state^=state>>17;state^=(state<<5)&MASK;state&=MASK;samples.append(signed(state))
    samples[:6]=[-2147483648,2147483647,-1,0,1,-123456789]
    outputs=[];words=[0x50415353]
    for n in range(4):
        acc=sum(samples[n+k]*coeff[k] for k in range(32));scaled=(abs(acc)//32768)*(-1 if acc<0 else 1);clipped=max(-2147483648,min(2147483647,scaled));outputs.append({'accumulator':acc,'scaled':scaled,'clipped':clipped});words.extend([acc&MASK,(acc>>32)&MASK,clipped&MASK])
    words.append(128);return {'samples':samples,'coefficients':coeff,'outputs':outputs,'mailbox':words}
if __name__=='__main__':
    p=Path('build/multiplier_vectors.txt');p.parent.mkdir(exist_ok=True);count=0
    with p.open('w') as f:
        for op,a,b,v in vectors():f.write(f'{op:x} {a:08x} {b:08x} {v:08x}\n');count+=1
    print(count,'Python-reference multiply vectors')
