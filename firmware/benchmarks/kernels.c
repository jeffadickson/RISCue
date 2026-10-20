typedef unsigned int u32;
static volatile u32 data[16];
extern volatile u32 mailbox[2];
int main(void) {
 u32 answer=0;
#if BENCH_KIND == 0
 u32 crc=~0u;
 for(u32 i=0;i<32;i++) {
  crc^=(i*37u+11u)&255u;
  for(u32 j=0;j<8;j++)crc=(crc>>1)^((0u-(crc&1u))&0xedb88320u);
 }
 answer=~crc;
#elif BENCH_KIND == 1
 u32 seed=0x1234567u;
 for(u32 i=0;i<16;i++){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;data[i]=seed&65535u;}
 for(u32 i=1;i<16;i++){u32 v=data[i],j=i;while(j&&data[j-1]>v){data[j]=data[j-1];j--;}data[j]=v;}
 for(u32 i=0;i<16;i++)answer+=data[i]*(i+1u);
#else
 u32 state=0x13579bdfu;
 for(u32 i=0;i<32;i++){state=state*1664525u+1013904223u;answer^=(state>>(i&15u))+state/((i&7u)+1u);}
#endif
 volatile u32 *mail=mailbox;
 mail[0]=answer;mail[1]=0x434f5245u;
 return 0;
}
