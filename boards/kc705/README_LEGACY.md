# KC705 laboratory target

Version 0.5 selects riscue_pipeline_soc (five-stage RV32IMC machine core). Its functional verification and Vivado/board bring-up are pending. The board image/clock/pin interface below is retained. VIO/ILA campaign builds and ABI 2 are documented in lab/README.md. The external IRQ core input is tied inactive by this board wrapper.

Target part: `xc7k325tffg900-2`. This adds a board wrapper and an explicit Vivado synthesis/implementation flow. No Vivado build, simulation, formal campaign or board programming has been run for this target. Timing, pin operation and resource fit remain unverified.

## Build

Install Vivado with Kintex-7 device support and expose `vivado` on PATH. GNU Make and Python 3.12+ are also needed. No RISC-V cross compiler is needed for the supplied hand-encoded demo image.

```sh
make kc705-synth                 # synthesis and structural redundancy report only
make kc705                       # ECC register file, FI disabled, 10 MHz
make kc705 RF_MODE=tmr           # TMR register file
make kc705 RF_MODE=tmr KC705_FI=1 # enable the north-button single-bit demonstration
```

Without GNU Make, native PowerShell can invoke the same flow from the repository root:

```powershell
python tools/prepare_fpga_image.py firmware/kc705/demo.hex build/kc705-ecc-fi0-d100/firmware.hex --words 1024
vivado -mode batch -nojournal -log build/kc705-ecc-fi0-d100/vivado.log -source boards/kc705/build.tcl -tclargs build/kc705-ecc-fi0-d100 0 0 1024 100 bit
```

Build outputs are isolated by RF mode, FI setting and clock divider, for example `build/kc705-ecc-fi0-d100/`. The build validates/pads `firmware.hex`, then produces synthesis/implementation checkpoints, utilization, timing, DRC, CDC and redundancy reports. It emits `riscue_kc705.bit` only after setup/hold timing and error-level DRC checks pass. Warnings and CDC reports still require review. A retained replica count is a structural check, not fault-containment or physical radiation qualification.

`make kc705` never runs simulation/formal and never programs the board. The separate explicit command is:

```sh
make kc705-program              # same RF_MODE/KC705_FI/KC705_CLK_DIV as the build
```

The programmer requires exactly one connected XC7K325T in the selected hardware target. It uses volatile JTAG configuration; flash programming is not provided.

## Clock, firmware and memory

The fixed 200 MHz differential clock drives an MMCM at a 1 GHz VCO. `KC705_CLK_DIV=100` generates 10 MHz; `128` selects approximately 7.8125 MHz. Allowed dividers are 8–128. Clock lock/reset release is synchronized. The slow default is a bring-up choice; the current M extension uses protected multicycle units. If the slowest divider cannot close timing, the execution datapath needs redesign; do not waive internal timing paths.

The default reference ECC memory is 1,024 words (4 KiB data plus SECDED bits). Change `KC705_WORDS` between 1,024 and 8,192, subject to implementation fit. Vivado may map the reference asynchronous-read/scrub array into distributed RAM or registers; BRAM inference is not promised. The target does not use external DDR3, MIG, PCIe or Ethernet.

The demo stores MUL/DIV/REM results at 0x800, 0x804 and 0x808, then continuously increments a counter at 0x80c. `firmware/kc705/demo.S` documents the instructions; `demo.hex` is the hand-encoded image. The image itself has not been run on the board. Program execution starts at address zero.

For your own little-endian binary, convert it to word hex with `tools/bin_to_hex.py`, then select it:

```sh
python3 tools/bin_to_hex.py program.bin program.hex --words 1024
make kc705 KC705_IMAGE=program.hex
```

## Controls and indicators

SW7 resets the core. In an explicitly FI-enabled build, a debounced rising press of SW2 (north) flips SECDED bit 0 of the final SRAM word once. A normal build disables this injection. The memory's background scrub or foreground access can repair the injected bit and record the observation.

| LED | Meaning |
| --- | --- |
| 0 | Clock heartbeat |
| 1 | Recent instruction retirement |
| 2 | Halted |
| 3 | Fatal fault |
| 4 | Sticky corrected observation |
| 5 | Sticky uncorrectable observation |
| 6 | Sticky replica disagreement |
| 7 | Architectural trap |

The USB-UART connector J6 emits one ASCII snapshot per second at 115200 baud, 8N1, with flow control disabled. Fields after `RISCue` are ten eight-digit hexadecimal words: PC, cause, tval, flags, corrected count, uncorrectable count, disagreement count, fatal count, retirement count and status. Status bits 0/1/2 are halted/fatal/trap. This is diagnostic telemetry, not CPU software MMIO or a lossless event stream.

Use a terminal, or optionally install pyserial and decode snapshots as JSON:

```sh
python3 -m pip install pyserial
python3 tools/kc705_console.py --port COM5
# Linux example: --port /dev/ttyUSB0
```

UART receive/command loading is not implemented. The reporter's first/last record registers remain in the RTL but are not included in this small periodic packet.

## Protection boundary

The CPU, RAM controller and error recorder retain their protected-state mechanisms. Explicit Vivado `DONT_TOUCH` hints preserve their replica registers and both execution lanes; the build audits named groups before and after implementation. There are no placement-separated pblocks or redundant voters in this first board target. FPGA configuration-memory scrubbing (for example SEM), configuration-bit fault injection and protection of common clock/reset paths are not supplied by this wrapper; they are separate system-level work before radiation characterization.

Clock/MMCM, global reset, button synchronizers/debounce, heartbeat/activity, UART shifter and telemetry scheduler/snapshot state are **unprotected laboratory infrastructure**. They do not drive architectural bus writes; only reset and the explicitly enabled injection path influence the core. They must be treated separately before this wrapper is used for radiation testing with a defined system-level fault model.

## Pin and tool references

Pin facts are from [AMD/Xilinx UG810 v1.9](https://docs.amd.com/v/u/en-US/ug810_KC705_Eval_Bd), Tables 1-9, 1-20 and 1-27. The XDC uses SYSCLK AD12/AD11 (LVDS), reset AB7 (LVCMOS15), north button AA12 (LVCMOS15), UART TX K24 (LVCMOS25), and the eight GPIO LEDs. Maintain the board's normal 2.5 V VADJ configuration for the LVCMOS25 GPIO/UART bank.

[Current AMD Vivado licensing options](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/vivado-licensing-options.html) list all 7-series devices in the free BASIC tier. Older WebPACK/ML Standard releases limited free Kintex-7 support to smaller devices, so verify XC7K325T support/licensing for your installed release. Vivado is vendor software installed separately; the free formal-tool setup does not download it.
