"""Generate a deterministic random RV32IM program and architectural trace."""
from pathlib import Path
from gen_vectors import oracle,rr,ii,s,mask
import random
rng=random.Random(0x46544350)
def I(op,rd,rs,f,imm):return ((imm&4095)<<20)|(rs<<15)|(f<<12)|(rd<<7)|op
def S(rs,val,f,imm):return ((imm>>5)<<25)|(val<<20)|(rs<<15)|(f<<12)|((imm&31)<<7)|0x23
def B(f,a,b,offset):return ((offset>>12&1)<<31)|((offset>>5&63)<<25)|(b<<20)|(a<<15)|(f<<12)|((offset>>1&15)<<8)|((offset>>11&1)<<7)|0x63
program=[I(0x13,1,0,0,1024)]+[I(0x13,r,0,0,rng.randrange(-2048,2048)) for r in range(2,32)]
for _ in range(200):
 kind=rng.randrange(7);rd=rng.randrange(2,32);a=rng.randrange(32);b=rng.randrange(32)
 if kind<=1:
  f=rng.randrange(8);f7=rng.choice([0,1]);program.append((f7<<25)|(b<<20)|(a<<15)|(f<<12)|(rd<<7)|0x33)
 elif kind==2:
  f=rng.randrange(8);imm=rng.randrange(-2048,2048)
  if f in (1,5):imm=rng.randrange(32)|((rng.randrange(2)*32<<5) if f==5 else 0)
  program.append(I(0x13,rd,a,f,imm))
 elif kind==3:
  f=rng.choice([0,1,2,4,5]);offset=rng.randrange(64);offset&=~((1<<(f%4 if f<4 else f-4))-1)
  program.append(I(3,rd,1,f,offset))
 elif kind==4:
  f=rng.randrange(3);offset=rng.randrange(64)&~((1<<f)-1);program.append(S(1,b,f,offset))
 elif kind==5:program.append(B(rng.choice([0,1,4,5,6,7]),a,b,8))
 else:program.append(0x0080006f|(rd<<7)) # jal +8
program += [I(0x13,2,2,0,1),0x00100073]
regs=[0]*32;memory=bytearray(2048);pc=0;trace=[]
while True:
 ins=program[pc//4];op=ins&127;f=(ins>>12)&7;f7=ins>>25;rd=(ins>>7)&31;rs1=(ins>>15)&31;rs2=(ins>>20)&31;a=regs[rs1];b=regs[rs2];imm=ins>>20;imm=imm if imm<2048 else imm-4096
 npc=pc+4;value=0;dest=0
 if ins==0x00100073:break
 if op==0x33:value=oracle(f,f7,a,b);dest=rd
 elif op==0x13:
  value=oracle(f,(f7 if f in (1,5) else 0),a,(imm&mask));dest=rd
 elif op==3:
  addr=a+imm;width={0:1,1:2,2:4,4:1,5:2}[f];value=int.from_bytes(memory[addr:addr+width],'little',signed=f<2)&mask;dest=rd
 elif op==0x23:
  simm=((ins>>25)<<5)|((ins>>7)&31);simm=simm if simm<2048 else simm-4096;addr=a+simm;width=1<<f;memory[addr:addr+width]=(b&((1<<(8*width))-1)).to_bytes(width,'little')
 elif op==0x63:
  take={0:a==b,1:a!=b,4:s(a)<s(b),5:s(a)>=s(b),6:a<b,7:a>=b}[f];npc=pc+(8 if take else 4)
 elif op==0x6f:dest=rd;value=pc+4;npc=pc+8
 else:raise AssertionError(hex(ins))
 if dest:regs[dest]=value
 trace.append((pc,ins,dest,value));pc=npc
image=program+[0]*(512-len(program))
Path('build/program.hex').write_text(''.join(f'{i:08x}\n' for i in image))
Path('build/program.trace').write_text(''.join(' '.join(f'{i:08x}' for i in t)+'\n' for t in trace))
Path('build/program.regs').write_text(''.join(f'{i:08x}\n' for i in regs))
print(f'Generated program: {len(program)} words, {len(trace)} expected retirements')
