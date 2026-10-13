# Hardware debug: GDB, OpenOCD and RISCue

RISCue 0.8 adds a dedicated single-hart JTAG debug target. The tested connection
is **GDB → OpenOCD → JTAG pins → DTM → DMI debug module → pipeline/ECC SRAM**.
The simulation server forwards JTAG pin transitions; it does not emulate an ISA
or translate GDB register requests itself. The same synthesizable RTL is used
by the separate KC705 debug wrapper.

The implemented profile advertises Debug Module version 2 (RISC-V Debug 0.13),
DTM version 1, RV32 and one hart. It targets the **minimal** debug feature set,
not full Debug 1.0 conformance. This deliberately narrows the earlier Debug 1.0
roadmap to a working OpenOCD 0.12.0/GDB 15.1 implementation. Full compliance,
hardware triggers/watchpoints, a program buffer and Debug 1.0 migration remain
separate work. Ordinary processor instructions retain their existing ISA.

## What works

| Operation | Implementation |
| --- | --- |
| Halt / resume | Stop new fetch, finish accepted instructions and transactions, retain architectural PC and state, resume without reset |
| Reset halt | `ndmreset` resets core and SRAM controller while DM/DTM remain reachable; RAM contents survive; halt before first instruction |
| Registers | Abstract 32-bit access to x0–x31, dcsr/dpc and implemented machine/counter CSRs; read-only and unknown writes rejected |
| Single instruction | Admit one instruction, including both halves of a straddling instruction; stop after completion or synchronous trap |
| Breakpoints | Software EBREAK/C.EBREAK; normal exception behavior remains when dcsr.ebreakm is clear |
| Memory | SBA byte/halfword/word accesses through SECDED SRAM, while halted and quiescent |
| C source debug | Host ELF/DWARF: source breakpoints, variables, register/memory editing and stepping |
| IDE | VS Code C/C++ `cppdbg` launch configuration; other GDB front ends can use the same server |

No hardware execution breakpoints, data watchpoints, flash programming, RTOS
awareness, authentication, live-running memory access or instruction trace
stream is provided. GDB source debugging needs a matching compiler-produced
ELF with debug information. Zeal binary/HEX output remains suitable for machine
code debugging, without a claim of DWARF source support.

## Reproduce the actual GDB test

On Ubuntu 24.04 x86-64 with a C++ toolchain and the existing RISC-V compiler:

```sh
make debug-tools                  # SHA-256-pinned local OpenOCD/GDB bundle
make monitor-tools            # existing local Verilator setup, if needed
make test-debug                   # ECC and TMR GDB sessions + directed regressions
```

If the Verilator setup target in an older checkout is unavailable, run
`python3 tools/setup_monitor_sim.py`. `RISCV_CC`, `VERILATOR`, `OPENOCD` and `GDB`
can select native tools instead. The default compiler is the repository-local
`.tools/riscv/root/usr/bin/riscv64-unknown-elf-gcc`. Missing prerequisites fail;
the tests do not silently skip. Pinned packages are extracted locally, without
system installation. Other operating systems should use native tool packages.

The GDB test compiles `tests/debug/example.c` and `start.S` with `-g -O0`, loads
its ELF over SBA, stops inside `debug_done`, checks `answer == 42`, changes it,
edits a GPR, steps a mixed compressed/straddling instruction sequence, handles
EBREAK, checks subword memory writes and verifies reset halt. A monitor reset
requires `maintenance flush register-cache` before GDB reads cached registers.

Reports: [ECC GDB](../verification/debug-gdb-ecc.json),
[TMR GDB](../verification/debug-gdb-tmr.json),
[directed and regression tests](../verification/debug-directed.json).
Reports identify source hashes; logs and binaries are under `build/debug/`.
The directed build uses Verilator `--public-flat-rw` and forced corruption of
replicas, and asserts that each intended detector actually activates before
checking recovery. This prevents optimized-away testbench deposits from
counting as fault coverage. The suite exercises command rejection, x0, ECC regeneration, single
replica debug-state repair, SBA alignment, reset halt, step/exception/interrupt
priority, rejection of fatal resume and sticky DM majority-loss failure. It also reruns the debug-disabled
pipeline smoke tests and jump tests across their ECC/TMR and early/late modes.

