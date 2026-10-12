#ifndef FT_RISCV_TEST_H
#define FT_RISCV_TEST_H
#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp
#define RVTEST_CODE_BEGIN .section .text; .balign 4; .globl _start; _start:
#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .balign 16; .globl begin_signature; begin_signature:
#define RVTEST_DATA_END .globl end_signature; end_signature:
#define RVTEST_PASS li a0, 0; ebreak
#define RVTEST_FAIL mv a0, TESTNUM; ebreak
#endif
