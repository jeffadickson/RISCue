# Packet-processing application — RISCue 0.7.7

This is a standalone simulated application target, `riscue_packet_soc`, with
8 KiB of shared code/data SECDED SRAM, the current five-stage core, and a
CPU-accessible UART peripheral. It does not replace the KC705 development
monitor or change existing board targets. It uses the native ECC-coded CPU
interface rather than adding AXI transport to local packet storage.

## Architecture and protection

| Component | Implementation | Protection/boundary |
| --- | --- | --- |
| CPU | Current five-stage core; ECC or TMR registers | Existing compared execution/TMR control; existing limitations apply |
| Working memory | 2048 words by default; 39-bit codewords | SECDED, background scrub, fail stop on detectable double error |
| Packet buffers | Two 32-byte arrays in C BSS | Stored in ECC SRAM; alternated sequentially, no DMA or concurrent buffer ownership |
| Descriptor fields | Owner, lengths and complements in SRAM | ECC storage; firmware checks owner range and complements before use |
| UART FIFOs | 64 entries each, one 39-bit word per byte | SECDED on dequeue; correction counted, DED fails stop before byte delivery |
| UART metadata, response, CRC and watchdog | Three complete packed state records | Majority vote, repair each clock, fail stop on absence of a complete-record majority |
| UART serial engines | Existing center-sampled RX and 8N1 TX | Unprotected lab logic, including synchronizer, sampler, serializer and counters |
| Address decode, ECC/CRC functions and voters | Shared combinational logic | Common-mode fault boundary; no full logic TMR claim |

The UART queues allow reception while software processes a packet. The two
software buffers demonstrate bounded ownership and alternating storage;
they do **not** implement concurrent DMA ping-pong. The demo polls RX/TX,
although a level IRQ is available. There is no authentication, cryptographic
anti-replay, configured token-bucket rate limiter, or executable-memory isolation.

## MMIO contract

UART window: `0x10000000..0x100000ff`. Addresses must be word aligned. Writes
require a full-word mask. Unknown offsets, empty RX reads and full TX writes
return a bus error. Requests use the existing held native interface: one side
effect on initial acceptance, response held until request drops. Request
address/control/write-data are ECC checked; DED fails stop. Corrected requests
execute using decoded data. Reset clears metadata and abandons pending traffic;
FIFO storage is not cleared, but counts prevent stale entries from being read.

| Offset | Access | Meaning |
| --- | --- | --- |
| `0x00` | R | Bit 8: RX nonempty; bit 9: TX full; other bits zero |
| `0x04` | R | Pop one decoded RX byte |
| `0x08` | W | Queue low byte for TX |
| `0x0c` | RW | Bit 0 enables level IRQ: RX nonempty or sticky framing/overflow/fatal |
| `0x10` | RW | CRC accumulator; initialize to `0xffffffff`, read then XOR with `0xffffffff` |
| `0x14` | W | Feed low byte into reflected IEEE CRC-32, polynomial `0xedb88320` |
| `0x18` | R | Corrected-error event count |
| `0x1c` | R | UART framing-error count |
| `0x20` | R | RX overflow count; incoming byte dropped when full |
| `0x24` | RW | Watchdog reload in clocks; zero disables; writing reloads immediately |
| `0x28` | W | Pet watchdog; data ignored |

Counters wrap modulo 2^32. Framing/overflow counters clear only on reset; hence
an enabled IRQ stays asserted after an error. A production interrupt driver
needs an acknowledgement/clear interface. Watchdog expiry latches peripheral
fatal and propagates to the CPU external-fault input. It is fail stop, not an
automatic reset or firmware recovery. Firmware pets while servicing RX/TX;
this detects cessation of service, not every possible logical hang.

## Packet and firmware contract

Wire format is `A5 | length | sequence | operation/status | payload | CRC32`.
Length is the payload count, maximum 32. CRC covers length, sequence,
operation/status and payload, excluding the sync byte. CRC is four little-endian
bytes. The same framing is used in both directions.

| Request opcode | Reply |
| --- | --- |
| 1 | Echo payload; status 0 |
| 2 | Sum unsigned payload bytes; four-byte little-endian sum; status 0 |
| Other | Empty payload; status 2 |
| Sequence equal to last completed valid request | Empty payload; status 3 |

