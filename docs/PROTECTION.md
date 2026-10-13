# Protection boundaries — v0.2

The current pipeline, AXI and monitor inventory is in [STATE_MACHINE_AUDIT.md](STATE_MACHINE_AUDIT.md). The common-mode limits below apply to the digital mitigation model; historical results do not establish new-core verification. In particular, the KC705 serial monitor, UART, ownership mux and boot/halt/reset controls are unprotected laboratory infrastructure.

The RTL implements correction of single stored bits in SECDED memories and masking/repair of one replica error in TMR state. Duplicated execution decisions are compared. These mechanisms do not establish radiation hardness.

Remaining gates are captured as open/partial requirements, not claimed as complete:

1. Shared voters, ECC decode outputs, register/word selection, comparison/commit gating and next-state logic remain common-mode vulnerability paths. Encoding the wrong result does not make it correct.
2. Keep attributes do not ensure independence. The generic synthesis recipe preserves sequential cells and execution instances and audits disjoint storage, including optional RF TMR; physical placement, separated routes, hardened voters and clock/reset treatment are still required.
3. SECDED guarantees single-bit correction and double-bit detection only. Three-or-more-bit patterns can miscorrect. Physical interleaving/stronger codes require actual target upset data.
4. TMR assumes at most one affected replica within the repair window. Equal errors in two replicas can be silent. A shared voter upset can affect all feedback paths.
5. Request ECC protects transmitted fields, not a wrong address calculated before encoding or an internal memory decoder returning a different valid word. Address-bound storage or independent decoder checks are not implemented.
6. FI ports model clock-edge stored-bit XOR errors. They do not simulate electrical pulse width, metastability, clock/reset glitches or physical charge sharing. Execution-output forcing is a logical mismatch test only.
7. FPGA configuration scrubbing/reconfiguration, SEL/SEFI response, TID/displacement-damage assessment, protected golden boot images and independent system supervision are external.
8. SRAM scrub is opportunistic, not bounded under all traffic. Hardware ECC initialization/boot validation remains target-dependent.
9. Error counters and first/last records are protected stored state, but the recorder's combinational update/voter remains shared. Source masks preserve simultaneous source identity; one address/PC metadata slot can lose individual event detail. No FIFO/backpressure/complete event history is implemented.
10. No privileged runtime, interrupts, checkpoints, retry, memory-bank retirement, timing closure, formal proof or radiation qualification is claimed.

**All state machines in the implemented core/subsystem are inventoried in STATE_MACHINE_AUDIT.md; external peripherals/controllers are outside that claim.**

Primary reference specifications remain RV32I/M from https://docs.riscv.org/reference/isa/ and NASA FSM/memory radiation guidance referenced in the v0.1 package. The pinned upstream code and licenses are separately identified in upstream.lock.json and licenses/.
