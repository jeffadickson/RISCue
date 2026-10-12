# KV260 ARM-supervised RISCue laboratory target

The intended board is the Kria KV260/K26 SOM (the request said KV206, treated
as KV260). This target places RISCue in PL and uses the existing Cortex-A53
Linux system as a laboratory supervisor. No ARM instruction emulation,
PS DDR data path for RISCue, or Linux-on-RISCue is required. Firmware executes
from the local 32 KiB ECC SRAM; ARM reaches a protected AXI4-Lite control and
memory loader through M_AXI_HPM0_FPD and SmartConnect.

## Included implementation

- `rtl/riscue_kv260_axi.sv`: independently captured AW/W, held read/write
  responses, byte strobes, TMR protocol/command/telemetry state and a host
  memory timeout. The existing protected campaign controller schedules FI.
- `rtl/riscue_axi_soc.sv`: separate hart reset and SRAM/controller reset,
  foreground ECC, runtime idle scrub, loader/core ownership and error recorder.
- `build.tcl`: official KV260 board-preset discovery, K26 PS block design,
  10 MHz default PL clock, AXI register map at 0xA0000000, explicit synthesis
  or timing/DRC-gated bitstream and XSA generation.
- `riscue-uio.dts`: Linux UIO overlay template with matching PL0 clock rate.
- `tools/kv260/riscue_ctl.py`: UIO CLI, checked ELF/raw loader and full SRAM
  readback, telemetry, reset/boot, external IRQ and injection commands.
- `tools/kv260/dashboard.py` and `dashboard.html`: ARM-hosted browser UI.
- `firmware/platform`: freestanding ILP32 C demo, startup, trap frame, timer
  and mailbox. Software contract: `docs/SOFTWARE_ABI.md`.

The generic AXI wrapper passed a short simulation covering program loading,
partial writes, response backpressure, telemetry, running loader rejection,
reset/data retention and a hardware fault campaign. Real Vivado IP generation,
implementation, Linux overlay binding, PS/PL clock setup and physical KV260
operation have not been verified. Vendor IP is not simulated by this test.

## Build and Linux integration

```sh
make kv260-synth
make kv260                         # .bit, .bin and .xsa, explicit build only
make kv260-dtbo                    # requires dtc, matching Linux base DT
make firmware-platform             # requires bare-metal RISC-V GCC/binutils
```

Install K26 device support and the official KV260 preset for the chosen Vivado
release. Set KV260_BOARD_REPO if needed, or KV260_BOARD_PART to select an
installed exact preset. The script uses part xck26-sfvc784-2LV-c and validates
block-design connectivity. RF_MODE=tmr selects TMR registers; KV260_FI defaults
1 for this lab target and can be set to 0. KV260_CLK_HZ defaults 10000000 and
must match the device-tree assigned-clock-rates and C timer constant.

Use the corresponding KV260 Linux BSP/base device tree and its supported
FPGA-manager/application flow to load this full-PL bitstream. Replace/remove
any active PL application first. This repository does not overwrite QSPI,
boot firmware or the Linux image. Existing PS initialization must enable the
same HPM interface/clock represented by the exported XSA; otherwise generate
a matching platform boot configuration from that XSA using the vendor flow.
Confirm the base tree exports zynqmp_clk and that clock ID 71 is PL0_REF for
that BSP before applying the UIO overlay. Custom clock values require editing
or generating the overlay to match; no silent frequency inference is made.

Linux needs UIO and a generic-uio binding supporting this polled, no-interrupt
peripheral (commonly uio_pdrv_genirq with of_id=generic-uio). Match the UIO node
by its name/map address, not by assuming it is always uio0. Grant access to
one lab operator/process. The bridge's diagnostics are not a standard RISC-V
DM and the ARM/Linux host is not claimed radiation tolerant.

On the board, with the correct /dev/uioN available:

