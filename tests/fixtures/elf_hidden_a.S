.globl _start
_start:
.option push
.option arch,+a
amoadd.w x3,x2,(x1)
.option pop
j _start
