/* 32-tap signed FIR: 32-bit sensor samples, Q1.15 coefficients,
 * 64-bit accumulation. Bound: 32*2^31*32768 = 2^51, within int64. */
typedef unsigned int u32;typedef int s32;typedef long long s64;
extern volatile u32 mailbox[32];
static volatile u32 seed=0x31415926u;
static volatile s32 samples[35];
static volatile s32 coefficients[32]={32767,-32768,16384,-8192,4096,-2048,1024,-512,256,-128,64,-32,16,-8,4,-2,1,-1,12345,-23456,30000,-30000,777,-999,42,-73,8191,-8193,2047,-2049,17,-19};
static u32 next(void){u32 x=seed;x^=x<<13;x^=x>>17;x^=x<<5;seed=x;return x;}
__attribute__((noinline)) static s64 dot(u32 offset){s64 sum=0;for(u32 k=0;k<32;k++)sum+=(s64)samples[offset+k]*coefficients[k];return sum;}
int main(void){
 for(u32 j=0;j<35;j++){u32 x=next();samples[j]=(x&0x80000000u)?-(s32)(~x)-1:(s32)x;}
 samples[0]=(-2147483647-1);samples[1]=2147483647;samples[2]=-1;samples[3]=0;samples[4]=1;samples[5]=-123456789;
 for(u32 n=0;n<4;n++){
  s64 acc=dot(n);u32 low=(u32)acc,high=(u32)((unsigned long long)acc>>32);
  /* C division specifies truncation toward zero, unlike a negative right shift. */
  s64 scaled=acc/32768;
  s32 clipped=scaled>2147483647?2147483647:scaled<(-2147483647-1)?(-2147483647-1):(s32)scaled;
  mailbox[1+n*3]=low;mailbox[2+n*3]=high;mailbox[3+n*3]=(u32)clipped;
 }
 mailbox[13]=128;mailbox[0]=0x50415353u;return 0;
}
