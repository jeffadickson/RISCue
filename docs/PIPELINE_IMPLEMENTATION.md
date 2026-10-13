# Five-stage pipeline and machine platform

Current RTL and directed simulation status are summarized in [the manual](RISCUE_MANUAL.md) and [validation index](VALIDATION.md). Pipeline smoke, early jumps, bit manipulation, compiled C, AXI/ECC and UART monitor tests have passed in the stated configurations. Full architectural compliance, new pipeline formal proofs, Vivado timing and physical board validation remain pending.

`riscue_pipeline_core` is the current five-stage CPU. `riscue_pipeline_soc` supplies its local ECC-memory fixture; the default KC705 target uses `riscue_monitor_soc` with AXI ECC memory. `rv32im_ft_core` and `rv32im_ft_soc` preserve the older serialized target. Historical results under `verification/evidence` apply to that legacy target.

The pipeline target is RV32IMC_Zicsr_Zifencei_Zicntr_Zbb_Zbc_Zbs, M-mode only. IF fetches
ECC-coded words, expands RV32C integer instructions and assembles straddling
32-bit instructions. ID obtains register operands. EX forwards older results
and runs two integer lanes in parallel and compares their results, or two compared multicycle
arithmetic lanes. MEM performs checked loads/stores or CLINT accesses. WB
retires and commits registers/CSRs, precise traps, MRET, and FENCE.I. Stage
valid bits and backpressure permit overlap; a unified port limits throughput.
EX waits for dependent loads and M completion. Direct JAL and expanded C.J/C.JAL redirect in ID when accepted into EX.
Two preserved target lanes are compared before use. EX still computes the
link and architectural next PC, but suppresses a second direct-jump flush.
Conditional branches and JALR remain in EX. No cache or branch predictor
is supplied. This is not a one-instruction-per-clock performance claim.

A held bus transaction owns its address, data and control until ready, with
one idle cycle between transactions. MEM has priority over new fetches. A
redirect marks an outstanding fetch killed; that response drains and cannot
populate IF. FENCE.I drains older stores and flushes buffered/pending fetch.
Trap entry at WB prevents a younger MEM request and discards younger stages.
Instruction/access faults enter direct mtvec; ECC integrity failures,
watchdog expiry and redundant-lane/state integrity failures stop the core.
An external endpoint must honor the single-outstanding, held-request contract.
An unacknowledged external store cannot be rolled back after timeout.

## Machine state

misa is fixed at `0x40001104`, mhartid and identity CSRs at zero. misa writes
are ignored. mstatus implements MIE/MPIE with MPP fixed M and other fields
zero. mtvec supports direct mode (low two bits cleared); mepc clears bit 0.
mie supports bits 3/7/11; mip reflects msip, timer comparison and synchronized
external IRQ and ignores writes. mscratch, mcause and mtval are writable.
Unknown CSRs, unsupported SYSTEM operations and writes to read-only counter
aliases raise illegal-instruction traps. CSR operations serialize older
instructions and implement the zero-register/immediate suppression rules.
WFI is a NOP. MRET restores MIE from MPIE and sets MPIE. Interrupt entry drains
accepted instructions, records the next architectural PC, and masks global
MIE; external/software/timer priority is fixed in that order.

mcycle and mtime increment on each core clock, including stalls. minstret
increments for each non-trapping retired instruction. All counters have RV32
high halves; explicit machine counter-half writes override the increment of
that half on the same edge. cycle/instret/time and their high aliases are
read-only. Interrupt entry itself does not retire an instruction. Ordinary
architectural traps are not counted as hardware-fatal detector events.

| Address | Register | Reset |
| --- | --- | --- |
| 0x02000000 | msip, bit 0 | 0 |
| 0x02004000 / 0x02004004 | mtimecmp low/high | all ones |
| 0x0200bff8 / 0x0200bffc | mtime low/high | 0 |

CLINT accepts naturally aligned byte/half/word transfers and byte enables.
Use standard RV32 high/low update sequences to avoid transient comparator
interrupts. mtime runs at core-clock frequency, not a fixed real-time rate.
The core/SoC exposes external_irq; the current KC705 wrapper ties it inactive.
In the local pipeline reference SoC, data outside its SRAM and these registers receives an access fault. Packet UART and external AXI wrappers supply different address maps.

## Protection and injection

