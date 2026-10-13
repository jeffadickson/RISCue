# KC705 development target

The default target is now a UART monitor plus the RISCue AXI4-Lite CPU and SECDED memory. It powers up stopped, accepts ELF uploads over USB-UART, and can run, stop, inspect memory, report ECC faults and inject memory errors in explicitly enabled builds.

See [monitor setup, protocol and tests](../../docs/KC705_MONITOR.md). `make kc705` builds the FPGA image; `make kc705-program` programs volatile FPGA configuration. These are separate actions. Vivado with Kintex-7 support is required. No physical board or timing result is claimed.

The existing `KC705_WORDS`, `KC705_CLK_DIV`, `KC705_IMAGE`, and `RF_MODE` settings still apply. Default memory is 4 KiB data; the reference ECC array is not guaranteed to infer BRAM. The 200 MHz input feeds an MMCM; default core clock is 10 MHz. UART is 115200 baud, 8N1. The supplied initialized image can be started with `run 0`; the CPU does not start automatically.

LEDs: 0 heartbeat, 1 recent retirement, 2 stopped ownership, 3 fatal, 4 corrected RAM error observed, 5 uncorrectable RAM error observed; 6 and 7 reserved. Board reset returns to the monitor. The fault button is unused in this default build; serial injection requires `KC705_FI=1`.

The original VIO/ILA laboratory target remains selected by `KC705_INSTRUMENTED=1 KC705_FI=1`, with its original local-memory path and ASCII telemetry. See [legacy board guide](README_LEGACY.md) and [instrumented lab guide](lab/README.md). Its UART does not implement monitor commands.
