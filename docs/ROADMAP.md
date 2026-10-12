# Remaining target and verification work

The five-stage machine pipeline, compressed decoder, multicycle arithmetic,
CLINT, interrupts and instrumented KC705 integration are implemented in 0.5.
They have compile-only evidence. Functional verification and target hardware
qualification remain open:

- Execute cocotb, arithmetic/injector regressions and pinned upstream programs.
- Run RV32IMC RVFI and dedicated CSR/interrupt/fault properties; retain failures,
  covers and timeouts explicitly. Compliance testing is not yet established.
- Run real Vivado IP generation, synthesis, physical redundancy audits,
  place/route, timing and board/debug campaigns.
- Engineer physical replica separation, memory interleaving, configuration
  scrubbing, voter/SET/common-mode coverage and radiation qualification.
- Consider A/Zalrsc/Zaamo only if multihart/DMA/atomic software requires it.
- Cache, predictor, higher-throughput dual-port memory and external IRQ board
  wiring are future performance/platform options, not enabled features.