```sh
python3 tools/kv260/riscue_ctl.py --device /dev/uio0 status
python3 tools/kv260/riscue_ctl.py --device /dev/uio0 load build/platform-demo.elf
python3 tools/kv260/riscue_ctl.py --device /dev/uio0 run
python3 tools/kv260/dashboard.py --device /dev/uio0 --bind 127.0.0.1 --port 8080
```

Use an SSH tunnel (`ssh -L 8080:127.0.0.1:8080 user@board`) and open
http://127.0.0.1:8080 locally. The default server is loopback-only, rejects
cross-origin control and serializes device operations. It has no user-account
authentication; an explicitly chosen LAN bind remains a trusted lab service.
CLI and dashboard must not concurrently own the same UIO device.

## Register map (offset from 0xA0000000)

| Offset | Register / meaning |
| --- | --- |
| 0x00 / 0x04 | ID 0x52495343; AXI ABI 1 / FI ABI 2; RF_TMR bit16, FI_ENABLE bit17 |
| 0x08 | Control: bit0 RUN, bit1 external IRQ level, bit2 pulse SRAM-control/recorder reset (RUN must be 0) |
| 0x0c | bit0 RUN, bit1 observed fatal, bit2 observed trap, bit3 FI busy; bridge disagreement/fatal bits30/31 |
| 0x10 / 0x14 / 0x18 / 0x1c | Sampled architectural PC / mcause / mtval / hardware sticky flags |
| 0x20..0x2c | Corrected, uncorrectable, disagreement, fatal detector counts |
| 0x30 / 0x78 | Host-observed retirement count low/high |
| 0x34 / 0x38 / 0x3c | SRAM words / declared clock Hz / last retired raw instruction |
| 0x40 / 0x44 / 0x48 | FI target / index / bit0 request token + bit1 arm |
| 0x4c / 0x50 / 0x54 / 0x58 | Delay / count (low16) / gap / trigger PC |
| 0x5c / 0x60 | Trigger kind bits1:0, rotate bit2, stop-on-fatal bit3 / modular index step |
| 0x64 / 0x68 | Controller status bits7:0, busy bit8, done token bit9, disagreement/error bits30/31 / accepted low16, attempted high16 |
| 0x6c / 0x70 / 0x74 | Last injection PC / injection cycle low/high |
| 0x80..0xbc | 16 little-endian 32-bit mask words, low word first |
| 0x10000..0x17ffc | SRAM words (default 8192), load/read only while RUN=0 |

All AXI transactions are aligned 32-bit accesses with WSTRB byte enables.
Unmapped/unaligned or running SRAM requests return SLVERR. Command counts and
reserved bits must follow the ABI; the supplied driver validates descriptors.
Multi-register telemetry is a best-effort sample, not an atomic coherent dump.

RUN=0 holds the hart in reset: GPRs, CSRs, pipeline and core counters clear.
SRAM stays intact, and bridge telemetry retains the last running sample.
Boot after stop begins at zero; it is not resume. Stop/read mailbox deliberately
resets the hart before reading memory. SRAM-control reset clears endpoint fatal
state and the event recorder, not SRAM. Idle scrub is paused while stopped so
a full-word loader can repair all SRAM without racing a background fatal scan;
foreground ECC checks stay active, and idle scrub resumes on RUN.

Standard halt/resume/single-step/GDB support is separately specified in
`docs/DEBUG_AND_MISSION_FEATURES.md`. RISCue's digital mitigation model still
excludes shared combinational/voter/clock/reset/configuration faults; TMR
bridge state and structural attributes do not prove physical independence.

Primary board/platform references:
- https://xilinx.github.io/Vitis-Tutorials/2022-1/build/html/docs/Vitis_Platform_Creation/Design_Tutorials/01-Edge-KV260/step4.html
- https://docs.amd.com/r/2024.2-English/Vitis-Tutorials-Vitis-Platform-Creation/Create-Base-Vivado-Project-from-Preset
