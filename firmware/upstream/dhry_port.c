#include "dhry.h"
extern int dhry_main(void);
extern int Int_Glob,Bool_Glob,Arr_1_Glob[50],Arr_2_Glob[50][50];
extern char Ch_1_Glob,Ch_2_Glob;
extern Rec_Pointer Ptr_Glob,Next_Ptr_Glob;
static char heap[1024] __attribute__((aligned(16)));
static unsigned used;
char *malloc(int count) { unsigned start=used;used=(used+count+15)&~15u;return used<=sizeof(heap)?heap+start:0; }
void *memcpy(void *dst,const void *src,long n) { char *d=dst;const char *s=src;while(n--)*d++=*s++;return dst; }
char *strcpy(char *d,const char *s){char *r=d;while((*d++=*s++));return r;}
int strcmp(const char *a,const char *b){while(*a&&*a==*b){a++;b++;}return (unsigned char)*a-(unsigned char)*b;}
int printf(const char *fmt,...){(void)fmt;return 0;}
// Functional workload only: no claimed Dhrystone timing/score.
long time(void){static long t;t+=1000;return t;}
long insn(void){static long t;t+=1000;return t;}
int main(void){
 dhry_main();
 return !(Int_Glob==5&&Bool_Glob==1&&Ch_1_Glob=='A'&&Ch_2_Glob=='B'&&
 Arr_1_Glob[8]==7&&Arr_2_Glob[8][7]==110&&
 Ptr_Glob->Discr==Ident_1&&Ptr_Glob->variant.var_1.Enum_Comp==Ident_3&&
 Ptr_Glob->variant.var_1.Int_Comp==17&&Next_Ptr_Glob->variant.var_1.Int_Comp==18);
}
