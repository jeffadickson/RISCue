# Changelog

## 0.5.0 — pipeline/platform implementation; functional validation pending

- Add overlapping five-stage RV32IMC machine core, CSRs/counters, CLINT,
  precise traps/interrupts, FENCE.I and duplicated multicycle arithmetic.
- Protect pipeline/platform/arithmetic state and add versioned FI windows.
- Select the pipeline for KC705 and add explicit VIO/ILA campaign builds.
- Configure ECC/TMR cocotb, arithmetic/injector regressions and RV32IMC RVFI.
- Preserve legacy modules and evidence; new results are compile-only.


## 0.4.0 — KC705 laboratory target

- Vivado build/program targets, clock/reset wrapper and UG810 pin constraints.
- On-chip ECC firmware image, LED status, periodic USB-UART snapshots and optional north-button injection.
- Explicit replica/execution-lane preservation and structural audits.
- Board infrastructure protection boundary and pending timing/hardware validation documented.

## 0.3.0 — RISCue formal setup

- Optional RVFI retirement interface and pinned riscv-formal integration.
- SHA256-verified free OSS CAD Suite/sv2v downloads and Makefile proof targets.
- ECC, error recorder, RAM fault, M execution-unit and whole-core fault harnesses.
- Explicit local signed DIV/REM model correction with an Icarus reproducer.
- Per-job outcomes, waveforms, proof assumptions and manual CI configuration.
- Strict formal requirements; unfinished and timed-out campaigns remain open.

## 0.2 — simulation and fault-injection prototype

- ECC/TMR register options, protected control and RAM state, triplicated reporting.
- Pinned upstream programs, cocotb campaigns and synthesis redundancy audits.

## 0.1 — initial RV32IM RTL

- Original core, SECDED functions, reference memory endpoint and SV regressions.
