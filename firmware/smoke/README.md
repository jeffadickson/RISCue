# Small compiled C smoke test

`main.c` reads volatile inputs, computes the sum of squares from 1 through 16,
divides it by 7, rotates and counts bits, performs carryless multiplication and
sets a bit. Two inline-assembly helpers exercise CLMUL and BSET; the rest is
ordinary C/GCC builtin code. GCC emits MUL, DIVU, REMU, RORI and CPOP.

The startup initializes sp/gp, clears BSS, calls main and loops at `_finished`.
The linker reserves a 1 KiB stack and a result mailbox at 0xfc0 in the 4 KiB
simulation RAM. This small standalone startup does not provide interrupt or
trap handlers. Unexpected traps and integrity failures fail the simulation.
Cocotb checks the binary hash, waits for `_finished` retirement and compares
all nine ECC-coded mailbox words against an independent reference.

`make c-smoke` compiles, audits and runs both ECC/TMR register modes.
`make c-smoke-local` first obtains the optional pinned Linux x86-64 toolchain.
See `docs/ELF_COMPATIBILITY.md` for setup and audit limitations.

Executed with GCC 13.2, binutils 2.42, Icarus 12.0 and cocotb 2.0.1:

| Result | Expected |
| --- | --- |
| PASS signature | 0x50415353 |
| Sum of squares | 1496 |
| Quotient / remainder | 213 / 5 |
| Rotate 0x12345678 right 7 | 0xf02468ac |
| Population count | 13 |
| CLMUL with 0x1021 (low 32 bits) | 0x11d91978 |
| Set bit 31 | 0x92345678 |
| Final array value | 256 |

Both modes retired 269 instructions in 1,636 cycles. This is a small directed
workload, not a general performance benchmark, full C-library validation or
board timing result. Generated ELF, binary, disassembly, audit, build metadata
and simulation results are under `build/c-smoke`.
