.section .text.start
.globl _start
_start:
  li sp, 0x1f00
  call main
.globl finished
finished:
  j finished
