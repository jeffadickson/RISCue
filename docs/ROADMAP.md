# Remaining target and verification work

Early direct-jump resolution and KV260 generic AXI host interaction now have short simulation evidence. Selected cocotb jump tests also pass. Full regression, standard debug implementation, C toolchain execution and physical KV260/KC705 bring-up remain open.

Short SV simulations now pass for ECC/TMR pipeline smoke (20 retirements, 165 clocks), multicycle arithmetic (2,088 vectors plus cancellation/repair), and hardware injection scheduling. See verification/pipeline-smoke-results.json. Full cocotb/upstream/formal/Vivado/board validation remains pending. Older compile-only statements below describe the initial implementation checkpoint.

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
