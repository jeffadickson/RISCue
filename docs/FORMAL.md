# Formal verification — RV32IM-FT v0.3

Early direct-jump target lanes are included in the pipeline conversion/RVFI inputs. Added local assertions cover redirect acceptance and killed pending fetches. The RVFI format is unchanged; new timing/redirect proof jobs and cover witnesses remain unexecuted.

New explicit targets formal-pipeline-prepare and formal-pipeline stage RV32IMC RVFI jobs for riscue_pipeline_core with 64-cycle instruction depths. formal-muldiv and formal-injector add dedicated bounded arithmetic/campaign checks and cover witnesses. These jobs have not been run. Existing results below remain legacy evidence.

## Reproduce on Linux x86-64 or Windows WSL2

Python 3.12+, GNU Make, git, internet access and about 4 GB of disk are needed. No paid tools or licenses are needed. Tool archives and riscv-formal are pinned; archive SHA256 values are checked before extraction. The suite download is about 713 MB. Binaries stay in `.tools/`; upstream source stays in `third_party/`.

```sh
make formal-tools       # download/verify OSS CAD Suite and sv2v
make formal-fetch       # fetch immutable upstream commits, refuse dirty checkouts
make formal-prepare     # generate the upstream RV32IM checks
make formal-ecc
make formal-monitor
make formal-execute     # arbitrary-operand M execution-unit contracts
make formal-ram
make formal-fault
make formal-isa
make formal             # all of the above checks, including reachability covers
```

Use `python3 tools/run_formal.py isa --jobs 4 --timeout 600` for more parallelism or longer per-job limits. Use `--instruction add --instruction lw` to select ISA instructions. Use `python3 tools/run_formal.py cover` after preparation to run instruction reachability covers. One runner per build directory is enforced to prevent regeneration from deleting active jobs. Independent campaigns can use separate `--build-dir build/name` directories. The Makefile's default sequential use is recommended.

`build/formal/results-*.json` records PASS, FAIL, UNKNOWN, ERROR or TIMEOUT for every completed campaign. Each job retains its console log, SBY status and counterexample/cover waveform when generated. Non-PASS outcomes fail the command; a timeout is not a proof. Normal simulation targets remain available. With the downloaded suite, run:

```sh
PATH="$PWD/.tools/oss-cad-suite/bin:$PATH" make test
```

## Property inventory and scope

| Job | Method | Contract |
| --- | --- | --- |
| ECC | Combinational proof | All 32-bit inputs, all 39 single-bit faults corrected exactly, all 741 distinct two-bit faults detected, clean decode unchanged |
| M execution unit | Combinational proof | Real arbitrary-operand MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU compared with upstream instruction models; separate from whole-core integration |
| Monitor | Induction | Sticky observations accumulate exactly, counters increment/saturate on the specified rising detector observations, first/last observation contents are correct, disagreement sets flag 15, replicas agree after a cycle without injection |
| RAM single | BMC, 10 steps | 39 separate bit-position jobs, symbolic word and either address in a two-word memory: write, inject a single stored-bit fault, read corrected data, then read again after repair |
| RAM double | BMC, 10 steps | Same sequence with two distinct stored-bit faults: error response rather than silent data acceptance |
| Core ECC/TMR fault | BMC, 12 steps | One symbolic injection cycle, register/control replica and bit; protected core matches an identical fault-free core's bus and retirement outputs |
| RVFI ISA | Upstream BMC, check cycle 12 | 45 RV32IM instruction models; plus register, PC forward/backward, uniqueness and causality checks |
| Covers | Reachability search | Exercise RAM/fault/monitor scenarios and upstream instruction covers at cycle 6 (versus ISA check cycle 12); guards against unreachable instruction scenarios |

The core fault campaign excludes x0 injection, admits one stored-bit upset in one control replica or one ECC/TMR register, and feeds both cores the same arbitrary clean memory response and ready signal. It does not model combinational transients, a bad voter, correlated replica faults or repeated upsets. The monitor campaign permits arbitrary corruption of one report replica once, stronger than a single-bit upset. It also checks exact edge-triggered counter increments/saturation and first/last observation contents.

The RAM harness uses a two-word memory and a directed transaction schedule. It is not an unbounded memory-controller proof and does not cover every partial-write, scrub starvation or arbitration sequence. The ISA environment permits arbitrary clean memory responses; instruction/data memory consistency and external bus protocol properties require additional harnesses. No memory fairness assumption is added to the safety checks. Liveness is not claimed.

## RVFI instrumentation

`RISCV_FORMAL` enables optional RVFI ports in the core. Supply the upstream `rvfi_macros.vh` with XLEN=32, ILEN=32 and NRET=1. Normal builds have no additional ports or behavior. Formal instrumentation exports retirement order, operand values, destination writeback, PCs, aligned byte masks and memory data. Load/store operand values are captured when entering the memory state, so a scrub or earlier write cannot change the traced operands while waiting on the bus. Architectural traps produce one RVFI record before the core halts; fatal hardware faults do not count as retired instructions.

RVFI order/operand tracing registers are verification-only and not radiation-protected. The current ISA checks use the ECC-register configuration. The separate relational fault campaign covers both ECC and TMR configurations. No `RISCV_FORMAL_ALTOPS` abstraction is used: M instructions use the real multiplication/division logic and may need substantially longer solver time.

The instruction list supplied by this pinned upstream RV32IM model contains no ECALL, EBREAK or FENCE checks. Their existing simulations remain relevant; privileged ISA/CSR/interrupt certification is not claimed. There is no proof yet that every decoded instruction belongs to a checked model, nor sequential equivalence of builds with and without RVFI.

## Interpretation

Combinational/inductive PASS is a proof under the stated model. BMC PASS excludes counterexamples only within the stated bound. Cover PASS establishes a reachable example, not correctness. Simulation, synthesis redundancy audits and target radiation/layout analysis remain complementary evidence. These RTL checks do not qualify the processor for radiation or flight use.

Sources: [SBY](https://github.com/YosysHQ/sby), [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), [riscv-formal](https://github.com/YosysHQ/riscv-formal), [sv2v](https://github.com/zachjs/sv2v). Source and tool pins are authoritative in the lock files.

## Pinned upstream model correction

The pinned `insn_div.v` and `insn_rem.v` contain a signed arithmetic expression inside a ternary whose other alternatives are unsigned. Verilog's context typing coerces this arithmetic to unsigned. Concrete examples confirmed with Icarus:

| Operation | Operands | ISA/core result | Original upstream model |
| --- | --- | --- | --- |
| DIV | 0x80000000 / 0xffff0000 | 0x00008000 (+32768) | 0x00000000 |
| REM | 0xffffffff % 0x80000000 | 0xffffffff (-1) | 0x7fffffff |

`tools/prepare_formal_models.py` copies the pinned instruction models into the build tree and puts each signed operation in a separately typed signed wire before using it in the ternary. It checks that the expected expression occurs exactly once; an unexpected source revision fails preparation. All other models remain unchanged. The source checkout is never modified. ISA and execution-unit jobs use these explicitly patched copies. This is a specification-model repair, not an RTL workaround or ALTOPS abstraction.

Run `make formal-model-tests` to reproduce both the original discrepancy and the corrected results. The formal execution-unit contracts then quantify over arbitrary operand values, including division by zero and signed overflow. Keep the patch provenance when comparing these results with another upstream revision.
