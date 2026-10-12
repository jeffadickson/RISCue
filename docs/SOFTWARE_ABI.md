# C toolchain and implementation contract

RISCue uses the standard RV32 ILP32 ABI, not a custom calling convention.
`software-profile.json` declares the exact ISA, compiler flags, alignment,
memory and timing contract. Use a bare-metal RISC-V GCC/binutils toolchain;
a `riscv64-unknown-elf` multilib compiler can target RV32. No GCC backend fork
is required for the implemented standard instructions.

`make firmware-platform` builds a RAM-linked RV32IMC machine-mode demonstration
for the KV260 wrapper with Zbb/Zbc/Zbs enabled. It supplies startup, 16-byte aligned stack, global
pointer setup, BSS clearing, mtvec, a trap entry saving all GPRs, CLINT timer
helpers and a diagnostic mailbox. GCC must recognize the named extensions
and provide compatible ILP32 libgcc. Compiler flags are explicit in Makefile;
strict alignment prevents compiler-generated misaligned data accesses.
No libc, malloc, filesystem, semihosting or OS syscall ABI is supplied.
Firmware build/execution with a cross compiler remains unvalidated here.

The demo's local SRAM is 32 KiB at zero. Stack top is 0x7f00; the last 256 bytes
are a mailbox. Timer ticks run at the actual core-clock rate; CLOCK_HZ in the
RTL, Linux clock assignment and compiler RISCUE_CLOCK_HZ must agree. The ELF
loader accepts ELF32 little-endian RISC-V executables with entry zero and
matching physical/virtual SRAM addresses. It rejects floating-point/RVE/TSO
ELF ABI flags and segments outside RAM, clears all memory and verifies the
load. It does not fully parse .riscv.attributes: compile against this profile
and do not assume ELF flags alone prove every emitted extension compatible.

M-only means every task has machine privilege; there is no isolation boundary
or MMU. Illegal/misaligned/access errors trap to direct mtvec, whereas detected
hardware integrity failures stop the hart. WFI is a NOP; the demo exception
handler therefore loops without architectural halt. Core reset does not
restore SRAM, and the ARM wrapper's STOP clears GPR/CSR/pipeline state.
The loader pauses idle SRAM scrub while reset so a full-word reload can
repair/reinitialize corrupted words; foreground ECC remains enabled and idle
scrub resumes on RUN. This is a lab recovery contract, not checkpoint/resume.

Implementation latency (early JAL, multicycle M, shared memory stalls) affects
performance and worst-case execution time, not the C calling convention.
Use measured firmware/interrupt budgets; the 30-instruction jump benchmark
is not a general speedup or mission WCET bound.

Primary compiler reference: https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html
