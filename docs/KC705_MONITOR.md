# KC705 serial development monitor

The default KC705 target connects the five-stage CPU AXI4-Lite master and a UART-controlled AXI4-Lite master to the same SECDED RAM. The monitor owns RAM at power-up; the CPU is held in reset. A bitstream can load and run multiple ELF images without reconfiguration.

The monitor, UART, clock/reset circuitry, boot-address controls and ownership mux are laboratory infrastructure. They are not radiation-qualified or protected by the CPU's TMR guarantees. Memory ECC protects stored codewords, not arbitrary corruption on AXI wires. The core, AXI bridges and ECC RAM retain their existing protection. A deployment must disable or separately protect this laboratory control plane.

## Build and use

```
make kc705 KC705_WORDS=2048          # 8 KiB data, ECC register file
make kc705-program KC705_WORDS=2048
python -m pip install pyserial
python tools/kc705_monitor.py --port COM5 ping
python tools/kc705_monitor.py --port COM5 load build/c-smoke/smoke.elf --run
python tools/kc705_monitor.py --port COM5 status
python tools/kc705_monitor.py --port COM5 stop
python tools/kc705_monitor.py --port COM5 read 0xfc0 --words 16
```

Build the smoke ELF with `make c-smoke-build` and the supported RISC-V cross compiler. The loader validates all ELF32 little-endian RV32 executable segments before writing, initializes BSS, zero-pads partial boundary words, reads back every loaded word, and optionally runs at the ELF entry point. It rejects dynamic executables, incompatible ABI flags, bad segment bounds and conflicting overlaps. ELF attributes/instruction legality remain the responsibility of the existing compiler-profile audit; the UART loader does not disassemble arbitrary ELF instructions.

115200 baud, 8N1, no flow control. Linux port example: `/dev/ttyUSB0`. This binary protocol replaces the default target's periodic ASCII telemetry. `tools/kc705_console.py` remains for the original VIO/ILA target. The FPGA pin assignments are UART TX K24 and RX M19, LVCMOS25, from AMD UG810 Table 1-20: <https://docs.amd.com/v/u/en-US/ug810_KC705_Eval_Bd>.

`RF_MODE=tmr` selects TMR registers. `KC705_FI=1` enables serial RAM fault injection. `KC705_INSTRUMENTED=1` retains the original VIO/ILA wrapper and ASCII UART, documented separately; it does not enable the serial loader. The default serial target does not use the fault button. Power-up stops at the monitor even when a firmware image was initialized into RAM.

## Commands and ownership

| Command | Code | Address / data / auxiliary | Result data / auxiliary |
| --- | ---: | --- | --- |
| Ping | 0 | zero | `0x52495343` / RAM byte size |
| Status | 1 | selector / zero / zero | See below |
| Read word | 2 | aligned RAM address / zero / zero | decoded data / zero |
| Write word | 3 | aligned RAM address / full word / zero | unspecified / zero |
| Run | 4 | halfword-aligned entry / zero / zero | zero / zero |
| Stop | 5 | zero | stopped architectural PC / zero |
| Inject | 6 | aligned byte address / mask bits 31:0 / mask bits 38:32 | zero / zero |
| Recover memory controller | 7 | zero | zero / zero |

Read, write, inject, recover and run require stopped ownership, idle bridges and an idle RAM endpoint. Writes are full words and generate fresh ECC. Injection is restricted to RAM codewords and compiled out unless enabled. Status remains available during execution or a CPU fault. Run resets architectural state (including counters/CSRs/registers) at the supplied address; it is not resume or single-step.

Stop inhibits new fetches, finishes any split instruction fetch, drains the pipeline and accepted AXI transactions, then hands RAM to the monitor. It preserves CPU state while stopped; timers and register scrubbing continue. Fatal cores can relinquish RAM after their bridge drains, even though pipeline stages remain occupied. A stop timeout retains CPU ownership and keeps halt requested. It never switches a live AXI transaction to another master.

