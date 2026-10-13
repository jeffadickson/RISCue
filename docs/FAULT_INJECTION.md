# Pipeline fault-injection ABI 2

This is the full local-SoC/VIO campaign ABI. The default KC705 UART monitor exposes **RAM target 8 only**, using a byte address translated to the word index; it does not expose the RF, core, arithmetic or recorder targets. Generic AXI bridge/controller state has no public FI target. Telemetry aggregation depends on the wrapper: the UART monitor returns AXI RAM counters, while the local-SoC recorder combines core and RAM events.

Early direct-jump resolution changes no packed state fields or window offsets; this remains ABI 2. The added compared target lanes are combinational.

Masks are post-update XOR faults, applied after architectural writes and
repair on the injection edge. The controller, receiver and host reject empty,
out-of-width and out-of-range requests. FI_ENABLE defaults zero. ABI 2 is
reported in VIO configuration bits 15:8; WORDS is in 31:16, FI/RF_TMR in 1:0.
The legacy core has ABI 1 with a single 384-bit control record and no target 15;
its original documentation is preserved in LEGACY_FAULT_INJECTION.md.

| Target | Object | Index | Mask width |
| --- | --- | --- | --- |
| 1 | SECDED register | 0..31, ECC RF mode only | 39 |
| 2/3/4 | TMR register replicas 0/1/2 | 0..31, TMR RF mode only | 32 |
| 5/6/7 | Pipeline/platform record replicas c0/c1/c2 | 512-bit window index | 512, final window shortened |
| 8 | SRAM codeword | 0..WORDS-1 | 39 |
| 9/10/11 | SRAM control replicas | 0 | 35 |
| 12/13/14 | Diagnostic recorder replicas | 0 | 321 |
| 15 | Arithmetic state replica | 0/1/2 lane 0; 256/257/258 lane 1 | derived MD_BITS |

The canonical packed types are in rtl/riscue_pipeline_pkg.sv. Run
`python3 tools/write_injection_map.py` to regenerate injection-map.json with
exact bit ranges, slot subfields and final-window width. Bit 0 is the low bit
of the last declared field. A window mask bit b flips packed state bit
`512*index+b`. The map must accompany the exact bitstream revision: changing
packed field order/width changes positions and must update the map/version.
State windows cover pipeline buffers, CSRs, timer, counters, bus ownership,
interrupt sampling and retirement snapshots. Arithmetic records use their
separate target because their updates occur in independent modules.

Test memory correction by injecting one bit in a codeword, then observing
repair/reporting before applying a separate two-bit fault to the clean word.
Scrub traversal depends on foreground bus load; wait for repair rather than
assuming one word per clock. A two-bit read/partial-write error fail stops the
pipeline SRAM endpoint; a full-word overwrite can replace a bad codeword.
Three-or-more-bit ECC patterns can alias and are outside the SECDED guarantee.

Campaign sequencing and JTAG commands are in boards/kc705/lab/README.md.
The software detector log counts newly observed detector flags, not particles
or every consecutive cycle carrying the same flag. Architectural access
faults use the RAM bit-4 / combined bit-12 flag without counting as a hardware
uncorrectable/fatal event. UART and machine CSRs expose architectural traps.