`riscue_pipeline_pkg` defines the packed state and ABI widths. A single record
contains all stages, control, CSRs, counters, timer, IRQ synchronizer state and
retirement trace. c0/c1/c2 vote and repair each clock. Each arithmetic lane has
its own triplicated state. RF uses SECDED by default or optional TMR. SRAM and
the recorder retain their existing protection. Two matching complete records
are required; three mutually different replicas fail stop. This is a digital
single-replica upset model, not radiation qualification of an FPGA.

Shared decode, CSR/CLINT combinational logic, majority voters, bus pins,
clock/reset, configuration SRAM, routing and diagnostics are not covered by
the single-replica stored-state fault model. Synthesis attributes and structural audits do not
prove physical separation or common-mode tolerance. Placement/interleaving,
configuration scrubbing, SET coverage and radiation testing remain target
engineering obligations. The board UART/button/reset state machines remain
outside the protected core. A remains a conditional future requirement.

See [FAULT_INJECTION.md](FAULT_INJECTION.md), [STRIDE.md](STRIDE.md), and
[../boards/kc705/lab/README.md](../boards/kc705/lab/README.md).

## Configured verification

`make pipeline-tools` downloads the pinned free simulator/formal suite and
creates a local Python environment from pinned cocotb requirements, without
running tests. `make pipeline-test` runs directed cocotb scenarios in ECC and TMR modes.
`make test-muldiv` checks arithmetic reference results, corner cases, fixed
latency, cancellation and replica repair. `make test-injector` checks burst
spacing, stride, rotation, descriptor rejection, disarm and reset replay.
`make formal-pipeline-prepare` downloads pinned free tools/upstream models and
prepares RVFI RV32IMC jobs; `make formal-pipeline` runs checks and instruction
cover witnesses explicitly. `make formal-muldiv` stages eight 40-cycle
arithmetic BMC/cover pairs; `make formal-injector` stages bounded campaign
qualification and spacing assertions plus a completion cover. None are
reported as completed proofs.
`make pipeline-upstream` fetches/builds pinned RV32I/M/C and FENCE.I test
bodies and C workloads, then observes EBREAK pass/fail on the pipeline.
Those bare-metal adapters do not establish privileged compliance.
Legacy `make test`/`make formal` remain legacy targets. Directed pipeline simulation evidence is indexed in VALIDATION.md; configured formal jobs are not completed proofs. Neither compliance nor RTOS compatibility has been established.

Normative references:
- https://docs.riscv.org/reference/isa/unpriv/zicsr.html
- https://docs.riscv.org/reference/isa/priv/machine.html
- https://docs.riscv.org/reference/isa/v20240411/unpriv/m-st-ext.html

## Early direct-jump validation and interface compatibility

EARLY_JUMP defaults 1 in the pipeline core/SoC. Set it to 0 for a controlled
EX-resolution baseline. The short tb_pipeline_jump scenario retires the same
30 instructions in 172 clocks with EX resolution and 144 with ID resolution,
in both RF modes: 28 clocks saved (16.3% fewer), not a general workload result.
The scenario includes JAL links, C.J/C.JAL, a negative jump loop, taken/untaken
branches, skipped illegal/store instructions, ECALL and illegal traps/MRET.
`make pipeline-jump` runs all four configurations. The existing mixed-width
arithmetic/load/store smoke remains `make pipeline-smoke`.

Redirect priority is WB trap/MRET/FENCE.I, older EX redirect, interrupt drain,
then an accepted ID direct jump. ID waits under backpressure, serializes behind
older SYSTEM operations, and never redirects a faulting decode. It discards
buffered fall-through fetch and partial words, and marks an outstanding IF
request killed while allowing the held transaction to drain. EX does not
flush already fetched target instructions a second time.

RVFI and public architectural retirement fields are unchanged; they describe
retired effects regardless of when fetching redirects. The new target module
is included in pipeline cocotb, formal and board builds, and in the physical
redundancy audit. Formal local assertions check accepted redirect state and
outstanding-fetch invalidation; RV32IMC checks/cover witnesses remain pending.
Cocotb adds direct_jump_links_wrong_paths_and_trap_priority and validates
retirement order/links rather than EX-stage timing. Use --late-jump with
run_pipeline.py for the baseline; do not assert the old cycle count globally.

No protected packed fields changed, so the injection map remains ABI 2 with
4031 core bits (8 windows) and 307 bits per arithmetic replica. The two new
jump target lanes are combinational and report disagreement through the
existing execution-integrity flag. There is no predictor state to protect.