A bad CRC, oversized length or partial-frame timeout produces no reply.
Firmware scans for the next sync byte. RX bytes are serviced by polling; a
partial read times out after 200,000 `mcycle` ticks. A maximum size check
precedes every packet-buffer write. Descriptors are rechecked before payload
processing. Descriptor corruption increments a mailbox counter and exits to
`_finished`; a production supervisor must decide the recovery action.

Duplicate detection remembers only the immediately previous completed valid
request. It is not a sliding anti-replay window and does not survive reset.
Echo/sum have no external actuator side effects. The protocol is a demonstration,
not CCSDS or a secure flight command protocol. Nested sync bytes in discarded
traffic can cause tentative framing; CRC and bounds checks still gate acceptance.

Firmware and stack occupy shared RAM below `0x1f00`; a 1 KiB stack is reserved by
the linker. Mailbox at `0x1fc0`: ready magic `0x5041434b`, accepted packets,
CRC rejects, length rejects, timeouts, descriptor rejects, duplicates, unknown
operations, then reserved words. `stats[1]` counts successful echo/sum requests.
A missing length byte after the sync byte is counted in `stats[3]` (length rejects), because the firmware combines failure to receive length with its length-range check. Partial-frame failures after a valid length increment `stats[4]` (timeouts). Neither case sends a reply.

Sources: [firmware](../firmware/packet/main.c),
[startup](../firmware/packet/start.S), [linker](../firmware/packet/link.ld),
[UART peripheral](../rtl/riscue_packet_uart.sv),
[SoC](../rtl/riscue_packet_soc.sv).

## Fault injection

A separate packet FI port is gated by `FI_ENABLE=0` by default. Its ABI is local
to this demo, distinct from core FI ABI 2. Acknowledge means an injection was
applied on the accepting edge; simultaneous FIFO write/repair rejects FIFO FI.
Masks must be nonzero and fit the named target. This is trusted laboratory access.

| Target | Index | Mask |
| --- | --- | --- |
| 0 | RX FIFO physical slot, less than DEPTH | 39-bit codeword XOR |
| 1 | TX FIFO physical slot, less than DEPTH | 39-bit codeword XOR |
| 2 | State replica 0, 1 or 2 | Packed `state_t` XOR, low bit is last field's low bit |

Existing core/RAM FI ports remain available. Single-replica state injection
repairs on the next clock. The majority-loss test deliberately corrupts two
replicas to distinct values on the same edge through simulation hierarchy;
sequential public injections would be repaired between edges.

## Build and verification

```sh
make test-packet                  # Installed cross compiler and timing-capable Verilator
make test-packet-local            # Fetch pinned compiler/simulator via existing setup targets
make test-packet VERILATOR=.tools/monitor-verilator/verilator
```

The [builder](../tools/build_packet.py) uses the existing machine-readable ISA
profile, compiles freestanding C, audits linked instructions/attributes and
emits an initialized RAM image. [Python test runner](../tools/run_packet_tests.py)
generates independent `zlib.crc32` request/reply vectors and runs actual serial
bits through RTL and compiled firmware. It does not use pyserial or a physical
board. Results are in `build/packet/results.json`; versioned evidence is
[packet-results.json](../verification/packet-results.json).

[Peripheral unit tests](../tests/tb_packet_uart.sv) cover held request behavior,
RX IRQ, CRC `123456789`, bad accesses, RX overflow/framing, RX/TX SEC and DED,
state repair, majority loss and watchdog expiry. They use a small FIFO for
boundary tests; TX backpressure is forced in simulation to stage injection.
[Whole-core tests](../tests/tb_packet.sv) run ECC and TMR register configurations,
validate every reply byte and exact rejection counters for echo, sum, immediate
duplicate, unknown opcode, bad CRC, oversized length, timeout and a maximum
32-byte payload. Additional cases inject a RAM codeword SEC/DED and a valid-ECC
but inconsistent ownership descriptor. The descriptor test models corruption
outside storage ECC's fault model; it is not proof against arbitrary software.

Serial test timing is accelerated/paced (128 clocks per bit plus 3000 idle clocks
between transmitted request bytes). This validates functional behavior, not
maximum sustainable baud rate, continuous-input service latency or buffer sizing.
No packet-specific formal proof, FPGA synthesis/resource/timing result, physical
UART test or radiation qualification is claimed. DMA, another stream source,
board integration, hardened serial engines and mission-specific packet policy
remain follow-on work.

Compilation retains existing core/RAM width and combinational scheduling warnings; passing simulation does not claim a warning-clean synthesis or timing signoff.
