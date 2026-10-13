# AXI4-Lite ECC RAM endpoint

`riscue_axi_ecc_ram` is a 32-bit AXI4-Lite slave backed by the existing 39/32
SECDED reference RAM. It can connect directly to `riscue_axi_core` or through
an AXI interconnect. WORDS, BASE_ADDRESS and a raw-word INIT_FILE define the
RAM window. Both endpoints share a clock in the reference tests. AXI4-Lite
has no bursts or IDs. This is a RAM endpoint, not a DDR PHY/controller.
Vivado BRAM inference, physical implementation and board integration remain
unvalidated; the reference RTL array must not be assumed to infer block RAM.

Address and write-data channels are captured independently. Either can arrive
first. A partially accepted write reserves arbitration until its other channel
arrives; completed writes win over reads. One transaction is serviced at a
time. Registered read data/responses and write responses remain stable while
backpressured. Unaligned/out-of-window requests return DECERR before accessing
RAM. WSTRB=0 is an OKAY no-op. Other byte masks use the RAM's atomic checked
read-modify-write. PROT attributes are accepted but not an access-control policy.

All storage words have SECDED. Single-bit errors, including parity bits, are
corrected on read and rewritten. Background scrubbing is configurable through
scrub_enable. Foreground requests take priority. Partial writes decode/correct
the old word, merge bytes and write a complete new ECC codeword. An
uncorrectable old word prevents a partial write and returns SLVERR. Reads of
uncorrectable words return SLVERR with zero data and latch memory fail-stop.
A scrub-detected double error also latches fail-stop. Subsequent storage
accesses return SLVERR until memory-control recovery.

To recover, stop CPU/other masters, drain all channels/responses, pause scrub,
pulse memory_reset, then overwrite the damaged word with a full-word write.
Control reset preserves storage and diagnostic counters. Resume scrub only
after repair. memory_reset blocks new acceptance and is rejected as a fatal
control misuse when requests/responses are already owned. Resetting an
outstanding AXI domain is not an AXI cancellation mechanism; coordinate
interconnect/master reset for any fatal loss of controller-state integrity.
A full-word overwrite does not need the corrupted old data once fail-stop has
been cleared. Normal aresetn resets protocol/telemetry state, not stored words.

The endpoint's transaction and telemetry state is triplicated with voting and
repair. The RAM's existing controller state is also triplicated. Loss of a complete-state majority now fails stopped before storage access. Exposed
outputs include event_valid, corrected/disagreement events, fatal,
corrected/uncorrectable/disagreement/fatal counts, last_error_address and a
six-bit Hamming syndrome. Counts wrap at 32 bits. Syndrome zero can identify an
overall-parity single-bit correction; it is not alone a severity code. Fault
injection is disabled by default and validates masks/indices: target 8 flips
up to 39 storage bits in a selected word; targets 9..11 flip one 35-bit RAM
control replica with index zero. New AXI-controller state has no FI target;
its TMR repair can be tested by simulation deposition.

The existing RAM now rejects loss of a complete control-state majority and exposes its syndrome without changing codeword format or
FI ABI. Foreground fatal records now retain the faulting address, rather than
overwriting it with the scrub cursor address. Storage ECC does not protect
AXI addresses or payloads against corruption in transport. System integration
must monitor the fatal/event outputs and implement its recovery policy; the
master wrapper has an optional external_memory_fault input enabled with
MEMORY_FAULT_INPUT=1. The integration fixture connects it to the RAM fatal
output, stopping the hart while the AXI master drains captured ownership.
The input is disabled by default for compatibility with standalone masters.

## Tests and reproduction

`make test-axi-ecc-ram` checks AW-before-W and W-before-AW, held B/R responses,
byte/no-op writes, all 39 single-bit storage errors, on-read repair, idle
scrubbing, invalid addresses, DED read/partial-write containment, syndrome/
address/counters and reset/full-word recovery. Legacy RAM and 9,360 ECC fault
injection checks are rerun after the diagnostic change.

`make test-axi-ecc-c` rebuilds the existing small C example, larger workload and
32-tap FIR, then runs each in ECC and TMR register modes through the actual
CPU -> AXI master -> AXI slave -> ECC RAM path. It checks results against the
same independent references. Larger-workload mcycle phase timing and interrupt
resume PCs are deliberately excluded from fixed golden words because bus
latency changes them; the timer interrupt cause/count and algorithm results
remain checked. The runner uses two workers, per-run logs and explicit timeout.
A suitable Icarus/GCC/binutils toolchain must be on PATH.

Published results are in verification/axi-ecc-memory-results.json. These are
directed RTL tests, not formal AXI compliance, external DDR validation, physical
BRAM/resource/timing closure or radiation qualification.

## CPU-through-AXI results

| Program | ECC cycles / retirements | TMR cycles / retirements | Interrupts per run |
| --- | ---: | ---: | ---: |
| smoke | 3237 / 269 | 3237 / 269 | 0 |
| workload | 40432 / 3340 | 40432 / 3340 | 1 |
| fir | 33954 / 2853 | 33954 / 2853 | 0 |
