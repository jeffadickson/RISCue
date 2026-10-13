# Generic AXI processor wrapper

`rtl/riscue_axi_core.sv` wraps the five-stage processor with a 32-bit AXI4-Lite
master interface. It issues instruction fetches and data loads/stores to an
external AXI interconnect. `riscue_axi_master_bridge.sv` converts the internal
SECDED-coded request/response interface. The existing KV260 AXI4-Lite slave
remains the ARM-side loader/control interface around local ECC SRAM; it is a
separate interface with a separate purpose.

The generic wrapper has one shared clock/reset domain, a 32-bit address and
data bus, WSTRB byte enables, independent AW/W handshakes, AR/R and B response
channels, and one outstanding transaction. There are no bursts, transaction
IDs, caches, exclusives or coherency. AXI4-Lite can connect through an
appropriate interconnect/protocol converter to AXI4 memory/peripherals.
Vivado clock/reset/M_AXI interface attributes are provided; synthesis, IP
packaging, board routing and timing have not been validated.

The bridge latches the decoded request before asserting VALID. Address/data
remain stable under backpressure; AW and W can complete in either order.
Reads use aligned word addresses and writes use aligned addresses plus the
core's shifted data/WSTRB. The bridge waits for the response, pulses core
completion once, then waits for req to drop before accepting another request.
Any non-OKAY response is an access error; the core supplies the precise fetch,
load or store trap and mtval. Malformed internal controls are rejected before
bus issue. RESET_PC and BUS_TIMEOUT remain configurable core parameters.
CLINT registers remain internal to the core at their published addresses.
ARPROT/AWPROT are privileged secure (001); the unified internal bus does not
supply a fetch/data discriminator, so ARPROT's instruction hint is zero.

All captured bridge state is triplicated (116 bits per replica) with voting
and repair. FSM encodings have Hamming distance two. ECC errors in incoming
address/control/write-data are corrected or fail stopped; read request data
is irrelevant. Bridge correction/disagreement/fatal signals and the core's
event outputs are exposed for system telemetry. Core FI ports retain their
existing core meaning; no bridge FI target is added. The bridge single-upset
test deposits a bit directly into one replica in simulation.

Ordinary AXI4-Lite carries no SECDED code bits. The bridge encodes returned
AXI data for the internal core bus, but cannot detect corruption that already
occurred in external RAM or on the AXI payload. External memories must provide
their own ECC and error reporting; end-to-end bus-data integrity needs an
additional system design. This wrapper does not replace the existing local
ECC SRAM's protection with an equivalent external-memory guarantee.

If the core drops req after a fatal/timeout, an already captured transaction
still drains: VALID cannot be withdrawn to cancel AXI ownership. A write
accepted externally cannot be rolled back. A slave that never responds leaves
the bridge owned until system reset. Fatal loss of bridge-state majority
isolates its channels and requires coordinated reset/isolation of the AXI
domain; protocol continuity is not guaranteed under that uncorrectable fault.
Reset must be coordinated with the attached interconnect/slaves, especially
when a transaction is outstanding. CDC requires an external AXI clock converter.

## Executed tests

`make test-axi-core-errors` runs the actual processor with delayed responses,
independent/asymmetric AW/W acceptance and address/data stability checks, in
ECC and TMR register modes. The program performs multiply, word store/load,
forwarded arithmetic, byte store/load, then an unmapped load (SLVERR) or store
(DECERR). It checks mcause/mtval, data results and suppression of a younger
store. `make test-axi-master-bridge` checks held-request suppression,
requester-drop draining, W-before-AW, DECERR reporting, single-replica repair,
SECDED correction and double-error fail stop. See AXI master results JSON.

These directed tests and sv2v conversion are not full AXI compliance/formal,
physical synthesis or radiation qualification. The current KC705 serial-monitor target selects the generic AXI master and ECC RAM endpoint. The KV260 target retains its distinct ARM-facing AXI slave/local RAM architecture; the legacy KC705 VIO target also remains distinct. Validate the selected top, address map, clock/reset and memory protection before board use.

The optional `MEMORY_FAULT_INPUT=1` parameter enables `external_memory_fault` as a fatal input. Connect an ECC RAM endpoint’s `fatal` signal here to stop the hart on an uncorrectable storage fault; the default is disabled for compatibility. AXI response errors still produce architectural access-fault traps. See [AXI ECC memory](AXI_ECC_MEMORY.md) for recovery and test coverage.

`MONITOR_CONTROL=1` enables `halt_request` and the runtime `boot_pc` reset address. `quiescent` reports an empty pipeline/bus with no partial split fetch; `bridge_idle` separately reports drained AXI ownership. A monitor must wait for both plus the slave's idle indication before handing off memory. Stopping does not freeze timers or scrubbing. With `MONITOR_CONTROL=0` (default), the optional inputs have no effect and `RESET_PC` remains the reset address.
