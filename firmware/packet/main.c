#include <stdint.h>
#define UART ((volatile uint32_t *)0x10000000u)
#define CYCLE_TIMEOUT 200000u
#define MAX_PAYLOAD 32u
static uint8_t buffers[2][MAX_PAYLOAD]; /* Both live in the SoC's ECC SRAM. */
/* Descriptor complements detect software-visible corruption before use.
 * They do not establish a security boundary against malicious M-mode code. */
static volatile uint32_t lengths[2], lengths_inv[2], owner, owner_inv;
static volatile uint32_t *const stats=(volatile uint32_t *)0x1fc0;
static uint32_t cycle(void){uint32_t v;__asm__ volatile("csrr %0,mcycle":"=r"(v));return v;}
static int get(uint8_t *b){
 uint32_t start=cycle();
 while(!(UART[0]&256u)){UART[10]=1;if((uint32_t)(cycle()-start)>CYCLE_TIMEOUT)return 0;}
 *b=(uint8_t)UART[1];return 1;
}
static void put(uint8_t b){while(UART[0]&512u)UART[10]=1;UART[2]=b;}
static void crc_start(void){UART[4]=0xffffffffu;}
static void crc_add(uint8_t b){UART[5]=b;}
static uint32_t crc_end(void){return UART[4]^0xffffffffu;}
static void reply(uint8_t seq,uint8_t status,uint8_t n,const uint8_t *data){
 uint32_t crc;put(0xa5);crc_start();put(n);crc_add(n);put(seq);crc_add(seq);put(status);crc_add(status);
 for(uint32_t i=0;i<n;i++){put(data[i]);crc_add(data[i]);}crc=crc_end();
 for(uint32_t i=0;i<4;i++)put((uint8_t)(crc>>(8*i)));
}
int main(void){
 uint8_t b,seq,op,n;uint8_t have_seq=0,last_seq=0;
 owner=0;owner_inv=~0u;for(uint32_t i=0;i<16;i++)stats[i]=0;
 UART[9]=1000000u;stats[0]=0x5041434bu;
 for(;;){
  UART[10]=1;if(!get(&b)||b!=0xa5)continue;
  if(!get(&n)||n>MAX_PAYLOAD){stats[3]++;continue;}
  if(!get(&seq)||!get(&op)){stats[4]++;continue;}
  if((owner^owner_inv)!=~0u||owner>1){stats[5]++;return 1;}
  uint32_t slot=owner;lengths[slot]=n;lengths_inv[slot]=~(uint32_t)n;
  crc_start();crc_add(n);crc_add(seq);crc_add(op);uint32_t complete=1;
  for(uint32_t i=0;i<n;i++){if(!get(&b)){complete=0;break;}buffers[slot][i]=b;crc_add(b);}
  uint32_t expected=crc_end(),received=0;
  if(complete)for(uint32_t i=0;i<4;i++){if(!get(&b)){complete=0;break;}received|=(uint32_t)b<<(8*i);}
  if(!complete){stats[4]++;continue;}
  if(received!=expected){stats[2]++;continue;}
  if((lengths[slot]^lengths_inv[slot])!=~0u||lengths[slot]>MAX_PAYLOAD){stats[5]++;return 1;}
  if(have_seq&&seq==last_seq){stats[6]++;reply(seq,3,0,buffers[slot]);continue;}
  if(op==1){reply(seq,0,n,buffers[slot]);stats[1]++;}
  else if(op==2){uint32_t sum=0;for(uint32_t i=0;i<lengths[slot];i++)sum+=buffers[slot][i];
   for(uint32_t i=0;i<4;i++){buffers[slot][i]=(uint8_t)(sum>>(8*i));}
   reply(seq,0,4,buffers[slot]);stats[1]++;}
  else {stats[7]++;reply(seq,2,0,buffers[slot]);}
  have_seq=1;last_seq=seq;owner=slot^1u;owner_inv=~owner;
 }
}
