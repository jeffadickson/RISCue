/* Linked at address zero. Stores -21, -2, -1 at 0x800..0x808, then counts forever. */
.section .text
.globl _start
_start:
 li t0,0x800
 li t1,-7
 li t2,3
 mul t3,t1,t2
 div t4,t1,t2
 rem t5,t1,t2
 sw t3,0(t0)
 sw t4,4(t0)
 sw t5,8(t0)
 li a0,0
loop:
 addi a0,a0,1
 sw a0,12(t0)
 j loop
