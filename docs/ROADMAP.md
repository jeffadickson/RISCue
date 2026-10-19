# Remaining implementation and verification work

**Architecture direction (October 2026):** retain the reduced-complexity, protected single-pipeline processor as the flagship. Prioritize checked voter/commit boundaries, preserve existing ECC/TMR register-file options and compared execution lanes; do not require three complete cores. Treat Xilinx configuration scrubbing as a separately validated FPGA platform responsibility, not processor RTL development. Design and acceptance gates: [reduced-complexity TMR plan](REDUCED_COMPLEXITY_TMR_PLAN.md).


The current five-stage core, M-mode platform, bit manipulation, AXI ECC RAM and KC705 UART monitor have directed simulation evidence, including compiled C. See [validation](VALIDATION.md) and [the manual](RISCUE_MANUAL.md).

1. Run the actual KC705 Vivado flow, inspect resource use, timing, CDC and replica preservation, then verify clock/reset, UART identity, ELF loading, execution and error recovery on the board.
2. Complete the current-pipeline architectural/privileged and pinned upstream campaigns; broaden fault tests across timing phases and nonzero architectural states. Preserve failures and incomplete coverage explicitly.
3. Run RV32IMC RVFI, CSR/interrupt, arithmetic and fault proofs/covers. Add formal AXI ownership, halt/drain and monitor containment contracts; simulation passes do not close these proof tasks.
4. Validate the KV260 vendor IP, Linux UIO/clock/overlay and physical host-control path.
5. Extend the implemented minimal JTAG/DMI debug target with broader compliance, hardware triggers/watchpoints and physical validation. The separate serial monitor still resets on RUN. See HARDWARE_DEBUG.md.
6. Engineer physical redundancy separation, memory interleaving, configuration scrubbing, protected clock/reset/boot/voters and target radiation qualification. The UART monitor and owner/boot controls remain outside the protected boundary.

Atomics, caches, prediction, dual-port memory, packet DMA, additional stream sources, hardened serial engines, continuous-rate packet validation and board application UART integration and external-memory controllers are future scope driven by workload/platform needs. A/Zalrsc/Zaamo remain conditional; no speculative performance or flight-readiness claim follows from adding features.
