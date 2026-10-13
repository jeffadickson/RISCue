# Validation index

This page indexes recorded evidence by implementation/configuration. A result applies to the version, source hashes, assumptions and test selection in its record; it is not automatically a fresh test of every later revision. The [manual](RISCUE_MANUAL.md#the-simulation-test-rig) explains the fixtures and reproduction commands.

| Evidence | What passed | Important scope |
| --- | --- | --- |
| [Pipeline smoke](../verification/pipeline-smoke-results.json) | ECC/TMR smoke, multicycle arithmetic and injection scheduling | Directed tests |
| [Early jump / KV260](../verification/early-jump-kv260-results.json) | Early/late ECC/TMR jumps, selected cocotb and generic host-AXI tests | Physical KV260/Linux validation pending |
| [Bit manipulation](../verification/bitmanip-results.json) | 5,002 unit vectors and ECC/TMR integration | 29 Zbb/Zbc/Zbs instructions; not full ISA certification |
| [Small C](../verification/c-smoke-results.json) | Compiled smoke in local-memory ECC/TMR | 269 retirements / 1,636 cycles |
| [Larger C](../verification/c-workload-results.json) | Sort, matrix multiply, CRC, Fibonacci, search and timer IRQ | 3,340 retirements / 20,232 cycles |
| [Multiplier/FIR](../verification/multiplier-results.json) | 264,448 reference vectors, signed FIR and pipeline dependencies/interrupts | Bounded exhaustive 8-bit patterns plus full-width samples |
| [AXI master](../verification/axi-master-results.json) | Single-outstanding master, independent AW/W, errors/drain/TMR | Directed protocol/integrity cases |
| [AXI ECC memory](../verification/axi-ecc-memory-results.json) | Slave ECC/fault/handshake tests, first-instruction DED and six compiled-C runs | No physical BRAM/DDR or AXI formal-compliance result |
| [KC705 monitor](../verification/kc705-monitor-results.json) | Four bit-level UART protocol/C runs, five Python tests, seven Icarus regressions, board-stub compilation | Accelerated serial RTL, not physical USB/UART or board operation |
| [Current status](../verification/pipeline-status.json) | Navigation to current evidence and open work | Status index, not a proof log |

Current open gates: full current-pipeline architectural/privileged compliance, complete upstream/fault campaigns, current-pipeline formal proofs and covers, Vivado synthesis/place/route/CDC/timing, actual KC705/KV260 operation, and radiation qualification. Configured formal targets and compile/conversion passes do not close these gates.

The original 100 adapted upstream program runs, 5,901 stored-memory/RF faults, 4,440 control/reporter injections and small generic synthesis audits concern the **legacy serialized CPU**. Their retained historical explanation is [LEGACY_VALIDATION.md](LEGACY_VALIDATION.md); they must not be quoted as coverage of the newer pipeline or serial monitor.

No test result here establishes an achieved FPGA clock rate, DMIPS/CoreMark score, analog SET sensitivity, configuration upset immunity, SEL/TID rating or mission residual-error rate. Reports preserve those distinctions rather than assigning a generic “fully verified” label.
