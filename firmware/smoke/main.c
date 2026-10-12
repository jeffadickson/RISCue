/* Freestanding C workload. Volatile inputs prevent constant-folding the test.
 * Target-specific helpers exercise instructions with no ordinary C operator. */
typedef unsigned int u32;
static volatile u32 inputs[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
static volatile u32 divisor = 7;
static volatile u32 bit_input = 0x12345678u;
static volatile u32 polynomial = 0x1021u;
static volatile u32 scratch[16];
static u32 clmul(u32 a, u32 b) { u32 v; __asm__("clmul %0,%1,%2" : "=r"(v) : "r"(a),"r"(b)); return v; }
static u32 bset(u32 a, u32 n) { u32 v; __asm__("bset %0,%1,%2" : "=r"(v) : "r"(a),"r"(n)); return v; }
extern volatile u32 mailbox[9]; /* Address assigned by the linker script. */
int main(void) {
    volatile u32 *out = mailbox;
    u32 sum=0;
    for (u32 j=0;j<16;++j) { u32 x=inputs[j]; scratch[j]=x*x; sum+=scratch[j]; }
    u32 x=bit_input, d=divisor;
    out[1]=sum; out[2]=sum/d; out[3]=sum%d;
    out[4]=(x>>7)|(x<<25);
    out[5]=(u32)__builtin_popcount(x);
    out[6]=clmul(x,polynomial);
    out[7]=bset(x,31);
    out[8]=scratch[15];
    out[0]=0x50415353u; /* PASS signature written after all results. */
    return 0;
}
