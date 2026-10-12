"""Independent arithmetic oracle and instruction encoder; reproducible seed."""
import random
from pathlib import Path
R=random.Random(0x52563332)
mask=0xffffffff
s=lambda x:x if x<0x80000000 else x-0x100000000

def rr(f3,f7):return (f7<<25)|(2<<20)|(1<<15)|(f3<<12)|(3<<7)|0x33

def ii(f3,imm):return ((imm&4095)<<20)|(1<<15)|(f3<<12)|(3<<7)|0x13

def oracle(f3,f7,a,b):
 if f7==1:
  if f3==0:return a*b&mask
  if f3==1:return (s(a)*s(b)>>32)&mask
  if f3==2:return (s(a)*b>>32)&mask
  if f3==3:return (a*b>>32)&mask
  if f3 in (4,6):
   if b==0:return mask if f3==4 else a
   q=abs(s(a))//abs(s(b));q=-q if (s(a)<0)!=(s(b)<0) else q
   return (q if f3==4 else s(a)-q*s(b))&mask
  return (mask if b==0 else a//b) if f3==5 else (a if b==0 else a%b)
 if f3==0:return (a-b if f7==32 else a+b)&mask
 if f3==1:return (a<<(b&31))&mask
 if f3==2:return int(s(a)<s(b))
 if f3==3:return int(a<b)
 if f3==4:return a^b
 if f3==5:return ((s(a) if f7==32 else a)>>(b&31))&mask
 if f3==6:return a|b
 return a&b

rows=[]
edge=[0,1,2,31,32,0x7fffffff,0x80000000,0xfffffffe,mask]
for f7 in [0,1,32]:
 for f3 in range(8):
  if f7==32 and f3 not in [0,5]:continue
  pairs=[(a,b) for a in edge for b in edge]+[(R.getrandbits(32),R.getrandbits(32)) for _ in range(160)]
  for a,b in pairs:rows.append((rr(f3,f7),a,b,oracle(f3,f7,a,b)))
for f3 in range(8):
 for _ in range(200):
  a=R.getrandbits(32);imm=R.randrange(-2048,2048)
  if f3 in (1,5):
   shift=R.randrange(32);f7=32 if f3==5 and R.randrange(2) else 0
   insn=ii(f3,(f7<<5)|shift);expect=oracle(f3,f7,a,shift)
  else:insn=ii(f3,imm);expect=oracle(f3,0,a,imm&mask)
  rows.append((insn,a,R.getrandbits(32),expect))
Path('build').mkdir(exist_ok=True)
Path('build/exec_vectors.txt').write_text(''.join(' '.join(f'{v:08x}' for v in r)+'\n' for r in rows))
print(f'Generated {len(rows)} execution vectors')
