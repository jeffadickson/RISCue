# Current state and protection inventory

Implementation baseline 0.8.0. This inventory describes stored-state mechanisms, not completed physical hardening or exhaustive fault coverage. The earlier serialized-core inventory is retained in [LEGACY_STATE_MACHINE_AUDIT.md](LEGACY_STATE_MACHINE_AUDIT.md).

| Block / state | Protection | Detection and repair | Qualification boundary |
| --- | --- | --- | --- |
| Pipeline/platform `c0/c1/c2` | Three 4,038-bit records | Bitwise voting/feedback; loss of complete-record majority is fatal | Shared voters, next-state, CSR decode and commit logic |
| Stages, PC, pending bus request, timeout, CSRs, timer, IRQ sampling, retirement | Included in pipeline record | Same TMR mechanism | Shared inputs/clock/reset, external IRQ synchronizer behavior |
| RF | 39-bit SECDED or three 32-bit words | Decode/vote, repair and scrub; DED/no-majority detection | Selection paths and matching multi-replica corruption |
| Each M arithmetic lane | Three 307-bit records | Repair, state/iteration validation; cross-lane completion/result comparison | Shared inputs and execution authorization |
| Integer/direct-jump lanes | Compared combinational outputs | Mismatch detected | No combinational fault correction; common-mode inputs/logic |
| AXI master bridge | Three 116-bit records | Captured payload/handshake state vote and repair; majority-loss fatal | AXI pins and shared decode/voters |
| AXI RAM endpoint | Three 348-bit records | Request/response/telemetry vote and repair; majority-loss fail stop | Shared endpoint logic; no public FI target for this state |
| Internal RAM controller | Three 35-bit records | Vote/repair and majority-loss fatal | Shared address decoder/ECC/write logic |
| RAM codewords / response codeword | SECDED | Single-error correction and double-error detection where decoded | Higher multiplicity and wrong valid-word selection |
| Local-SoC event recorder | Three 321-bit records | Repair and disagreement reporting | Shared update/voter; not a lossless FIFO |
| FI campaign controller | Triplicated descriptor/control with distance-four state encodings | Qualification, invalid/no-majority rejection, acknowledgments | Lab stimulus and shared command/trigger logic |
| Packet UART FIFO/control/CRC/watchdog | Three complete state records (266 bits at depth 64); 39-bit FIFO codewords | TMR repair/majority-loss fail stop; SECDED on dequeue | Shared decode/voters; serial RX/TX engines remain unprotected |
| UART command monitor and replay cache | Unprotected | CRC/length/timeout/ownership protocol checks | Protocol checks do not protect internal stored-state faults |
| Monitor run/boot/halt/reset controls and ownership selection | Unprotected | Nominal transaction-drain interlocks | Architectural influence; outside fault-tolerant deployment boundary |
| UART RX/TX, LEDs, host retirement count | Unprotected | RX synchronizer/framing and normal serial protocol | Lab/diagnostic infrastructure |
| Clock/reset/MMCM, FPGA configuration, board peripherals | External | Not qualified by this RTL | Requires target-specific engineering |

“All state machines are protected” is not a valid whole-system claim. The protected CPU/memory/controller subset coexists with unprotected laboratory infrastructure. Synthesis preservation attributes and replica-count checks do not demonstrate placement separation, configuration-upset tolerance or analog radiation behavior.

The current pipeline retirement fields reside in its TMR record. Earlier comments describing unprotected verification-only RVFI capture registers apply to the legacy core. Public FI ABI 2 exposes selected local-SoC state; the UART monitor exposes RAM codeword injection only. See [the manual](RISCUE_MANUAL.md#ecc-tmr-and-failure-containment), [FI mapping](FAULT_INJECTION.md) and [protection boundaries](PROTECTION.md).

The dedicated debug target adds a triplicated DM command/run-control/SBA record,
with sticky majority-loss failure. The seven architectural debug bits are part
of the pipeline record. TAP/CDC state remains outside this protection claim.
See [hardware debug](HARDWARE_DEBUG.md).