## Interactive simulation and VS Code

Build once with `make debug-sim`. In separate terminals:

```sh
build/debug/sim/Vriscue_debug_soc
.tools/debug/openocd -f debug/openocd-sim.cfg
.tools/debug/gdb-multiarch build/debug/example.elf
```

In GDB:

```gdb
target extended-remote localhost:3333
monitor reset halt
load
set $pc = _start
break main
continue
```

Open the repository in VS Code, install Microsoft's C/C++ extension, and select
**RISCue: GDB via OpenOCD** from `.vscode/launch.json`. Start the simulator and
OpenOCD first. Adjust `program` for your ELF and `miDebuggerPath` for your host.
The launch commands reset, load and set `_start`, so they intentionally replace
the running application. The GDB path was executed; the VS Code GUI itself has
not been exercised in this environment.

OpenOCD ports and the simulation socket bind to loopback. Its warning about a
missing program buffer/fence is expected: this target has no cache, SBA requires
quiescence, and resume fetches anew from dpc. Do not generalize that coherence
argument to a future cached or DMA-enabled wrapper.

## Core state, ordering and protection

`DEBUG_ENABLE=0` is the core default. Existing monitor, AXI and packet wrappers
do not acquire a JTAG port simply by updating the core. `riscue_debug_soc`
explicitly enables debug and provides its own 8 KiB ECC SRAM wrapper.

Seven architectural debug bits were added at the most-significant end of the pipeline TMR record:
halted, step, step-issued, ebreakm and three cause bits. Its logical width is
now 4,038 bits. Existing field bit offsets are preserved; the seven new bits
extend the final FI window. Campaigns should use the current generated widths;
there are still eight 512-bit windows. The DM separately triplicates captured
run-control, commands, data and SBA bookkeeping. One disagreeing copy is voted
out and repaired. Loss of a complete-record majority latches DM failure,
suppresses commands and makes the hart unavailable until external reset.

| Situation | Defined behavior |
| --- | --- |
| Halt request | Existing accepted instructions may finish, including stores; no new instruction fetch starts except completion of an already split fetch |
| EBREAK with ebreakm | Enter debug at the breakpoint PC; do not retire the breakpoint or issue younger stores |
| Step + ordinary completion | Stop at the instruction's architectural next PC with dcsr.cause=4 |
| Step + synchronous exception | Perform normal trap entry, then stop at mtvec; exception CSRs preserve the cause |
| Step + pending interrupt | Interrupt entry is suppressed for the step (stepie=0); pending state remains available afterward |
| Halted counters | mcycle and mtime stop; minstret does not increment; IRQ synchronization and RF repair continue |
| Fatal integrity error | Hart reported unavailable, not a resumable debug halt; debug does not clear a fault |
| SBA + resume | Resume waits for SBA and abstract commands to complete |
| Reset | Core/RF/CSR state resets; SRAM contents are retained, including any damaged codewords |

The TAP, CDC synchronizers, external JTAG wires, clocks/resets and shared voter/
combinational logic are **not** covered by these state-replication claims.
This is a trusted laboratory interface, not a radiation-qualified or secure
debug subsystem. A fatal core cannot be inspected through ordinary abstract
commands in this initial implementation; dmstatus remains readable. Existing
monitor/fault telemetry paths are separate targets. For a corrupted RAM word,
resetting the controller does not repair data: reload or overwrite it.

## DMI register map

Addresses below are DMI word addresses, not memory byte addresses.

