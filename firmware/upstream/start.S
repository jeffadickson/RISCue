.section .text.start
.globl _start
_start:
  li sp, 0x7ff0
  call main
  ebreak
1: j 1b
