#!/usr/bin/env python3
"""Independent integer reference for ratified RV32 Zbb/Zbc/Zbs 1.0.
Encodings: riscv/riscv-opcodes extensions rv{,32}_zbb/zbc/zbs.
"""
import random
from pathlib import Path
MASK=(1<<32)-1
REG={'andn':(0x20,7),'orn':(0x20,6),'xnor':(0x20,4),'min':(5,4),'minu':(5,5),'max':(5,6),'maxu':(5,7),'zext.h':(4,4),'rol':(0x30,1),'ror':(0x30,5),'clmul':(5,1),'clmulr':(5,2),'clmulh':(5,3),'bclr':(0x24,1),'bext':(0x24,5),'binv':(0x34,1),'bset':(0x14,1)}
UNARY={'clz':(0x600,1),'ctz':(0x601,1),'cpop':(0x602,1),'sext.b':(0x604,1),'sext.h':(0x605,1),'orc.b':(0x287,5),'rev8':(0x698,5)}
IMM={'rori':(0x30,5),'bclri':(0x24,1),'bexti':(0x24,5),'binvi':(0x34,1),'bseti':(0x14,1)}
NAMES=tuple(REG)+tuple(UNARY)+tuple(IMM)
def instruction(name,rd=3,rs1=1,rs2=2,shamt=0):
    if name in REG:
        f7,f3=REG[name];return (f7<<25)|((0 if name=='zext.h' else rs2)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|0x33
    imm,f3=UNARY[name] if name in UNARY else ((IMM[name][0]<<5)|shamt,IMM[name][1])
    return (imm<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|0x13
def signed(x):return x-(1<<32) if x>>31 else x
def reference(name,a,b):
    n=b&31
    if name=='andn':v=a&~b
    elif name=='orn':v=a|~b
    elif name=='xnor':v=~(a^b)
    elif name=='clz':v=32-a.bit_length()
    elif name=='ctz':v=(a&-a).bit_length()-1 if a else 32
    elif name=='cpop':v=a.bit_count()
    elif name in ('min','max'):v=(min if name=='min' else max)(signed(a),signed(b))
    elif name in ('minu','maxu'):v=(min if name=='minu' else max)(a,b)
    elif name.startswith('sext.'):
        bits=8 if name=='sext.b' else 16;v=a&((1<<bits)-1);v=v-(1<<bits) if v>>(bits-1) else v
    elif name=='zext.h':v=a&65535
    elif name=='rol':v=((a<<32)|a)>>(32-n)
    elif name in ('ror','rori'):v=((a<<32)|a)>>n
    elif name=='orc.b':v=sum(255<<(8*j) for j in range(4) if (a>>(8*j))&255)
    elif name=='rev8':v=int.from_bytes(a.to_bytes(4,'little'),'big')
    elif name.startswith('clmul'):
        # Polynomial convolution, deliberately not a shifted-word implementation.
        product=0
        for j in range(32):
            for k in range(32):product^=(((a>>j)&1)&((b>>k)&1))<<(j+k)
        v=product>>({'clmul':0,'clmulh':32,'clmulr':31}[name])
    elif name.startswith('bclr'):v=a&~(1<<n)
    elif name.startswith('bext'):v=(a>>n)&1
    elif name.startswith('binv'):v=a^(1<<n)
    elif name.startswith('bset'):v=a|(1<<n)
    else:raise ValueError(name)
    return v&MASK
def vectors():
    rng=random.Random(0xB17B17)
    edges=[0,1,0x80000000,MASK,0x7fffffff,0x01008000,0xaaaa5555,0x80008080]
    for name in NAMES:
        pairs=[(a,b) for a in edges for b in edges]+[(rng.getrandbits(32),rng.getrandbits(32)) for _ in range(64)]
        if name in IMM:pairs += [(a,n) for a in edges for n in range(32)]
        for a,b in pairs:
            yield instruction(name,shamt=b&31),a,b,reference(name,a,b),0
    # Reserved RV32 shamt[5], RV64 REV8, nonzero rs2 for ZEXT.H,
    # absent Zba/Zicond, unary reserved subopcode and wrong funct3.
    for word in [instruction(n,shamt=31)|(1<<25) for n in IMM]+[0x6b805193,instruction('zext.h')|(1<<20),0x60309193,0x2000a1b3,0x0e00d1b3]:
        yield word,MASK,31,0,1
if __name__=='__main__':
    path=Path('build/bitmanip_vectors.txt');path.parent.mkdir(exist_ok=True)
    rows=list(vectors());path.write_text(''.join(f'{w:08x} {a:08x} {b:08x} {v:08x} {bad:x}\n' for w,a,b,v,bad in rows));print(len(rows),'bitmanip vectors')
