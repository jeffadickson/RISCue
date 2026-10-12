/* RV32IM bare-metal smoke example. No CSR/interrupt instructions. */
.section .text
.globl _start
_start:
    li t0, 0x800
    li t1, -7
    li t2, 3
    mul t3, t1, t2
    div t4, t1, t2
    rem t5, t1, t2
    sw t3, 0(t0)
    sw t4, 4(t0)
    sw t5, 8(t0)
    ebreak
