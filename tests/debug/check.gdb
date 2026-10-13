set pagination off
set confirm off
set remotetimeout 10
target extended-remote localhost:3333
monitor reset halt
load
set $pc = _start
break debug_done
continue
python
import gdb
def check(expr, want):
    got=int(gdb.parse_and_eval(expr))
    if got!=want: raise gdb.GdbError('%s: got %x expected %x'%(expr,got,want))
check('answer',42)
print('PASS source breakpoint and C result')
end
set variable answer = 99
python
check('answer',99)
end
delete breakpoints
set $a0 = 0x12345678
python
check('$a0',0x12345678)
end
# Halfword-aligned 32-bit instruction and compressed step.
set {unsigned int}0x1800 = 0x00700513
set {unsigned short}0x1804 = 0x0001
set {unsigned int}0x1806 = 0x00550593
set {unsigned int}0x180a = 0x00100073
set $pc = 0x1800
stepi
python
check('$pc',0x1804)
check('$a0',7)
end
stepi
python
check('$pc',0x1806)
end
stepi
python
check('$pc',0x180a)
check('$a1',12)
print('PASS exact single-step, compressed and split fetch')
end
continue
python
check('$pc',0x180a)
print('PASS EBREAK debug entry')
end
# Subword memory accesses must preserve other bytes and regenerate ECC.
set {unsigned int}0x1900 = 0x12345678
set {unsigned char}0x1901 = 0xab
set {unsigned short}0x1902 = 0xcdef
python
check('*(unsigned int*)0x1900',0xcdefab78)
print('PASS ECC-memory byte/halfword/word writes')
end
monitor reset halt
maintenance flush register-cache
python
check('$pc',0)
check('$a0',0)
print('PASS reset-halt')
print('PASS RIScue GDB end-to-end')
end
disconnect
quit
