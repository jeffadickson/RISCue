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

## Firmware profile integrity (SW-002)

Generate flags from the JSON profile and audit the final linked ELF so library
or assembly additions cannot silently broaden the advertised ISA. Metadata
and binutils decoding are evidence, not a trust boundary: the audit cannot
prove reachability, cover generated/mutable code or establish hardware
compliance. Production loader/authentication and runtime recovery remain
separate requirements. Conservative failures must be resolved explicitly,
without silently disabling the audit.

## KC705 serial development monitor (0.7.6)

The physical UART is a trusted laboratory control interface, not a secure boot interface. CRC detects accidental packet corruption; it does not authenticate the sender. The loader can replace executable memory and start at a supplied entry address. Restrict physical access; exclude this control plane from a flight configuration until it has a separate fault-tolerance and access-control design.

| STRIDE concern | Requirement / response | Verification |
| --- | --- | --- |
| Spoofing / elevation | Document physical access as authority; compile RAM injection off by default; no claim of authenticated boot | Disabled-injection command rejection; parameter review |
| Tampering | Validate packet CRC and full ELF bounds before effects; generate ECC on full-word writes; verify loaded data by readback | CRC rejection, ELF negative cases, C mailbox checks |
| Repudiation | Echo sequence/address and report explicit status; host logs can retain replies; no durable audit claim | Reply validation and replay checks |
| Information disclosure | Memory/status reads intentionally expose laboratory state; no confidentiality claim | Stopped-only memory access tests |
| Denial of service | Discard malformed/partial frames; bounded waits; preserve bus ownership on stop timeout; lock host path after bus timeout | Packet timeout, busy rejection, ownership assertions |
| Repeated side effects | Cache the last completed command/reply; identical retries replay; same sequence with changed payload is rejected | Duplicate write/injection/run tests |

MON-001: Power up stopped; load and read RAM through AXI and normal ECC encoding. MON-002: Stop must drain accepted instructions, split fetches and AXI transactions before memory ownership changes. MON-003: Run resets architectural state at a validated halfword-aligned RAM entry. MON-004: CRC validation and cached duplicate replies prevent damaged or repeated commands from causing new effects. MON-005: Recovery and injection require stopped, idle ownership; status remains available during execution/fatal state. MON-006: Validate ELF segments, initialize BSS, verify loaded memory, and support the complete host command workflow. Verify real serial framing and compiled-C upload/run/readback in both register protection modes. Monitor/UART/mux/boot controls are explicitly outside the protected flight core boundary.
