# Remaining implementation and verification work

The current five-stage core, M-mode platform, bit manipulation, AXI ECC RAM and KC705 UART monitor have directed simulation evidence, including compiled C. See [validation](VALIDATION.md) and [the manual](RISCUE_MANUAL.md).

1. Run the actual KC705 Vivado flow, inspect resource use, timing, CDC and replica preservation, then verify clock/reset, UART identity, ELF loading, execution and error recovery on the board.
2. Complete the current-pipeline architectural/privileged and pinned upstream campaigns; broaden fault tests across timing phases and nonzero architectural states. Preserve failures and incomplete coverage explicitly.
3. Run RV32IMC RVFI, CSR/interrupt, arithmetic and fault proofs/covers. Add formal AXI ownership, halt/drain and monitor containment contracts; simulation passes do not close these proof tasks.
4. Validate the KV260 vendor IP, Linux UIO/clock/overlay and physical host-control path.
5. Implement and validate standard RISC-V debug halt/resume/step/GPR access if required. The serial monitor currently resets on RUN and has no standard Debug Module.
6. Engineer physical redundancy separation, memory interleaving, configuration scrubbing, protected clock/reset/boot/voters and target radiation qualification. The UART monitor and owner/boot controls remain outside the protected boundary.

Atomics, caches, prediction, dual-port memory, richer UART software I/O and external-memory controllers are future scope driven by workload/platform needs. A/Zalrsc/Zaamo remain conditional; no speculative performance or flight-readiness claim follows from adding features.
