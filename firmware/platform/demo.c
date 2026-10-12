#include "riscue.h"
void trap_c(uint32_t cause,uint32_t pc,uint32_t value) {
 RISCUE_MAILBOX->last_cause=cause;RISCUE_MAILBOX->last_pc=pc;RISCUE_MAILBOX->last_tval=value;
 if(cause==0x80000007u) {RISCUE_MAILBOX->ticks++;riscue_set_timer(riscue_time()+RISCUE_CLOCK_HZ/10);}
 else if(cause==0x80000003u)RISCUE_MSIP=0;
 else if(cause==0x8000000bu)write_csr(mie,read_csr(mie)&~0x800u);
 else {write_csr(mie,0);for(;;)__asm__ volatile("wfi");}
}
int main(void) {
 RISCUE_MAILBOX->signature=0x52464345u;RISCUE_MAILBOX->ticks=0;
 RISCUE_MAILBOX->last_cause=0;RISCUE_MAILBOX->last_pc=0;RISCUE_MAILBOX->last_tval=0;
 riscue_set_timer(riscue_time()+RISCUE_CLOCK_HZ/10);
 write_csr(mie,0x888u);__asm__ volatile("csrsi mstatus, 8");
 uint32_t count=0;
 for(;;)RISCUE_MAILBOX->progress=++count;
}