No general-purpose bus abort is provided. A host-bridge timeout locks out subsequent memory commands; inspect status and reset the board. Normal ECC RAM DED is recoverable: stop, record status, `recover`, overwrite damaged words with known-good data or reload the full program, then run. Controller recovery preserves RAM and counters and does not repair damaged codewords. Background scrub is paused during monitor ownership and enabled when running. A CPU fatal is cleared by run's architectural reset after memory repair.

Status selectors: 0 = PC / flags; 1 = corrected / uncorrectable counts; 2 = disagreement / fatal counts; 3 = last error address / six-bit syndrome; 4 = trap cause / trap value; 5 = retired instruction count / zero. Flag bits 0..5 mean running ownership, CPU released from reset, CPU fatal, memory fatal, injection enabled, host bridge locked. Counters 1..3 describe the memory endpoint; they are not aggregate counts of all core events.

## Wire protocol v1

One outstanding request. Both frames are 20 bytes; multibyte integers are little-endian.

| Offset | Request | Reply |
| ---: | --- | --- |
| 0..1 | `a5 5a` | `5a a5` |
| 2 | sequence byte | echoed sequence |
| 3 | command | status |
| 4..7 | address | echoed address |
| 8..11 | data | result data |
| 12..15 | auxiliary | result auxiliary |
| 16..19 | CRC-32 over bytes 2..15 | CRC-32 over bytes 2..15 |

CRC is reflected IEEE CRC-32, polynomial `0xedb88320`, initial/final XOR `0xffffffff`, compatible with Python `zlib.crc32`. No command has effects until CRC validation. An interbyte gap of approximately 40 bit periods discards a partial frame; UART framing errors also discard it. Bytes arriving while a command or reply is in progress are not queued. Hosts must wait for a complete reply.

Retry an unanswered request with identical sequence and payload. The monitor caches the last CRC-valid completed request and reply, preventing duplicate injection or run when an acknowledgment is lost. Same sequence with a different request returns status 8. Increment sequence for each new command (wrap at 256); reconnect ping handles a collision. Replay protection covers only the most recent command, not arbitrary historical retransmissions or independent concurrent hosts.

Statuses: 0 success, 1 unknown command, 2 CRC failure, 3 invalid argument, 4 busy/unsafe ownership, 5 memory/bus error, 6 timeout, 7 injection disabled/rejected, 8 sequence collision. There is no authentication; physical serial access grants load/run/injection capabilities in enabled laboratory builds.

## Verification

`make monitor-tools` installs the pinned Linux x86-64 Verilator without root (requires `dpkg-deb`, Perl, Make and a C++ compiler with coroutine support). Then use `make test-monitor VERILATOR=.tools/monitor-verilator/verilator`; an existing Verilator installation also works.

`make test-monitor` builds the C image, tests the Python loader, and uses Verilator with timing support to exercise real UART bits in ECC and TMR modes. It uploads an ELF-derived image through CRC-protected packets, starts it, stops it, and reads result mailboxes through the monitor. `make test-monitor-icarus` runs the directed serial suite using Icarus; it is substantially slower.

Directed checks include packet CRC, replay/collision, partial packet timeout, invalid commands/addresses, busy writes, single-bit correction, DED response and recovery, nonzero halfword-aligned entry, split fetch, and run/stop/restart. CPU and AXI baseline regressions supplement these. Full AXI formal proof, monitor fault tolerance, Vivado implementation, timing closure and physical board operation remain separate validation tasks.

Recorded validation: four Verilator runs passed (protocol and compiled C, each with ECC/TMR registers), five Python tests passed, seven Icarus fault/bus regressions passed, both KC705 variants compiled with vendor stubs, and the monitor converted through sv2v. The C image loaded 84 words (336 bytes including BSS/padding) through physical serial frames; expected mailbox values were read back through monitor commands. See [versioned evidence](../verification/kc705-monitor-results.json).
