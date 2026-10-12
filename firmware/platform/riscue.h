#ifndef RISCUE_PLATFORM_H
#define RISCUE_PLATFORM_H
#include <stdint.h>
#ifndef RISCUE_CLOCK_HZ
#define RISCUE_CLOCK_HZ 10000000u
#endif
#define RISCUE_MAILBOX_ADDRESS 0x7f00u
#define RISCUE_MSIP (*(volatile uint32_t *)0x02000000u)
#define RISCUE_MTIME ((volatile uint32_t *)0x0200bff8u)
#define RISCUE_MTIMECMP ((volatile uint32_t *)0x02004000u)
#define read_csr(name) ({uint32_t v;__asm__ volatile("csrr %0, " #name:"=r"(v));v;})
#define write_csr(name,value) __asm__ volatile("csrw " #name ", %0"::"r"((uint32_t)(value)):"memory")
struct riscue_mailbox {uint32_t signature,progress,ticks,last_cause,last_pc,last_tval;};
#define RISCUE_MAILBOX ((volatile struct riscue_mailbox *)RISCUE_MAILBOX_ADDRESS)
static inline uint64_t riscue_time(void) {
 uint32_t hi,lo,again;
 do {hi=RISCUE_MTIME[1];lo=RISCUE_MTIME[0];again=RISCUE_MTIME[1];}while(hi!=again);
 return ((uint64_t)hi<<32)|lo;
}
static inline void riscue_set_timer(uint64_t time) {
 RISCUE_MTIMECMP[1]=0xffffffffu;RISCUE_MTIMECMP[0]=(uint32_t)time;RISCUE_MTIMECMP[1]=(uint32_t)(time>>32);
}
#endif
