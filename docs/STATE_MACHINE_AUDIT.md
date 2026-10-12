# State-machine and state inventory — v0.2

**All explicit sequential controllers in this RTL have protected stored state. This does not mean every control path is radiation hardened.**

| Block/state | Stored-state protection | Detection/recovery | Remaining vulnerability |
| --- | --- | --- | --- |
| CPU FETCH/EXEC/MEM/HALT sequencer | Three 384-bit control replicas; FSM codes have distance 4 | Majority/feedback repair; invalid voted FSM state causes fail-stop | Shared voter and next-state/commit logic; common clock/reset |
| CPU PC/instruction/pending memory transaction | Included in the same triplicated bundle | Replica disagreement and repair | Common input/decoder faults can produce the same incorrect value in all replicas |
| Request timeout counter | Included in CPU TMR bundle | Fail-stop on stalled request | Shared timeout comparison/qualification |
| RF scrub pointer | Included in CPU TMR bundle | TMR repair | Shared register selection and repair write-enable |
| RF words | ECC or three 32-bit replicas | ECC correction/repair, or voted reads/repair | TMR cannot guarantee detection for matching two-replica errors; shared address selection |
| SRAM request/response/error/fatal controller | Three 35-bit RAM-control replicas | Voted response, error, fatal; feedback repair | Common address decoder/RMW/ECC logic and ready qualification |
| SRAM scrub pointer | Included in RAM-control TMR | Voted pointer, repair, range check | Idle-only scrub can starve under continuous traffic |
| Error recorder previous/sticky flags, counters and records | Three 321-bit record replicas | Repair; self-disagreement flag bit 15 | Shared recorder voter/update/comparator logic, common clock/reset |
| Arithmetic/multiply/divide | Pure combinational; no internal FSM | Two execution-record outputs compared | Same RTL and shared operands; comparator/authorization common mode; combinational M timing cost |
| Fault-injection selector | No stored FSM; FI_ENABLE static parameter | Range/mode qualification and acknowledgement | Must remain disabled and be removed/tied off in production |
| External clock/reset/configuration scrubber/boot sequencer/peripherals | Not part of this RTL | Not supplied | Integration responsibility; no claim of protection |

The FSM coding detects some invalid *voted* encodings; it does not implement a Hamming corrective FSM. TMR is the corrective mechanism. Two faults can lead to another legal code, so the coding does not prove arbitrary multi-bit state coverage.

Synthesis auditing checks separate storage cells/nets, not placement separation or analog/common-mode coverage. See PROTECTION.md for qualification obligations.

## v0.3 verification instrumentation

`RISCV_FORMAL` adds RVFI order and captured operand registers solely for verification. These are not triplicated and do not feed functional control, register writes or bus requests. They are absent in production builds. No new production state machine is added by the formal integration.
