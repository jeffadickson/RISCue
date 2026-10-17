## Unreleased — Experimental pipeline integration

- Add a static drop-in TMR/PARITY_REPLAY boundary, named build selection and mode manifests; TMR stays default.
- Add single-copy stage parity, protected architectural state, bounded replay, distance-three recovery phases and conservative memory-side-effect fail-stop.
- Add directed fault and interface campaigns; preserve compared execution and independent RF selection.
- Keep parity explicitly experimental and reject it in vendor board release flows pending mapped audits. Area, full fault coverage and flight qualification remain open.
- Add local Yosys Series-7 resource estimation, an executable SECDED formal setup check, and a self-contained CRC assembly/simulation page for David.

## 0.8.0 — Hardware debug and GDB integration

- Add opt-in resumable core debug, exact instruction stepping, dcsr/dpc and abstract register access, plus EBREAK/C.EBREAK debug entry.
- Add a minimal Debug 0.13-compatible DMI module, JTAG DTM with toggle CDC, and halted-only 8/16/32-bit SBA through ECC SRAM.
- Protect architectural debug state and DM commands with TMR; explicitly bound unprotected TAP/CDC and fatal recovery behavior.
- Add pinned local OpenOCD/GDB setup, actual JTAG-to-RTL GDB acceptance tests, C ELF fixture, and VS Code launch configuration.
- Add a separate KC705 FMC-LPC debug target and timing/CDC constraints; physical Vivado/board validation remains pending.
- Preserve existing FI bit offsets while extending the pipeline record to 4,038 bits. Default monitor/AXI/packet debug remains disabled.

## 0.7.7 — UART packet-processing application

- Add conventional programmer/ISA/GPR/CSR reference, worked pipeline/early-jump explanations and precise register-protection semantics after five sequential independent documentation review rounds; correct stale cross-guide integration/recovery claims.

- Add a standalone native-bus application SoC with 8 KiB ECC SRAM and CPU UART MMIO; existing FPGA targets remain unchanged.
- Protect RX/TX byte queues with SECDED and FIFO/response/CRC/watchdog state with TMR, plus lab-only fault injection.
- Add compiled C bounded echo/sum packet firmware, alternating buffers, descriptor checks, CRC/timeout/duplicate rejection and mailbox telemetry.
- Add Python golden vectors and bit-level UART simulations in ECC/TMR register modes, including SRAM and descriptor fault cases.
- Document requirements, MMIO/protocol, protection boundaries and pending board/rate/formal work. Serial engines remain unprotected lab infrastructure.

## 0.7.6 — KC705 serial development monitor

- Consolidate current architecture, protection, software, FPGA and test-rig documentation into a developer manual with 24 source-synchronized excerpts. Refresh README/status/inventory and preserve historical descriptions separately.

- Default KC705 target now uses the AXI CPU and ECC RAM with independent UART load/run/status control; original VIO/ILA target remains selectable.
- Add CRC-framed stop-and-wait commands, duplicate replay, bounded waits, stopped-only memory ownership, memory recovery and optional codeword injection.
- Add optional pipeline drain control and programmable reset PC; defaults preserve existing wrappers.
- Add Python ELF loader with BSS initialization/readback and physical UART regression plus compiled C upload/run tests.
- Update board RX constraints, redundancy audit hierarchy, requirements and laboratory trust boundary. Vivado/board validation remains pending.

# 0.7.5 — AXI ECC memory endpoint

- Add protected AXI4-Lite SECDED RAM slave with byte RMW, scrub, DED containment, diagnostic counters/syndromes and validated fault injection.
- Add quiescent memory-control reset/full-word recovery and independent channel/response tests.
- Expose RAM syndrome, preserve foreground fault address and fail stop on loss of RAM control-state majority.
- Run existing compiled C examples through CPU -> AXI -> ECC RAM in ECC/TMR register modes.
- Physical BRAM inference, board integration and full protocol/formal validation remain pending.

# 0.7.4 — generic processor AXI master

- Add 32-bit single-outstanding AXI4-Lite master wrapper and triplicated bridge.
- Handle independent AW/W backpressure, latched request ownership and precise bus-error traps.
- Add ECC/TMR processor read/write-error tests and bridge correction/repair/drain tests.
- Document external-memory integrity boundary, reset/CDC and pending board integration.

# 0.7.3 — multiplier stress and signed FIR

- Add exhaustive bounded arithmetic-unit vectors for all four multiply variants with independent Python golden products.
- Add compiled signed 32-tap FIR using MUL/MULH and 64-bit accumulation, scaling and explicit clipping.
- Add full-core boundary/random/dependency/x0/memory tests and interrupts requested while both multiply lanes are busy.
- Publish verification evidence with separate unit, full-core and physical scope.

# 0.7.2 — larger C integration workload

- Add sorting/matrix/CRC/recursion/search/signed division/bit manipulation and one-shot timer IRQ workload.
- Compile/audit and simulate actual ELF image in ECC/TMR modes; publish independent reference, dynamic instruction counts, phase counters, stack observation and full retirement traces.
- Both modes pass: 3340 retirements, 20232 cycles, one timer IRQ and matching results. No intentional faults injected.

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
