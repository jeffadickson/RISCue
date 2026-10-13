# RISCue programmer and microarchitecture reference

This reference describes the current `riscue_pipeline_core`, not the historical serialized core. It is an implementation guide checked against [execute RTL](../rtl/riscue_execute.sv), [compressed decoder](../rtl/riscue_rvc.sv), [pipeline RTL](../rtl/riscue_pipeline_core.sv), and [protected state types](../rtl/riscue_pipeline_pkg.sv). It does not claim completed architectural compliance or physical radiation qualification. See the [manual](RISCUE_MANUAL.md) for system variants and test evidence.

## Contents

- [Programmer model](#programmer-model)
- [Encoding conventions](#encoding-conventions)
- [Integer instructions](#integer-instruction-reference-rv32i)
- [Multiply and divide](#multiply-and-divide-m)
- [Compressed instructions](#compressed-instructions-c)
- [Bit manipulation](#bit-manipulation-zbb-zbc-zbs)
- [CSRs and machine control](#csr-instructions-and-machine-control)
- [Traps and interrupts](#traps-and-interrupts)
- [Pipeline and jump lookahead](#pipeline-and-jump-lookahead)
- [Protection replicas](#architectural-registers-versus-protection-replicas)
- [Major opcode lookup](#major-opcode-lookup)

## Programmer model

RISCue is a little-endian, 32-bit, in-order, single-hart processor with 32 integer registers, a program counter, and machine-mode control/status registers. The implemented profile is `rv32imc_zicsr_zifencei_zicntr_zbb_zbc_zbs`, using the standard ILP32 calling convention. Arithmetic wraps modulo 2^32 unless an instruction explicitly returns a comparison, high product or count. There are no arithmetic overflow traps, condition-code flags, floating-point registers, vector registers, MMU, supervisor/user execution modes or atomic A instructions. A register number denotes the same architectural register regardless of whether its storage uses ECC or TMR.

| Registers | ABI names | Software role | Preserved across ordinary C calls |
| --- | --- | --- | --- |
| x0 | zero | Reads zero; writes discarded | Constant |
| x1 | ra | Return address | No |
| x2 | sp | Stack pointer, 16-byte alignment at ABI boundaries | Yes |
| x3 | gp | Global pointer | Fixed by ABI |
| x4 | tp | Thread pointer | Fixed by ABI |
| x5–x7 | t0–t2 | Temporaries | No |
| x8 | s0/fp | Saved register / optional frame pointer | Yes |
| x9 | s1 | Saved register | Yes |
| x10–x17 | a0–a7 | Arguments; a0/a1 also results | No |
| x18–x27 | s2–s11 | Saved registers | Yes |
| x28–x31 | t3–t6 | Temporaries | No |
| PC | — | Byte address of instruction | Control flow |

The CPU does not enforce these ABI roles except x0. Trap entry does not automatically save GPRs or switch stacks; a handler must preserve the interrupted context itself. Reset initializes architectural state in the core; startup must still establish `sp`, `gp`, BSS and `mtvec`. RAM initialization and entry address depend on the wrapper. Core reset is not a RAM reload.

Instructions occupy 16 or 32 bits and start at even byte addresses (IALIGN=16). A 32-bit instruction may straddle a 32-bit memory-word boundary. Loads/stores address bytes: halfwords require two-byte alignment and words four-byte alignment. Misaligned data accesses trap; they are not split into multiple accesses. There is no general guarantee that MMIO devices accept byte/halfword accesses merely because the CPU can issue them.

## Encoding conventions

Here `rd` is destination, `rs1/rs2` are source registers, `imm` is the decoded immediate, and `sx` means sign extension. Bit numbers are inclusive. The assembler rearranges scattered branch/jump immediate bits.

| Format | Fields, most significant first | Typical use |
| --- | --- | --- |
| R | funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0] | Register ALU and M |
| I | imm[11:0] at [31:20], rs1, funct3, rd, opcode | Immediate ALU/load/JALR |
| S | imm[11:5], rs2, rs1, funct3, imm[4:0], opcode | Store |
| B | imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode | Branch; implicit bit 0 = 0 |
| U | imm[31:12], rd, opcode | LUI/AUIPC; low 12 bits zero |
| J | imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode | JAL; implicit bit 0 = 0 |

I/S immediates span −2048…2047; conditional branches span −4096…4094 bytes; JAL spans −1048576…1048574 bytes. Shift-immediate instructions reinterpret upper immediate bits as operation selectors. CSR immediate operands are unsigned five-bit values, not sign-extended I immediates.

## Integer instruction reference (RV32I)

All operations below use 32-bit values. Signed comparisons interpret two's-complement operands; unsigned comparisons compare bit patterns. Register shifts use rs2[4:0]. Ordinary instructions advance PC by their actual instruction length.

| Mnemonics | Assembly operands | Effect |
| --- | --- | --- |
| LUI | rd, imm20 | rd = imm20 << 12 |
| AUIPC | rd, imm20 | rd = instruction PC + (imm20 << 12) |
| ADD, SUB | rd, rs1, rs2 | Sum/difference modulo 2^32 |
| ADDI | rd, rs1, imm12 | rd = rs1 + sx(imm12) |
| AND, OR, XOR | rd, rs1, rs2 | Bitwise operation |
| ANDI, ORI, XORI | rd, rs1, imm12 | Bitwise operation with sx(imm12) |
| SLL, SRL, SRA | rd, rs1, rs2 | Left, logical right, arithmetic right shift |
| SLLI, SRLI, SRAI | rd, rs1, shamt | Same shifts, immediate 0…31 |
| SLT, SLTU | rd, rs1, rs2 | Signed/unsigned less-than; result 0 or 1 |
| SLTI, SLTIU | rd, rs1, imm12 | Compare to sx(imm12), then signed/unsigned interpretation |
| LB, LH, LW | rd, offset(rs1) | Read 8/16/32 bits at rs1+sx(offset), sign-extend narrow values |
| LBU, LHU | rd, offset(rs1) | Read 8/16 bits and zero-extend |
| SB, SH, SW | rs2, offset(rs1) | Store low 8/16/32 bits at rs1+sx(offset) |
| BEQ, BNE | rs1, rs2, label | Branch on equal/not equal |
| BLT, BGE | rs1, rs2, label | Branch on signed less-than/greater-or-equal |
| BLTU, BGEU | rs1, rs2, label | Same unsigned comparisons |
| JAL | rd, label | rd = following instruction address; PC = instruction PC + displacement |
| JALR | rd, offset(rs1) | Save following address; PC = (rs1+sx(offset)) & ~1 |
| FENCE | pred, succ | No additional action in this ordered, single-outstanding implementation |
| ECALL | — | Machine environment-call exception, cause 11 |
| EBREAK | — | Breakpoint exception, cause 3 by default; optional debug target enters debug when dcsr.ebreakm=1 |

A load into x0 still performs the memory access and can trap or trigger a device side effect. Register writes to x0 are discarded. Common assembler aliases are `nop = addi x0,x0,0`, `mv = addi rd,rs,0`, `j = jal x0,label`, `ret = jalr x0,0(ra)`; `li`, `la` and `call` can expand into multiple instructions and relaxation may change their encodings.

## Multiply and divide (M)

| Mnemonic | Result in rd from rs1, rs2 |
| --- | --- |
| MUL | Low 32 bits of product |
| MULH | High 32 bits of signed × signed product |
| MULHSU | High 32 bits of signed × unsigned product |
| MULHU | High 32 bits of unsigned × unsigned product |
| DIV, DIVU | Signed/unsigned quotient |
| REM, REMU | Signed/unsigned remainder |

Signed division rounds toward zero; a nonzero remainder has the dividend's sign. Divide by zero returns 0xffffffff for either quotient and the dividend for either remainder. Signed INT_MIN/−1 returns INT_MIN, remainder zero. These cases do not trap. The pipeline uses compared multicycle units, not the combinational fallback in `riscue_execute`. See [multiplier verification](MULTIPLIER_VERIFICATION.md) for measured unit coverage and latency details.

## Compressed instructions (C)

Compressed integer instructions are expanded before execution; retirement retains the original 16-bit encoding. The compact register fields select x8…x15. The full-register forms can address other GPRs subject to encoding restrictions.

| Group | Implemented mnemonics | Expansion / behavior |
| --- | --- | --- |
| Stack address | C.ADDI4SPN, C.ADDI16SP | ADDI with scaled stack-relative immediate |
| Constants | C.LI, C.LUI | ADDI from zero / LUI |
| Arithmetic | C.ADDI, C.ADD, C.SUB, C.AND, C.OR, C.XOR, C.ANDI | Corresponding integer operation |
| Shifts | C.SLLI, C.SRLI, C.SRAI | Immediate shift; RV32 high shift bit must be zero |
| Move/no-op | C.MV, C.NOP | ADD from zero / no architectural effect |
| Memory | C.LW, C.SW, C.LWSP, C.SWSP | Word load/store with scaled unsigned offset |
| Direct jump | C.J, C.JAL | JAL to x0/x1; link is PC+2 |
| Indirect jump | C.JR, C.JALR | JALR to x0/x1; link is PC+2 |
| Branch | C.BEQZ, C.BNEZ | Compare compact register to zero |
| Breakpoint | C.EBREAK | EBREAK |

Floating-point compressed forms and RV64-only word arithmetic are unsupported. Zero-immediate C.ADDI4SPN/C.ADDI16SP/C.LUI, C.LWSP to x0, and C.JR x0 are illegal. Some architecturally defined hint encodings execute as harmless operations; this table is not a claim of exhaustive reserved/hint compliance testing. The raw illegal encoding is reported in mtval.

## Bit manipulation (Zbb, Zbc, Zbs)

All binary register forms use `rd,rs1,rs2`; unary forms use `rd,rs1`; immediate bit/rotate forms replace rs2 by an index 0…31.

| Instructions | Operation |
| --- | --- |
| ANDN, ORN, XNOR | rs1 AND NOT rs2; rs1 OR NOT rs2; NOT(rs1 XOR rs2) |
| CLZ, CTZ, CPOP | Count leading zeros, trailing zeros, set bits; CLZ/CTZ(0)=32 |
| MIN, MAX, MINU, MAXU | Signed or unsigned min/max |
| SEXT.B, SEXT.H, ZEXT.H | Sign-extend byte/halfword or zero-extend halfword |
| ROL, ROR, RORI | Rotate left/right; register count uses low five bits |
| ORC.B | Each result byte is 0xff if corresponding source byte is nonzero, else 0 |
| REV8 | Reverse four byte positions |
| CLMUL, CLMULH, CLMULR | Carryless product slices [31:0], [63:32], [62:31] |
| BCLR/BCLRI | Clear indexed bit |
| BSET/BSETI | Set indexed bit |
| BINV/BINVI | Toggle indexed bit |
| BEXT/BEXTI | Extract indexed bit to bit 0, zero remaining bits |

Carryless multiplication is polynomial multiplication over GF(2); it is not integer MUL and does not itself define a CRC polynomial or reflection convention. These operations are combinational in the compared EX lanes. [BITMANIP.md](BITMANIP.md) describes exact encoding checks and verification scope. Zba is not implemented; the aggregate B bit in misa remains clear.

## CSR instructions and machine control

CSRRW/CSRRWI atomically read the old CSR into rd and replace it with rs1/zimm. CSRRS/CSRRSI set selected bits; CSRRC/CSRRCI clear selected bits. For set/clear forms, rs1=x0 or zimm=0 suppresses the write. A register containing zero but named by a nonzero rs1 still constitutes write intent. CSRRW with rd=x0 suppresses the read, but still writes. Unknown CSR addresses and write intent to a read-only CSR trap as illegal instructions. CSRs serialize with older pipeline operations.

| Address | Name | Access and implemented fields |
| --- | --- | --- |
| 0x300 | mstatus | RW MIE[3], MPIE[7]; MPP[12:11] reads 3; other bits zero |
| 0x301 | misa | 0x40001104 (RV32, I/M/C); writes ignored |
| 0x304 | mie | RW MSIE[3], MTIE[7], MEIE[11]; others zero |
| 0x305 | mtvec | RW direct trap base; bits [1:0] cleared; no vectored mode |
| 0x340 | mscratch | RW software scratch word |
| 0x341 | mepc | RW saved PC; bit 0 cleared |
| 0x342 | mcause | RW cause; bit 31 marks interrupt |
| 0x343 | mtval | RW trap-specific value |
| 0x344 | mip | MSIP[3], MTIP[7], MEIP[11] from hardware; writes ignored |
| 0xb00 / 0xb80 | mcycle / mcycleh | RW low/high cycle count |
| 0xb02 / 0xb82 | minstret / minstreth | RW low/high retired-instruction count |
| 0xc00 / 0xc80 | cycle / cycleh | Read-only aliases of mcycle |
| 0xc01 / 0xc81 | time / timeh | Read-only aliases of memory-mapped mtime |
| 0xc02 / 0xc82 | instret / instreth | Read-only aliases of minstret |
| 0xf11…0xf14 | mvendorid, marchid, mimpid, mhartid | Read-only zero |

MRET returns to mepc, restores MIE from MPIE and sets MPIE. WFI executes as a NOP. FENCE.I flushes buffered and pending fetch state after older operations; software modifying instructions must execute it before fetching the modified code. Named multi-letter ISA extensions are declared by the software profile, not individually discoverable in misa.

On core reset, writable CSR storage, mcycle, minstret, mtime and msip are zero; mstatus reads 0x1800 because MPP is fixed to M. mtvec, mepc, mcause, mtval, mscratch and mie are zero. misa and identity CSRs retain the constants above, and mtimecmp resets to all ones. mip is derived from current sources, including the synchronized external interrupt, so it is not an independently reset software register.

For a consistent 64-bit counter read on RV32, read high, low, high and retry if the high values differ. mcycle and mtime advance on every non-reset core clock, including stalls, monitor halt and fatal halt; minstret counts non-trapping retired instructions. Software writes to a machine counter half override that half's increment at the same edge. There is no mcountinhibit CSR. The optional standard debug target freezes mcycle/mtime while in debug halt; its stopcount/stoptime fields read one. See [hardware debug](HARDWARE_DEBUG.md).

## Traps and interrupts

| mcause | Meaning | mtval supplied by implementation |
| --- | --- | --- |
| 0 | Instruction address misaligned | Bad target/fetch address |
| 1 | Instruction access fault | Faulting fetch address; second-half address for straddling failure |
| 2 | Illegal instruction | Original raw instruction encoding |
| 3 | Breakpoint | Instruction PC |
| 4 / 6 | Load / store address misaligned | Effective data address |
| 5 / 7 | Load / store access fault | Effective data address |
| 11 | ECALL from M-mode | Zero |
| 0x80000003 | Machine software interrupt | Zero |
| 0x80000007 | Machine timer interrupt | Zero |
| 0x8000000b | Machine external interrupt | Zero |

Synchronous exceptions commit at WB: mepc identifies the faulting instruction, MIE is copied to MPIE and cleared, and control transfers to direct mtvec. Younger instructions are discarded. Interrupts require global MIE and the corresponding mie enable; accepted instructions drain before entry and mepc identifies the next architectural instruction. Simultaneous enabled interrupts have external, software, timer priority. Pending sources must be serviced/cleared by software or their device. An ordinary exception is distinct from a fatal hardware-integrity stop, which does not provide a normal recoverable trap-handler contract.

| Memory address | Timer register | Reset |
| --- | --- | --- |
| 0x02000000 | msip bit 0 | 0 |
| 0x02004000 / 0x02004004 | mtimecmp low/high | All ones |
| 0x0200bff8 / 0x0200bffc | mtime low/high | 0 |

mtime runs at the actual core-clock rate. To set a 64-bit mtimecmp without a transient early interrupt, write low=0xffffffff, then high, then final low. Use the high/low/high read sequence for mtime. Platform RAM and packet-UART register maps are wrapper-specific; see [packet processor](PACKET_PROCESSOR.md), [KC705 monitor](KC705_MONITOR.md) and [software ABI](SOFTWARE_ABI.md).

## Pipeline and jump lookahead

Retirement is an instruction’s architectural completion, when its result or precise exception is reported in program order. GPR/CSR commits occur at WB; a store completes its external memory transaction in MEM before retiring. CLINT refers here to the core-local interrupt/timer registers listed above.

| Stage | Main work | Reasons it can wait |
| --- | --- | --- |
| IF | Fetch ECC words; select 16-bit instruction or assemble 32-bit straddle | Unified port busy, held response, downstream full |
| ID | Decode, RF read, accepted direct-JAL target redirect | EX occupied, older serial operation, interrupt drain |
| EX | Forward operands; compare ALU results; evaluate branches/JALR; start/wait M | Load dependency, M operation, MEM occupied |
| MEM | Issue ordered load/store or internal CLINT access | Shared transaction outstanding, endpoint not ready |
| WB | Commit GPR/CSR results, retirement, synchronous trap and serial flush | Older memory operation must already complete |

The stage names describe responsibilities, not fixed one-clock instruction latency. There is one shared external request in flight. MEM has priority over new instruction fetch; a completed transaction is followed by a cooldown cycle. Consequently even an arithmetic-only stream can be fetch-limited. M and load stalls further reduce throughput. No documented clock target is a measured post-route maximum.

**There is no dynamic jump or branch predictor.** EARLY_JUMP=1 resolves direct JAL in ID using its known PC-relative immediate. C.J/C.JAL expand to this same operation. Two combinational target calculations are compared; EX later produces the architectural link and next PC without redundantly flushing the fetched target. Conditional branches and register-indirect JALR, including returns, resolve in EX. There is no BTB, history table or return-address stack. Sequential fall-through fetching has behavior resembling predict-not-taken, but no prediction state is implemented.

Redirect precedence is older WB trap/MRET/FENCE.I, older EX redirect, interrupt drain, then an accepted ID direct jump. An unaccepted/stalled decode does not redirect. Flush clears buffered/partial fall-through instructions and marks an outstanding fetch killed; the held bus response must still drain and is discarded. A target fetch does not imply the jump has retired. For `jal ra,target`, ra receives PC+4; for C.JAL it receives PC+2.

Operands are forwarded from non-load MEM results and WB results, with the newer MEM producer taking priority. A dependent load waits for its result; the consumer must not use its earlier RF sample. Example: `lw a0,0(a1); add a2,a0,a3` waits for the load response before the ADD executes. WB also bypasses a same-cycle GPR write into newly accepted ID operands. Stores consume the forwarded source value as well as the effective address. SYSTEM/FENCE.I serialization prevents CSR read/modify/write operations from observing incomplete older changes.

The controlled jump test retires 30 instructions in 172 clocks with EARLY_JUMP=0 and 144 with EARLY_JUMP=1, in both RF modes. This is 28 clocks saved on that test, not a universal speedup or one-instruction-per-cycle claim. See [pipeline implementation](PIPELINE_IMPLEMENTATION.md).

## Architectural registers versus protection replicas

GPR x5 is one software-visible 32-bit register. In ECC mode its storage is a 39-bit SECDED codeword; in TMR mode it is three 32-bit copies. Neither mode adds software registers or changes GCC's ABI. The pipeline's c0/c1/c2 records are also implementation replicas, not CSRs and not three harts.

| State or path | Mechanism | Covered failure behavior |
| --- | --- | --- |
| 32-bit RAM/RF word in ECC mode | 39-bit SECDED | One codeword bit corrected; two detected; larger errors not guaranteed |
| Pipeline, CSRs, timers, bus bookkeeping | Three complete 4,038-bit records | One replica corruption can be voted out and repaired |
| Each of two M lanes | Three 307-bit records per lane, plus cross-lane comparison | State repair; disagreement in results/completion detected |
| RF in TMR mode | Three copies per word | Vote/repair; no complete-word majority treated as failure |
| ALU and early-jump combinational lanes | Duplicate and compare | Detect disagreement; cannot decide which disagreeing result is correct |
| AXI bridge / ECC RAM endpoint | Triplicated stored state | Protect captured control and payload state, not exposed AXI wires |

Pipeline state is bitwise voted, but **three mutually different complete records cause fail-stop even if a bitwise majority exists**. Two identically corrupted replicas can agree on a wrong result and escape this check. Common-mode errors in shared decode, next-state logic, voters, clock/reset, routing or FPGA configuration are outside the single-replica stored-state fault model.

ECC correction is available at decode; writeback/scrubbing removes corrected stored errors where implemented. SECDED alone does not identify a wrong address selecting a different valid codeword. A data error on an unprotected AXI link can acquire valid new ECC at the RAM endpoint. Protected state is therefore not equivalent to end-to-end transport integrity.

Detected uncorrectable memory/register data, loss of state majority, execution-lane disagreement and timeout/integrity failures stop the protected core according to the relevant wrapper contract. An already accepted external store or MMIO side effect cannot be undone. Ordinary bus access-error responses can instead generate architectural access-fault traps. Error reporting availability is wrapper-specific: the local SoC event recorder, UART monitor RAM counters and packet peripheral counters are different interfaces, not one universal CSR bank.

The serial monitor, its ownership/boot controls and the serial RX/TX engines remain outside full protected-state coverage. Packet FIFO words have ECC and queue/CRC/watchdog state has TMR; that does not harden serial sampling itself. [STATE_MACHINE_AUDIT.md](STATE_MACHINE_AUDIT.md) lists widths and boundaries; [FAULT_INJECTION.md](FAULT_INJECTION.md) defines supported injections. Injections demonstrate selected digital fault responses, not physical radiation qualification.

### Worked pipeline events

These are ordered event traces, not fixed cycle schedules. External readiness and pipeline occupancy determine the clocks between events.

| Program fragment | Ordered events | Architectural result |
| --- | --- | --- |
| `addi a0,x0,7; add a1,a0,a0` | Producer advances toward WB; consumer reads an already committed value or obtains the newest matching MEM/WB result through forwarding (or WB-to-ID bypass) | a1=14; no stale RF value |
| `lw a0,0(a2); add a1,a0,a3` | Load owns MEM/request; dependent EX waits; response reaches WB; consumer uses forwarded load result | Load-use delay is variable, not a fixed one-cycle bubble |
| `beq a0,a1,taken; sw a2,0(a3)` with equality | EX resolves taken branch; younger fall-through instruction is flushed; killed fetch drains; target fetch resumes | Wrong-path store never commits |
| `jal ra,target` | ID acceptance computes/compares target; redirects fetch; EX computes link; WB commits link | Fetch can reach target before ra retires; no dynamic prediction |

### Register repair and recovery

ECC RF mode checks one rotating scrub slot per clock (a 32-slot sweep while the scrub index advances), and repairs corrected operand words during decode. TMR RF mode checks every word for pair agreement and feeds voted values back to all copies every clock. Physical x0 storage is forced to zero each edge, but the test injection override can corrupt that physical slot afterward. Architectural x0 operands still read zero; protection logic may nevertheless report a fault in its physical storage. Neither behavior creates a writable architectural x0.

Fatal halt is sticky until reset under the core contract; it is not an automatic reboot or checkpoint restore. A reset clears CPU execution/register state but does not by itself repair a bad RAM image. Wrapper-specific recovery may require memory-controller recovery and a verified reload. For example, a store acknowledged by an external device before a later detected fault remains an external side effect even though the hart subsequently halts.

## Major opcode lookup

This table provides the 32-bit major opcode. funct3/funct7 and fixed subfields distinguish instructions sharing an opcode; consult the linked RTL for the implemented exact checks. The table is not permission to use reserved encodings.

| Opcode [6:0] | Instruction families |
| --- | --- |
| 0x03 | Integer loads |
| 0x0f | FENCE / FENCE.I |
| 0x13 | Immediate ALU; immediate/unary bit manipulation |
| 0x17 | AUIPC |
| 0x23 | Integer stores |
| 0x33 | Register ALU, M, register bit manipulation |
| 0x37 | LUI |
| 0x63 | Conditional branches |
| 0x67 | JALR |
| 0x6f | JAL |
| 0x73 | CSR instructions, ECALL, EBREAK, MRET, WFI |

Compressed instructions use quadrants c[1:0]=00/01/10 and primary selector c[15:13]; c[1:0]=11 begins a wider encoding. RISCue implements only 16- and 32-bit instructions. Exact supported compressed subfields are in [riscue_rvc.sv](../rtl/riscue_rvc.sv); arithmetic/memory encodings are in [riscue_execute.sv](../rtl/riscue_execute.sv), SYSTEM refinements in [riscue_pipeline_core.sv](../rtl/riscue_pipeline_core.sv). The [bit-manipulation guide](BITMANIP.md) records the official opcode-source revisions used for those extensions.
