# Experimental pipeline protection variants

Status: experimental RTL and directed local simulation implemented. TMR remains
the default. Acceptance, exhaustive fault coverage, formal proof and mapped
area/timing are open. Historical evidence applies only to its original sources.

## Implemented development build

```sh
make pipeline-smoke pipeline-jump PIPELINE_PROTECTION=TMR
make pipeline-smoke pipeline-jump PIPELINE_PROTECTION=PARITY_REPLAY ALLOW_EXPERIMENTAL_PARITY=1
make pipeline-replay-test
```

`RF_TMR` remains independent. The common wrapper statically configures one shared
engine; it does not instantiate two CPUs or switch at runtime. Named Make choices
reject typos, and direct RTL rejects invalid numeric choices and missing opt-in.
`build/pipeline-config-<mode>.json` records the effective mode, FI version and core
source hash. Cocotb and directed debug runners use mode-specific build directories.
Vendor board release scripts explicitly accept TMR only until separate mapped
parity audits are available. Passing simulation is not approval for a parity bitstream.

### Storage and commit boundary

TMR retains complete voted/repaired records. PARITY_REPLAY stores `f/d/x/m/w`
payloads only in `c0`, with five parity bits covering **all** slot fields, including
invalid slots, valid/trap/control tags, PCs, instructions, operands and execution
results. `c1/c2` clear these payloads. Remaining state, including architectural PC,
CSRs, counters, outstanding bus ownership and committed RVFI record, is still
triplicated. This deliberately conservative first implementation does not yet
minimize the trusted-state footprint. Initial paired quick Series-7 mapping and scoped replica checks are recorded in [local toolchain evidence](../verification/local-toolchain-2026-10-16.json); full pruning/path audits and physical area remain open.

Parity is checked before stage fields are used. On mismatch the combinational
stage view is cleared, GPR/CSR commit and new issue are blocked, arithmetic is
cancelled, and uncommitted stages are squashed. RF protection and both compared
execution lanes are retained. Committed retirement observations are preserved;
replay never decrements committed order or restores old timer values.

### Recovery and side effects

The separate triplicated recovery record stores phase, a 32-bit attempt count,
and an unsafe-memory flag computed from the preceding validated next state.
Legal phases are RUN=00000, DRAIN=00111, RESTART=11001, DEAD=11110 (minimum distance
three). A single replica is repaired by voting. Complete-record majority loss or
any unused voted phase enters sticky fail-stop. The attempt budget defaults to
three over the lifetime since reset; it is not reset after each successful replay
and does not wrap. Reset reinitializes the budget and fatal state.

If a data transaction or memory instruction in MEM/WB may already have side
effects, a parity fault stops the core rather than replaying it. Thus this first
implementation is intentionally conservative around both RAM and MMIO. Safe
faults restart from protected `arch_pc`, retaining the committed RF/CSR boundary.
An outstanding instruction read keeps its captured request stable, drains its
response without decoding it, then inserts a restart bubble. A response accepted
on the detection edge is consumed once. The existing BUS_TIMEOUT bounds draining;
expiry latches fatal and drops the request on the next cycle. Timer counters
continue through recovery, so interrupt timing and cycle counts can differ.
Debug register handshakes and resume acknowledgment are held during recovery.

The existing event interface reports detected parity through disagreement and
integrity flag 6; timeout remains flag 5. The triplicated attempt count is internal
diagnostic state, not a new software CSR. Separate software-visible detected,
replayed and recovered counters remain an open PIPE-012 gate.

### Fault injection ABI

TMR retains ABI 2 offsets. Experimental PARITY_REPLAY is ABI 3: target 5 addresses
the primary state record, including its single stage payload; targets 6/7 address
trusted state only and reject masks touching removed stage copies. Record widths
and bit positions remain unchanged, but the meaning differs. Parity bits and the
new recovery record currently use hierarchical simulation injection only, not
public FI targets. ABI 2 campaigns must not be relabeled as parity results.

### Executed scope and remaining gates

The local iteration campaign exercises no-fault smoke/jump traces, both RF modes,
safe instruction/valid/WB-result faults, parity metadata, unsafe memory fail-stop,
delayed fetch drain, watchdog expiry, retry exhaustion, replica repair, majority
loss, and all 28 unused recovery codes. These are directed single-event tests;
they do not exhaust every stage bit, injection timing, persistent faults, debug
interaction or interrupt/split-fetch recovery. Arbitrary even-bit errors can
escape parity. Shared checker/voter/next-state/commit logic and clock/reset remain
common modes. No radiation, physical footprint, flight qualification or completed
formal proof is claimed. The requirements below remain acceptance obligations.

## Build selection and substitution

