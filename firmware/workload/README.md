# Larger freestanding C workload

`main.c` runs deterministic tasks on the five-stage RISCue pipeline:

1. Generate 12 signed inputs and two 3x3 matrices with a volatile xorshift seed.
2. Arm a one-shot CLINT machine timer interrupt 500 ticks ahead.
3. Insertion-sort the inputs while normal execution can be interrupted.
4. Multiply the matrices with signed integer arithmetic.
5. Compute reflected CRC-32/ISO-HDLC over `RISCue flight` (13 bytes).
6. Compute Fibonacci(7) recursively, then perform successful/unsuccessful binary searches.
7. Normalize matrix results with signed division, count CRC bits, reverse CRC bytes
   and compute a carryless polynomial product through one inline-assembly helper.
8. Publish results and interrupt metadata, return to the startup completion loop.

There is no libc, heap, OS or floating point. Volatile inputs/storage prevent
constant-folding the workload; helper functions are not inlined. GCC can still
optimize recursion/loops according to C semantics. The trap assembly saves and
restores all writable GPRs, invokes C `trap_c`, and executes MRET. Unexpected
exceptions write FAIL and remain in a WFI loop; the simulator rejects them.

```sh
make c-tools                  # Optional pinned Linux x86-64 toolchain
export PATH="$PWD/.tools/riscv/root/usr/bin:$PATH"
make pipeline-tools           # Icarus must also be on PATH
make c-workload               # Build, audit, simulate ECC then TMR
```

The linker targets 8 KiB SRAM: stack top 0x1e00, at least 1 KiB reserved for
stack, and a 128-byte result mailbox at 0x1f00. The simulation fixture selects
2048 ECC-coded words. The instruction profile comes from the canonical JSON;
post-link attributes/disassembly are audited before conversion to binary.

Cocotb validates the image hash and checks every result against Python's
sorted(), independent integer matrix multiplication, and zlib.crc32. Signed
division in the reference explicitly truncates toward zero. It checks one
machine timer trap, a valid interrupt resume PC, successful return to startup,
and absence of fatal integrity events. Instruction mnemonics come from GNU
disassembly indexed by retired PC; dynamic counts come from actual retirement.

Generated artifacts under `build/c-workload` include ELF, binary, disassembly,
metadata, complete per-retirement CSV traces and separate ECC/TMR JSON results.
Published results and the simulation report are under `verification` and
`docs/C_WORKLOAD_SIMULATION.md`.

The simulated clock is 10 ns (100 MHz) for convenient test timing. Cycle counts
can be converted to the reference board's 10 MHz clock; that conversion does
not establish timing closure or change which instructions execute. C mcycle
phase intervals include call/CSR overhead and any interrupt service occurring
inside the interval. The observed stack depth measures architectural sp
writes, not all possible executions or arbitrary stack corruption.

These runs intentionally inject no faults. They test software, pipeline and
interrupt behavior with both register protection configurations, not the
radiation effectiveness or fault coverage of ECC/TMR. This workload is a
synthetic integration test, not flight software or a general benchmark.
