# Multiplier and FIR verification — RISCue 0.7.3

Three complementary layers run against independent Python integer references. No core RTL changes were needed.

## Bounded exhaustive arithmetic units

Two production riscue_muldiv instances each pass 264,448 vectors: 66,112 per MUL/MULH/MULHSU/MULHU. All 65,536 pairs of sign-extended signed 8-bit operands are tested, plus 64 full-width edge pairs and 512 seeded random pairs. Unsigned/mixed instructions reinterpret those bit patterns as their operand rules require; this is not an exhaustive unsigned8 or full32 input-domain test. Both lane results, readiness/completion, two-clock multiply execution latency and absence of repeated completion/integrity flags are checked.

`make test-multiplier-exhaustive` generates 7.4 MiB of golden vectors and runs the native SV fixture. The generator/seed/hash are retained instead of checking generated vectors into source.

## Compiled signed FIR

GCC 13.2 -O2 compiles a 32-tap, four-output FIR with signed 32-bit samples and Q1.15 coefficients. Each of 128 products uses MUL+MULH and 64-bit accumulation. Independent Python validates both accumulator halves, division by 32768 and explicit int32 clipping. The maximum sum magnitude is bounded by 2^51.

| Measurement | ECC registers | TMR registers |
| --- | ---: | ---: |
| Cycles | 16912 | 16912 |
| Retirements | 2853 | 2853 |
| Average CPI | 5.928 | 5.928 |
| Host simulation seconds | 151.661 | 158.695 |

Each mode retires exactly 128 MUL and 128 MULH instructions. The full-width accumulator results include both sign directions and carry propagation.

| Output | Raw 64-bit accumulator | After /32768 | Clipped int32 |
| --- | ---: | ---: | ---: |
| 0 | -154433551443064 | -4712937971 | -2147483648 |
| 1 | 96468932675669 | 2943998189 | 2147483647 |
| 2 | -1366092785465 | -41689843 | -41689843 |
| 3 | 40445261152577 | 1234291417 | 1234291417 |

## Full-core multiply and interruption

The table-driven core test uses 128 operand pairs (64 boundary combinations and 64 seeded random pairs). Each pair executes all four variants, an immediately dependent MUL, an x0-destination MUL, a high-result store/load and a consumer. Python checks 1,152 retirement results per RF mode; 768 multiply instructions retire per mode. This runs fetch/decode/hazards/writeback and memory, rather than bypassing the CPU.

| Core vector run | Cycles | Retirements | Multiply retirements |
| --- | ---: | ---: | ---: |
| ecc | 9996 | 1795 | 768 |
| tmr | 9996 | 1795 | 768 |

Eight directed interrupt cases cover every variant in ECC and TMR modes. The external interrupt request is asserted only after both execution lanes are observed busy. The request crosses the normal synchronizer; exception entry happens at the architectural boundary chosen by the core. A small handler reads mcause, counts the interrupt and returns with MRET. Each target multiply and dependent result retires exactly once with the correct value, and the following instruction completes. This checks precise completion/cancellation/resumption; it does not require physical preemption halfway through a product.

## Reproduction and limits

`make c-fir`, `make test-multiplier-exhaustive`, and `make pipeline-multiplier` reproduce the layers. GCC/binutils/Icarus/cocotb setup is documented in ELF_COMPATIBILITY.md. JSON evidence and FIR disassembly are in verification. FIR/core vector cycle counts are measured from reset release to completion retirement, including startup. The simulated clock is 10 ns; conversion to a reference board frequency does not establish FPGA timing closure.

All tests are deterministic and inject no faults. They cover a bounded exhaustive domain plus full-width samples, not all 2^64 operand combinations, all interrupt schedules, all instructions, formal ISA compliance or radiation effectiveness. Historical division/cancellation/fault tests remain separately scoped.
