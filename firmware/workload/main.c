/* Small flight-computer-like workload; deterministic volatile inputs.
 * All arithmetic ranges are bounded to avoid signed overflow. No libc needed. */
typedef unsigned int u32;
typedef int s32;
extern volatile u32 mailbox[32];
static volatile u32 seed=0x13579bdfu;
static volatile u32 irq_count,irq_cause,irq_pc;
static volatile s32 sorted[12],matrix_a[9],matrix_b[9],matrix_c[9];
static const unsigned char packet[]="RISCue flight";
#define CSR_READ(n) ({u32 v;__asm__ volatile("csrr %0," #n:"=r"(v));v;})
#define CSR_WRITE(n,v) __asm__ volatile("csrw " #n ",%0"::"r"((u32)(v)):"memory")
#define MTIME (*(volatile u32 *)0x0200bff8u)
#define MTIMECMP ((volatile u32 *)0x02004000u)
__attribute__((noinline)) void trap_c(u32 cause,u32 pc,u32 value) {
    (void)value;irq_cause=cause;irq_pc=pc;
    if(cause==0x80000007u) {irq_count++;CSR_WRITE(mie,0);MTIMECMP[1]=0xffffffffu;MTIMECMP[0]=0xffffffffu;}
    else {mailbox[0]=0x4641494cu;mailbox[31]=cause;for(;;)__asm__ volatile("wfi");}
}
static u32 random_word(void) {u32 x=seed;x^=x<<13;x^=x>>17;x^=x<<5;seed=x;return x;}
__attribute__((noinline)) static void insertion_sort(void) {
    for(u32 j=1;j<12;j++) {s32 key=sorted[j];u32 k=j;while(k && sorted[k-1]>key){sorted[k]=sorted[k-1];k--;}sorted[k]=key;}
}
__attribute__((noinline)) static s32 find_value(s32 key) {
    s32 lo=0,hi=11;
    while(lo<=hi){s32 mid=(lo+hi)/2,s=sorted[mid];if(s==key)return mid;if(s<key)lo=mid+1;else hi=mid-1;}
    return -1;
}
__attribute__((noinline)) static void matrix_multiply(void) {
    for(u32 i=0;i<3;i++)for(u32 j=0;j<3;j++){
        s32 sum=0;for(u32 k=0;k<3;k++)sum+=matrix_a[i*3+k]*matrix_b[k*3+j];matrix_c[i*3+j]=sum;
    }
}
__attribute__((noinline)) static u32 crc32(void) {
    u32 crc=0xffffffffu;
    for(u32 j=0;j<sizeof(packet)-1;j++){crc^=packet[j];for(u32 k=0;k<8;k++)crc=(crc>>1)^((0u-(crc&1u))&0xedb88320u);}
    return ~crc;
}
__attribute__((noinline)) static u32 fib(u32 n) {if(n<2)return n;return fib(n-1)+fib(n-2);}
static u32 clmul(u32 a,u32 b){u32 v;__asm__("clmul %0,%1,%2":"=r"(v):"r"(a),"r"(b));return v;}
int main(void) {
    for(u32 j=0;j<12;j++)sorted[j]=(s32)(random_word()&255u)-128;
    for(u32 j=0;j<9;j++){matrix_a[j]=(s32)(random_word()&31u)-16;matrix_b[j]=(s32)(random_word()&31u)-16;}
    /* Single timer interrupt during normal work. High compare write first. */
    MTIMECMP[1]=0xffffffffu;MTIMECMP[0]=MTIME+500u;MTIMECMP[1]=0;
    CSR_WRITE(mie,128u);CSR_WRITE(mstatus,8u);
    u32 t=CSR_READ(mcycle);insertion_sort();mailbox[1]=CSR_READ(mcycle)-t;
    t=CSR_READ(mcycle);matrix_multiply();mailbox[2]=CSR_READ(mcycle)-t;
    t=CSR_READ(mcycle);u32 crc=crc32();mailbox[3]=CSR_READ(mcycle)-t;
    t=CSR_READ(mcycle);u32 f=fib(7);mailbox[4]=CSR_READ(mcycle)-t;
    mailbox[5]=crc;mailbox[6]=f;mailbox[7]=(u32)find_value(sorted[4]);mailbox[8]=(u32)find_value(1000);
    u32 hash=0;for(u32 j=0;j<12;j++)hash=(hash<<5)^(hash>>27)^(u32)sorted[j];mailbox[9]=hash;
    u32 sum=0;for(u32 j=0;j<9;j++){mailbox[16+j]=(u32)matrix_c[j];sum+=(u32)(matrix_c[j]/7);}mailbox[10]=sum;
    mailbox[11]=(u32)__builtin_popcount(crc);mailbox[12]=__builtin_bswap32(crc);mailbox[13]=clmul(crc,0x1021u);
    while(!irq_count)__asm__ volatile("wfi");
    mailbox[14]=irq_count;mailbox[15]=irq_cause;mailbox[25]=irq_pc;
    CSR_WRITE(mstatus,0);mailbox[26]=CSR_READ(minstret);mailbox[27]=CSR_READ(mcycle);
    mailbox[0]=0x50415353u;
    return 0;
}
