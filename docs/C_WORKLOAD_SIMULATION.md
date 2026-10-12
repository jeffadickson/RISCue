# Compiled C workload simulation — RISCue 0.7.2

GCC 13.2 compiled the 1,220-byte freestanding image with the canonical RV32IMC/Zicsr/Zifencei/Zicntr/Zbb/Zbc/Zbs profile at -O2. GNU binutils 2.42 audited 424 static instructions. Icarus 12.0 and cocotb 2.0.1 ran the real pipeline RTL, ECC memory, CSR/CLINT and multicycle arithmetic, rather than a software ISA emulator.

| Measurement | ECC registers | TMR registers |
| --- | ---: | ---: |
| Cycles | 20232 | 20232 |
| Retired instructions | 3340 | 3340 |
| Average cycles/instruction | 6.057 | 6.057 |
| Compressed instructions | 2157 | 2157 |
| Lowest observed sp | 7456 | 7456 |
| Observed stack depth (bytes) | 224 | 224 |
| Execution at reference 10 MHz (microseconds) | 2023.200 | 2023.200 |
| Simulation host seconds (excluding image load) | 181.751 | 191.098 |

Both modes match every reference result and mailbox word. Timer cause is 0x80000007; one interrupt enters the assembly/C handler and MRET resumes normal work. No intentional faults are injected. Counters for corrected ECC errors, uncorrectable errors, redundant disagreements and fatal events are recorded in the JSON.

| Instrumented phase | ECC cycles | TMR cycles |
| --- | ---: | ---: |
| sort_including_irq | 4256 | 4256 |
| matrix | 2360 | 2360 |
| crc32 | 4640 | 4640 |
| recursive_fibonacci | 2932 | 2932 |

Phase intervals come from C mcycle snapshots and include call/CSR overhead. Sort timing includes the one-shot interrupt service. These are workload observations, not worst-case bounds.

Reference sorted values: `[-123, -82, -79, -67, -59, -58, -23, 14, 46, 91, 105, 126]`.

Matrix product: `[12, -174, -156, -75, 182, 144, -91, 156, 114]` (row-major).

CRC-32/ISO-HDLC of `RISCue flight`: `0xC1AE182B`; Fibonacci(7): 13; search results: index 4 and -1; signed matrix quotient sum: 16.

## Actual dynamic instruction counts

| Instruction | ECC retirements | TMR retirements |
| --- | ---: | ---: |
| add | 17 | 17 |
| addi | 100 | 100 |
| andi | 147 | 147 |
| auipc | 33 | 33 |
| beq | 75 | 75 |
| bge | 14 | 14 |
| blt | 48 | 48 |
| bltu | 20 | 20 |
| bne | 105 | 105 |
| c.add | 317 | 317 |
| c.addi | 364 | 364 |
| c.addi16sp | 15 | 15 |
| c.and | 104 | 104 |
| c.beqz | 39 | 39 |
| c.bnez | 105 | 105 |
| c.j | 55 | 55 |
| c.jr | 28 | 28 |
| c.li | 112 | 112 |
| c.lui | 1 | 1 |
| c.lw | 210 | 210 |
| c.lwsp | 101 | 101 |
| c.mv | 106 | 106 |
| c.slli | 29 | 29 |
| c.srai | 8 | 8 |
| c.srli | 104 | 104 |
| c.sub | 1 | 1 |
| c.sw | 138 | 138 |
| c.swsp | 101 | 101 |
| c.xor | 219 | 219 |
| clmul | 1 | 1 |
| cpop | 1 | 1 |
| csrrs | 13 | 13 |
| csrrw | 6 | 6 |
| div | 9 | 9 |
| jalr | 28 | 28 |
| lbu | 13 | 13 |
| lui | 16 | 16 |
| lw | 17 | 17 |
| mret | 1 | 1 |
| mul | 27 | 27 |
| rev8 | 1 | 1 |
| rol | 12 | 12 |
| slli | 271 | 271 |
| srli | 38 | 38 |
| sub | 107 | 107 |
| sw | 61 | 61 |
| wfi | 1 | 1 |
| xori | 1 | 1 |

## Reproduction and limits

Run `make c-workload` with a bare-metal GCC/binutils toolchain, Icarus and the configured cocotb Python environment. `make c-tools` optionally fetches the pinned Linux x86-64 toolchain. Source is in firmware/workload; build artifacts are in build/c-workload. Published JSON, disassembly and complete per-retirement CSV traces are in verification.

The testbench clock period is 10 ns, equivalent to a synthetic 100 MHz. The 10 MHz duration above is calculated from cycles, not measured FPGA timing closure. Reset/image loading is outside the execution-cycle count. The startup and completion instruction are included. Observed stack depth uses architectural sp writes; this is not a stack safety proof. RAM is 8 KiB with stack top 0x1e00 and mailbox 0x1f00. Historical smaller C-smoke results remain separately scoped.

No OS, cache, external wait-state bus, DMA or fault campaign runs here. Matching ECC/TMR digital behavior does not establish protection effectiveness, radiation qualification, universal compiler correctness or ISA compliance.