| Address | Register | Supported behavior |
| --- | --- | --- |
| 0x04 | data0 | One 32-bit abstract-command data register |
| 0x10 | dmcontrol | dmactive, haltreq, resumereq, ndmreset, ackhavereset, set/clrresethaltreq; hartsel WARL zero |
| 0x11 | dmstatus | Version 2, authenticated, reset/halt/resume/running/unavailable state |
| 0x12 | hartinfo | Zero: no program-buffer debug RAM |
| 0x16 | abstractcs | datacount=1, progbufsize=0, busy and sticky cmderr |
| 0x17 | command | Access Register, aarsize=2, transfer/write; no postexec/postincrement |
| 0x18 | abstractauto | Zero; no autoexecution |
| 0x38 | sbcs | sbversion=1, 32-bit addresses, access sizes 8/16/32, busy/error, autoincrement/read-on-address/read-on-data |
| 0x39 | sbaddress0 | Byte address; natural alignment required |
| 0x3c | sbdata0 | Read result / write payload |

DCSR exposes xdebugver=4, prv=M, writable step/ebreakm and read-only cause,
stopcount=1, stoptime=1, stepie=0. DPC aliases the halted architectural PC and
clears bit zero on writes. GPR abstract numbers are 0x1000–0x101f; CSR numbers
use their standard addresses. Unsupported commands fail with sticky cmderr;
SBA errors must be cleared through sbcs before retry. SBA is limited to SRAM,
not the core-internal CLINT or arbitrary system peripherals.

The TAP has 5-bit IR: IDCODE=0x01, DTMCS=0x10, DMI=0x11, BYPASS=0x1f. DMI scans
have 7 address + 32 data + 2 operation bits. Its IDCODE `0x00000001` is an
unassigned laboratory placeholder; OpenOCD prints an invalid-manufacturer
notice. It is not a registered silicon vendor ID. DMI reset clears sticky DTM
status; it does not abort an already accepted target operation. No optional
DTM hard-reset feature is implemented.

## KC705 dedicated debug target

`make kc705-debug RF_MODE=ecc STAGE=synth` invokes Vivado; `STAGE=bit` additionally
places/routes and checks timing/DRC. It uses a 10 MHz core clock and a separately
constrained JTAG clock at up to 1 MHz. The normal UART-monitor bitstream is
unchanged. **This target uses an external JTAG adapter and FMC-LPC breakout;
it does not tunnel through the onboard USB FPGA-programming JTAG port.**

Pin mapping from [AMD UG810 v1.9, Table 1-29](https://docs.amd.com/v/u/en-US/ug810_KC705_Eval_Bd):

| Debug signal | FMC LPC J2 pin | FPGA package pin |
| --- | --- | --- |
| TCK | G6 (LA00_CC_P) | AD23 |
| TMS | G7 (LA00_CC_N) | AE24 |
| TDI | D8 (LA01_CC_P) | AE23 |
| TDO | D9 (LA01_CC_N) | AF23 |

Set/verify VADJ=2.5 V and use an adapter/breakout with matching 2.5 V signaling,
common ground and VTref. These are user I/O pins, not J2's configuration-chain
JTAG pins. Do not connect a fixed 3.3 V adapter to these pins. Program the FPGA
normally, then run OpenOCD with your adapter configuration followed by
`debug/openocd-kc705.cfg`. No adapter model is assumed by the target file.

The XDC constrains both clocks, external JTAG timing, synchronizer first stages
and bounded bundled-data crossings. CDC/placement/timing reports must still be
reviewed on a real Vivado implementation. RTL simulation and vendor-stub
elaboration do not establish physical timing closure or operation on the board.

## References and acceptance boundary

- [RISC-V debug specification](https://github.com/riscv/riscv-debug-spec)
- [OpenOCD RISC-V commands](https://openocd.org/doc-release/html/Architecture-and-Core-Commands.html)
- [GDB remote protocol](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Remote-Protocol.html)
- [VS Code C/C++ launch configuration](https://code.visualstudio.com/docs/cpp/launch-json-reference)

Requirements DBG-001 through DBG-009 are traced in REQUIREMENTS.md. Tests prove
the listed implemented operations in simulation, not exhaustive debug-spec
conformance, full fault coverage, GUI operation or hardware qualification.
