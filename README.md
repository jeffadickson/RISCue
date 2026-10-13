# RISCue

A five-stage, machine-mode RV32 processor prototype with SECDED memory, optional TMR registers, compared execution lanes, fault injection and a serial development monitor.

**Start with the [RISCue developer and verification manual](docs/RISCUE_MANUAL.md).** It covers architecture, code excerpts, software, fault protection, AXI, FPGA targets, the UART test rig and reproducible validation. The [documentation index](docs/README.md) links the detailed reference guides.

The [programmer reference](docs/PROGRAMMER_REFERENCE.md) provides instruction semantics, GPR/CSR tables, pipeline examples and precise ECC/TMR behavior. The [five-round independent review record](docs/reviews/DOCUMENTATION_REVIEW.md) tracks documentation findings and corrections.

## Current implementation

- RV32IMC + Zicsr + Zifencei + Zicntr + Zbb/Zbc/Zbs, standard ILP32 ABI.
- Five-stage pipeline, forwarding, early direct jumps, multicycle multiply/divide, precise traps, machine CSRs and CLINT-style interrupts/timer.
- SECDED or TMR register file, triplicated pipeline/arithmetic control, compared execution lanes and ECC RAM with scrub.
- AXI4-Lite CPU master and ECC RAM slave with error counters, address/syndrome reporting and optional stored-bit fault injection.
- KC705 UART monitor for ELF loading/readback, run, draining stop, status and memory recovery; original VIO/ILA target remains selectable.
- Standalone [UART packet processor](docs/PACKET_PROCESSOR.md): ECC byte FIFOs, protected CRC/watchdog control, bounded C echo/sum firmware and real serial-bit tests.
- Dedicated [hardware debug target](docs/HARDWARE_DEBUG.md): JTAG/DMI, OpenOCD/GDB, source breakpoints, single-step, ECC-aware memory access and a VS Code launch configuration.
- Separate KV260 ARM host-control AXI slave, loader/dashboard and campaign controls.

This is a digitally tested prototype, not a radiation-qualified or flight-ready processor. Shared logic, AXI transport, clock/reset/configuration and the laboratory monitor remain outside the stored-state protection guarantees. See [protection boundaries](docs/PROTECTION.md).

## What has run

Compiled C smoke, sorting/matrix/CRC/Fibonacci/interrupt workloads and signed FIR pass in ECC/TMR simulations. The CPU–AXI–ECC path passes all three programs in both modes. The UART rig loads and runs a compiled C ELF using serial bits, then stops and reads its results. Protocol, error injection, recovery and timeout tests pass.

[Versioned validation](docs/VALIDATION.md) distinguishes each configuration and source revision. Current-pipeline formal completion, full compliance, Vivado implementation/timing and physical KC705/KV260 operation remain pending. No FPGA area, achieved clock-rate or radiation-performance rating is claimed.

Packet application: `make test-packet` (cross compiler and Verilator) or `make test-packet-local` (existing pinned tool setup). This is a simulated target; the KC705 monitor remains the board default.

## Quick start

With Python, Make and Icarus Verilog installed:

```sh
make pipeline-smoke pipeline-jump
make test-axi-core-errors test-axi-master-bridge test-axi-ecc-ram
```

For the compiled-C UART test on Linux x86-64, with compiler setup prerequisites from the manual:

```sh
make c-tools monitor-tools
export PATH="$PWD/.tools/riscv/root/usr/bin:$PATH"
make test-monitor VERILATOR=.tools/monitor-verilator/verilator
```

For KC705 build, programming and serial commands, see [the board guide](boards/kc705/README.md) and [monitor reference](docs/KC705_MONITOR.md). Hardware commands require Vivado and the board; they are separate from simulation.

## Repository map

| Directory | Contents |
| --- | --- |
| `rtl/` | Current and preserved legacy cores, arithmetic, ECC, AXI and monitor |
| `boards/` | KC705/KV260 wrappers, constraints and vendor build flows |
| `firmware/` | Bare-metal C/assembly examples, startup and linker scripts |
| `tests/` | SV fixtures, cocotb tests and Python host/tool checks |
| `formal/` | RVFI and property harnesses; configured jobs are not proof results |
| `tools/` | Pinned setup, builds, loaders, reference models and test runners |
| `docs/` | Manual, requirements, interface contracts and historical references |
| `verification/` | Versioned results, traces and source hashes |
| `licenses/` | Third-party notices |
| `build/`, `.tools/`, `third_party/` | Local generated/downloaded content, excluded from Git |

`make test`, `make cocotb`, generic `make synth` and the original `make formal` refer to the preserved serialized RV32IM implementation. Use the explicit pipeline/AXI/monitor targets for the current core. Historical results are retained with their original scope.

`make docs` refreshes the manual's source excerpts; `make docs-check` verifies them and local links. See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md) and [the roadmap](docs/ROADMAP.md). Original code is MIT licensed; upstream code retains its own licenses. The [archived README](docs/LEGACY_README.md) preserves earlier implementation descriptions.