PIPE-005 and PIPE-006 require a common `riscue_pipeline_core` boundary and the
build-time selection `PIPELINE_PROTECTION=PARITY_REPLAY|TMR`. Instantiate one
implementation, reject unknown choices, record the effective mode in evidence,
and never switch modes at runtime or silently substitute a different mode.
`RF_TMR` remains an independent register-file choice. The intended area-oriented
default is PARITY_REPLAY after acceptance; retain today's TMR implementation and
defaults until those gates pass. The development commands above are experimental; acceptance remains open.

| Contract | PARITY_REPLAY | TMR |
| --- | --- | --- |
| Transient stage storage | Checked parity; detected faults squash/replay | Voted/repaired triplicated state |
| Architectural RF/memory | ECC or independently selected RF TMR | Same RF/memory contract |
| Commit/checkpoint/recovery authority | Small selectively protected trusted controller | Protected commit/control with existing TMR guarantees |
| Invalid FSM state | Safe recovery or contained fail-stop | Safe recovery or contained fail-stop |
| External interface | Common clock/reset, bus, debug, interrupt, halt, RVFI and event contract | Same contract |
| Latency | May include recovery stalls | May mask a replica upset without replay |

The bus payload encoding, request lifetime, backpressure, quiescence, boot,
retirement and debug semantics must allow substitution without mode-specific SoC
wiring. Compare architectural traces rather than demand cycle-identical behavior;
document counter, interrupt and timeout timing. Version FI layouts when stored
fields differ. Existing compared arithmetic remains required in both modes;
arithmetic recomputation is a separate future design decision (PIPE-013).

## Detection, commit and recovery contract

PIPE-007 through PIPE-010 require an inventory of every transient data/control
field, its integrity check and its response. Valid bits, kill/exception tags,
addresses and forwarding metadata need protection alongside operands and results.
Architectural PC/CSR/checkpoint state and transaction ownership cannot depend on
unchecked transient fields. Re-encoding a corrupt value is not validation.

All applicable checks must finish before a GPR/CSR write, retirement, store or
side-effecting MMIO request is authorized. A protected commit boundary advances
the validated architectural restart point atomically with effect bookkeeping.
Already accepted stores and side-effecting reads/writes must never be repeated
by replay. If completion is uncertain and exactly-once handling cannot be proven,
enter contained fail-stop instead of guessing or retrying the peripheral access.

On a recoverable transient fault: stop issue, squash uncommitted work, drain or
account for accepted bus traffic, reject stale responses with protected ownership
state, and restart from a coherent validated PC/GPR/CSR boundary. Define behavior
for interrupts, traps, debug/step, halt, split fetches and multicycle operations.
Do not roll back committed effects or externally advanced timers/devices.

Use selective TMR or an equivalently justified protected implementation for the
small trusted commit/recovery controller, checkpoint validity, error capture,
transaction ownership and retry/watchdog state. Document shared checker, voter,
next-state, clock/reset and configuration vulnerabilities. PIPE-012 requires
bounded retries/timeouts, sticky escalation, a defined reset/reinitialization path
and protected diagnostic events/counters.

## FSM encodings

PIPE-011 requires minimum pairwise Hamming distance **at least three** for legal
states of explicit FSMs across supported core, bus, debug and monitor variants,
including recovery states. Migrate existing binary/distance-two controllers; keep
existing distance-four encodings. Inventory counters and handshake flags separately
with their protection strategy. Every unused encoding must suppress new side effects
and enter a defined recovery or fail-stop path; returning blindly to idle is not
adequate for a controller that may own an accepted transaction. Preserve encoding
and safe-state behavior through synthesis and check the mapped result.

This is detection plus recovery, not a promise of automatic state correction.
Without a verified decoder, a one- or two-bit departure from a legal code routes
to recovery. Larger corruptions may alias another legal state. TMR correction and
Hamming-distance detection must be described separately.

## Acceptance and area evidence

PIPE-014 requires separate acceptance for pipeline mode x RF_TMR and supported
debug/redirect configurations: common-interface builds, ISA/architectural-trace
regressions, exhaustive single-bit transient-state faults, every unused FSM code
and single/double-bit state upset, persistent faults, faults during recovery,
side-effecting bus tests, no-corrupt/duplicate-commit and bounded-progress checks.
Record assumptions, injection sites, multiplicity and detection latency; arbitrary
even-bit pipeline errors can escape parity, and matching multi-replica corruption
can escape TMR. Existing results cannot be relabeled as this new matrix.

BUILD-004 requires mode-specific post-optimization protection audits and paired
area/sequential-cell/timing/recovery measurements on the same target and constraints.
Tiny Tapeout suitability remains unmeasured until synthesis and physical results
exist. RTL counts alone are not a footprint guarantee.

Canonical requirements: [requirements.json](requirements.json); generated
[traceability table](REQUIREMENTS.md). Current implementation:
[state inventory](STATE_MACHINE_AUDIT.md); limits: [protection](PROTECTION.md).
