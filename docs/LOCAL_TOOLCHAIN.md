# Local synthesis, formal tools and packet demonstration

The current pipeline has explicit tasks below. The older `make synth` target
continues to describe the legacy serialized SoC and is not a current-pipeline
resource estimate.

## Install and check the tools in Ubuntu

`make formal-tools` downloads the versions pinned in `tools/formal-tools.lock.json`,
checks their SHA256 values, and installs OSS CAD Suite plus sv2v. The suite includes
Yosys, SymbiYosys (SBY), yosys-smtbmc and SMT solvers. There is one Yosys installation
for synthesis and formal model preparation; a separate solver checks formal properties.
No administrator installation or Windows restart is needed for these user-local tools.

Large generated builds and tool binaries can live on Ubuntu's native filesystem
while sources stay in the shared Windows tree:

```sh
cd /mnt/c/dev/RISCue
RISCUE_FORMAL_TOOLS_ROOT="$HOME/.local/share/riscue-formal" make formal-tools
make formal-setup-check
```

The installer makes the normal ignored `.tools/oss-cad-suite` and `.tools/sv2v-Linux`
entry points refer to that location. To use the tools interactively:

```sh
PATH="$PWD/.tools/oss-cad-suite/bin:$PATH" yosys -V
PATH="$PWD/.tools/oss-cad-suite/bin:$PATH" sby --version
```

`formal-setup-check` runs the existing SECDED harness with arbitrary 32-bit data
and symbolic distinct fault locations. It checks clean decode, single-bit
correction, and double-bit detection. Its status/log are in `build/formal-setup/`.
PASS is scoped to those combinational properties. It is not a pipeline, replay,
instruction-set, liveness or flight-qualification proof. Non-PASS and timeouts
fail the task. See [formal contracts](FORMAL.md) before starting larger jobs.

## Kintex-7 resource estimate

```sh
make synth-pipeline-kintex7
make synth-pipeline-kintex7 PIPELINE_PROTECTION=PARITY_REPLAY ALLOW_EXPERIMENTAL_PARITY=1
make synth-pipeline-kintex7 SYNTH_RF_TMR=1
```

The default task reads the current SystemVerilog core directly with the pinned
Slang frontend. It runs the Series-7 primitive, DSP and flip-flop mapping stages
of Yosys `synth_xilinx -family xc7`, followed by a quick ABC `strash; if -K 6` mapping to uniform
six-input LUTs and final Series-7 checks. This is a resource estimate flow; it
does not use ABC9 timing optimization. It estimates the CPU core out of context, with fault
injection and standard debug disabled. RF protection remains independently
selectable. It does **not** include the external RAM, AXI endpoints, serial monitor,
clocking, JTAG or board peripherals. It inserts no I/O pads or clock buffers.

`build/yosys-kintex7/slang/<pipeline>-rf<RF_TMR>/` contains the result, mapping log,
statistics and synthesis script. Version/parameter/source hashes accompany the
counts. Large generated netlists live in `~/.cache/riscue-synthesis/`
(override `RISCUE_SYNTH_BUILD_ROOT`). A failed mapping is not a zero-resource result.

The initial paired RF_TMR=0 run recorded 33,524 LUT cells / 15,318 FF cells /
8 DSP48 cells for TMR, and 31,717 LUT cells / 10,033 FF cells / 8 DSP48 cells
for PARITY_REPLAY. Both use zero block-RAM primitives in this core-only flow.
See [versioned evidence](../verification/local-toolchain-2026-10-16.json) for
source hashes, scoped replica audits and failed prototype attempts. These are
quick-mapping cell counts, not packing or timing results.

The reference board is KC705/Kintex-7 XC7K325T. `xc7` chooses the Series-7 cell
library; it does not constrain packing to that particular device. LUT/FF/DSP/RAM
cell counts are not a placed utilization or timing result. Yosys may treat
preservation attributes differently from Vivado, and synthesis can merge or prune
redundancy. A complete mode-specific protection audit, vendor implementation,
timing/CDC analysis and physical separation checks remain open. These FPGA counts
also do not predict ASIC/Tiny Tapeout die area.

## David's packet processor page

```sh
make c-tools                 # pinned user-local RISC-V GCC/binutils, if absent
make packet-demo
```

The task compiles `firmware/packet-demo/main.c` and `crc16.S`, audits the linked
ELF against `docs/software-profile.json`, and executes it in RISCue RTL using
Verilator. The testbench checks `123456789 -> 0x29B1`, an empty packet, and a binary
packet against Python's independent CRC reference. It records a cycle/stage/
retirement CSV and a VCD waveform, then embeds the trace and assembly into:

`build/packet-demo/<pipeline>/heres-your-packet-processor-david.html`

The HTML is self-contained and can be opened in a browser or shared as one file.
Its CRC calculator runs JavaScript; its pipeline player displays saved RTL
observations. It does not run the RTL in the browser or substitute the JavaScript
calculation for the checked assembly result. Raw trace and VCD downloads remain
available from the page. The page links SharpTestBench; this particular trace
comes from a standalone testbench rather than that framework.

CRC parameters are CRC-16/IBM-3740 (CCITT-FALSE), polynomial 0x1021, seed 0xFFFF,
no reflection and final XOR zero. This example is not a SpaceWire or CCSDS
conformance test. Other protocols may require different parameters or coverage.

## Run from VS Code

In the WSL-connected workspace, select **Terminal -> Run Task** and choose a
RISCue task for synthesis, the SECDED proof, the packet HTML page, or pipeline
smoke. The terminal shows progress and generated logs remain in `build/`. These
tasks do not push commits or start GitHub Actions.
