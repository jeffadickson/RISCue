# 0.7.1 — compiler profile and actual C simulation

- Generate firmware flags from canonical JSON and audit linked ELF metadata/instructions before objcopy.
- Add checksum-pinned local GCC/binutils setup and small compiled C smoke target.
- ECC/TMR C simulation passes (269 retirements, 1636 clocks); platform firmware builds/audits.
- Replace platform startup zero alignment fill with legal NOPs.

# 0.7.0 — standard bit manipulation

- Implement RV32 Zbb, Zbc and Zbs 1.0 (29 instructions) in both compared pipeline execution lanes.
- Update firmware/upstream compiler profile and requirements; retain legacy RV32IM profile and FI ABI 2.
- Add independent polynomial reference, exact decode/corner tests and ECC/TMR pipeline dependency/trap regressions.
- Physical area/timing and extended full-core formal/compliance remain pending.

# Changelog

## 0.6.0 — KV260 laboratory control and software contract

- Add a protected AXI4-Lite PS/PL bridge, local ECC program loader, retained
  telemetry, external IRQ and hardware fault campaigns, plus KV260 BD/UIO targets.
- Supply an ARM CLI/browser dashboard, validated ELF/raw image parser,
  freestanding ILP32 profile and reference C startup/trap/timer firmware.
- Specify future standard Debug 1.0 and mission feature requirements; no
  standard debug module or additional mission instructions are advertised.
- Short AXI and selected jump/cocotb tests pass in ECC/TMR modes; real board,
  Vivado/Linux, C toolchain execution and full/formal validation remain pending.


## 0.5.2 — early direct jumps

- Resolve accepted JAL/C.J/C.JAL in ID with compared target lanes; retain
  EX link/next-PC retirement and older-redirect/trap priority.
- Add ECC/TMR early/late ordered-trace tests (30 retirements, 172 vs 144 clocks),
  cocotb jump/trap/wrong-path coverage and formal redirect assertions.
- Update formal/board sources and redundancy audit. RVFI and FI ABI 2 are unchanged.


## 0.5.1 — short simulation fixes

- Preserve the store-enable bit with explicitly sized bus control.
- Stabilize forwarding mux outputs to avoid simulator delta-cycle loops.
- Add passing ECC/TMR mixed-width pipeline smoke tests and simulation evidence.


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
