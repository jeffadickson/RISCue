# Executed validation — v0.2

Tools: Icarus Verilog 12.0, cocotb 2.0.1, RISC-V bare-metal GCC 13.2.0/binutils 2.42, sv2v v0.0.13, Yosys 0.33, Python 3.12.4. Verification date: 2026-10-12.

## Upstream programs

50 program images passed in both ECC and TMR register configurations: **100 successful runs**. Forty-eight use pinned riscv-tests RV32UI/RV32UM self-checking instruction bodies. Two are PicoRV32's sieve and Dhrystone.

The environment adapter supplies startup and EBREAK pass/fail termination, not machine-mode CSR setup. Two source programs are excluded with recorded reasons: `fence_i` needs Zifencei and `ma_data` expects a misaligned-access environment not provided here. These are adapted upstream runs, not ACT4 certification. Upstream sources are unchanged and their commits are recorded in `upstream.lock.json` and the binary manifest.

- Sieve passed its upstream checksum `0x1772a48f`; polling completion bound 18,880 cycles.
- Dhrystone executed its original 100 iterations and passed explicit final-state checks; polling completion bound 192,320 cycles. Timing routines are stubs; no benchmark score is claimed.
- Polling bounds include up to 31 extra cycles and are not exact retirement counts or processor performance ratings.

## cocotb stored-fault campaigns

| Mode | SRAM single bits | RF single bits | SRAM double-bit pairs | Total |
| --- | ---: | ---: | ---: | ---: |
| ECC RF | 117 (3 words × 39) | 1,209 (31 words × 39) | 741 (all pairs in one 39-bit word) | 2,067 |
| TMR RF | 117 | 2,976 (31 words × 3 replicas × 32) | 741 | 3,834 |
| Combined | 234 | 4,185 | 1,482 | **5,901** |

Single-bit SRAM/register upsets were repaired with reporting and no fatal result. SRAM double-bit patterns caused a detected fail-stop and incremented uncorrectable reporting. Most SRAM cases exercise background scrub rather than every foreground timing phase; directed read/RMW/write integrity is additionally tested by the SV RAM bench. The RF sweep starts from zero-valued words; nonzero functional operands are separately exercised by all upstream programs and the original RF fault test.

## Control and reporter sweeps

Each mode executes **2,220** one-bit replica injections: 3×384 CPU control bits, 3×35 RAM control bits, and 3×321 recorder bits. All three post-repair words are checked equal, with detector reporting and no fatal result. Total across modes: **4,440** cases. JSON records are emitted by the completed control-only cocotb runs. This is stored-state coverage, not arbitrary combinational/shared-node coverage.

## Interface/reporting tests

Four configurations (ECC/TMR × FI disabled/enabled) passed. They check production injection rejection, invalid target/index/mode rejection, corrected counter saturation, first-address capture, and RF DED fatal-count reporting in ECC mode. The main control campaigns additionally check first-record persistence after a memory fatal and reporter self-disagreement recovery.

Reporting is an observation recorder, not a complete FIFO: repeated detections and simultaneous-event metadata are defined in README.md. Arithmetic/synthesis checks do not establish lossless telemetry or protection of the shared recorder logic.

## Legacy regressions

All six original SV benches passed on v0.2 RTL: 9,360 ECC one/two-bit cases; 5,938 arithmetic oracle vectors plus branch/jump/trap checks; integrated loop/load/store/M program; 1,191 control/RF faults plus directed containment; reference RAM integrity/RMW; 202 retirement records and all final registers against a separate Python program model.

The ECC implementation was changed from procedural parity loops to equivalent fixed XOR trees to reduce event-driven simulator cost. The exhaustive original ECC suite was rerun after that change.

## Generic synthesis and netlist audit

Both RF configurations passed Yosys process lowering/optimization/memory collection and `check -assert` for a 16-word reference-SRAM configuration. Audits establish disjoint sequential storage drivers for CPU, RAM and reporter TMR, two distinct execution instances, and in TMR mode all 31 nonzero RF words have three separate storage drivers/nets. Explicit sequential-cell preservation prevents the TMR merging observed in v0.1's initial synthesis experiment.

This is generic synthesis, not technology mapping, RAM inference certification, place-and-route, timing/CDC/reset closure or irradiation. No area/Fmax/LET/TID/SEL rating is asserted.

## Evidence

`verification/evidence/` contains mode-specific program/fault/control JSON, cocotb JUnit XML, simulator and synthesis logs, source/binary manifest and audit output. All verification scripts and tests are included. Failed campaigns stop with nonzero exit; partial results must not be counted as completion.

The main full-mode campaigns and the final focused reporting/control/interface regressions are separate runs. A later reporting-only change added RF DED to fatal counting; final ECC/TMR focused tests and synthesis checks cover that change. It does not change instruction execution or previously exercised memory repair.
