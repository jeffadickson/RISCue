# Fault injection contract

`FI_ENABLE=0` by default in RTL. Test wrapper sets it to 1; this is not a flight interface. Ports: `fi_valid`, target, index, 512-bit XOR mask, combinational `fi_ack`. Testbench drives them before a clock edge. A qualified request flips the specified stored bits at that edge; keep valid asserted for one edge only. Unqualified target/index/mode receives no acknowledgement. Reset takes priority. Only the low mask bits listed below are used; a zero/high-only mask may acknowledge a no-op.

| Target | Storage | Index | Mask width |
| --- | --- | --- | --- |
| 1 | ECC RF | x0–x31 | 39 |
| 2–4 | RF TMR replicas 0–2 | x0–x31 | 32 |
| 5–7 | CPU control replicas 0–2 | ignored | 384 |
| 8 | SRAM word | 0 to WORDS−1 | 39 |
| 9–11 | RAM control replicas 0–2 | ignored | 35 |
| 12–14 | Error-recorder replicas 0–2 | ignored | 321 |

XOR applies to the post-update value: a same-edge architectural write/repair occurs first, then the upset. This avoids accidentally reverting an advancing state machine or losing a coincident write. Deposits into SRAM through simulator hierarchy are used to load clean firmware; fault campaigns use the qualified injection interface.

Campaigns distinguish (a) one-bit stored SEU, (b) multiple-bit same-codeword errors, (c) one replica state upset, (d) deliberate execution-result mismatch. Controlled RTL output forcing is retained in the legacy SV test for execution disagreement; it is not a calibrated SET model.

A physical-memory campaign must additionally sweep adjacent-cell bursts under the actual layout/interleaving, repeated upsets before scrub, controller/address-selection faults, different operating modes, and reset/power/clock/configuration failures. Three-or-more-bit SECDED errors and multi-replica TMR strikes may be silent; that is outside the declared guarantee, not an allowed flight outcome.

Results are deterministic ordered Python JSON records and cocotb JUnit XML. Simulator random seed is logged, but the current sweep stimuli do not depend on randomness. Failed assertions terminate a campaign; partial JSON must not be treated as complete evidence.
