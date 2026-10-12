# STRIDE, integrity requirements and fault model

STRIDE covers intentional misuse of debug/test control and telemetry; random
radiation effects are covered by the protection inventory and fault campaign
requirements, not by STRIDE alone. This release is not radiation-qualified.
The full normative requirements and verification status are in REQUIREMENTS.md.

| Concern | Mechanism / boundary | Requirements |
| --- | --- | --- |
| Spoofing | JTAG operator/physical access is trusted; no VIO authentication is claimed. FI defaults disabled. | FI-LAB-001 |
| Tampering | Descriptor capture, mask/window validation, explicit arm, one-edge injections; ECC memory and TMR state repair. | FI-PIPE-001, PROT-PIPE-001 |
| Repudiation | Campaign counts/timestamps/status, ILA capture, sticky first/last detector observations. No cryptographic audit log. | FI-LAB-001, VERIFY-PIPE-001 |
| Information disclosure | VIO/ILA expose execution and state diagnostics only in the lab build; bitstream/JTAG access remains an operator responsibility. | FI-LAB-001 |
| Denial of service | Intentional double-error tests may fail stop. Disarm/abort and bus timeout bound operation; core reset does not restore SRAM. | PIPE-003, PROT-PIPE-001 |
| Elevation of privilege | M-only architecture with no U/S security boundary. CSR permission checks and precise traps define bad-code behavior. | PRIV-001..006 |

Single-replica state upsets, SRAM/register SECDED single errors and detectable
double errors are the primary digital fault model. Multiple correlated state
replicas, decoder/voter/control SETs, clock/reset loss, FPGA configuration
upsets and analog radiation behavior require additional target mitigation and
evidence. A detected hardware-fatal failure suppresses further bus requests
and retirement; already accepted external transactions cannot be undone.

The KV260 ARM loader/campaign dashboard is a trusted lab control surface with
AXI ABI 1 and FI ABI 2. It defaults to loopback and same-origin browser control,
serializes commands, rejects running memory access, validates ELF segments and
verifies the loaded SRAM. No Linux/ARM authentication, isolation or radiation
tolerance claim is made. Standard debug access governance remains DBG-001/002.

## Standard bit manipulation (0.7)

Zbb/Zbc/Zbs add combinational EX logic to both compared lanes; they introduce
no unprotected sequential state or new FI windows. A reserved extension
encoding takes the existing precise illegal-instruction trap. Requirements
ISA-BIT-001 and FT-BIT-001 cover exact decoding and pipeline integrity.
Duplicated logic detects lane disagreement but does not address shared operand,
clock, routing or configuration common-mode faults. Larger CLMUL logic requires
physical timing and placement validation; digital tests do not establish
radiation qualification. See BITMANIP.md and bitmanip-results.json.
