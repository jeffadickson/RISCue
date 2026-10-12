"""Independent Python result model for the compiled workload."""
import zlib
MASK=0xffffffff
def expected():
    state=0x13579bdf
    def rng():
        nonlocal state
        state^=(state<<13)&MASK;state^=state>>17;state^=(state<<5)&MASK;state&=MASK;return state
    data=[(rng()&255)-128 for _ in range(12)]
    a=[];b=[]
    for _ in range(9):a.append((rng()&31)-16);b.append((rng()&31)-16)
    matrix=[sum(a[i*3+k]*b[k*3+j] for k in range(3)) for i in range(3) for j in range(3)]
    h=0
    for v in sorted(data):h=((h<<5)^(h>>27)^(v&MASK))&MASK
    crc=zlib.crc32(b'RISCue flight');product=0
    for j in range(32):
        if (0x1021>>j)&1:product^=crc<<j
    # Python // rounds toward -infinity; RISC-V/C signed division truncates to zero.
    quotient_sum=sum((abs(v)//7)*(-1 if v<0 else 1) for v in matrix)&MASK
    values={0:0x50415353,5:crc,6:13,7:4,8:MASK,9:h,10:quotient_sum,11:crc.bit_count(),12:int.from_bytes(crc.to_bytes(4,'little'),'big'),13:product&MASK,14:1,15:0x80000007}
    values.update({16+j:v&MASK for j,v in enumerate(matrix)})
    return {'mailbox':values,'sorted':sorted(data),'matrix':matrix,'input':data,'matrix_a':a,'matrix_b':b}
