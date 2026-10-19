# Reduced-complexity fault-tolerance hardening plan

Status: engineering design and acceptance criteria; **not an RTL implementation or verification result**.

## Architectural decision

Preserve `riscue_pipeline_core` as the flagship five-stage, in-order RV32 processor. Do **not** replace it with a triplicated-CPU implementation. The existing triple-replicated pipeline/platform records, optional ECC/TMR register-file modes, two compared execution lanes, protected arithmetic state, SECDED RAM and protected AXI bookkeeping remain the baseline.

The objective is measurable improvement in externally visible fault containment per LUT/FF/BRAM, not maximum replication. Full-core TMR may be an *independent, optional comparison experiment* later; it must not become a dependency of the reduced-complexity processor or its firmware.

## Platform boundary and configuration assumptions

Target deployments on supported Xilinx FPGAs are assumed to provide an independently managed configuration-memory scrub/SEM strategy. **RISCue will not implement configuration-frame scrubbing inside the processor RTL.** The board/mission integration is responsible for selecting and validating the appropriate device-specific SEM solution, upset detection/repair coverage, clock/reset behavior during scrub, uncorrectable configuration events and escalation policy. Configuration scrubbing does not protect transient datapath faults, BRAM payloads, user flip-flops, processor control, or voter/commit logic automatically. No radiation-qualification claim follows from this assumption.

## Baseline and proposed independent configurations

1. `lite`: baseline single pipeline with SECDED RAM; minimal additional logic (configuration target, not an assertion that a current build exactly realizes this boundary).
2. `protected`: **existing flagship**, triplicated architectural state, ECC or TMR RF, compared execution, protected arithmetic and AXI ownership.
3. `protected_checked`: protected plus independently checked voter and externally-visible commit controls, only once RTL and evidence close the gates below.
4. `full_core_tmr_reference`: optional **future experimental top**, not required to ship or validate the reduced-complexity CPU.

Keep existing public parameters/ports stable where practical. New switches must default to identical old behavior until independently validated and explicitly enabled.

## Priority A — voter integrity

Inventory every state voter and downstream fanout at pipeline, register file, arithmetic, AXI bridge, ECC RAM controller, debug and monitor endpoints. For each, distinguish: (a) majority masking a single stored replica upset, (b) common-mode voter upset, (c) combinational SET, (d) two matching replica faults. A duplicated checker derived from the **same optimized Boolean cone** is not independent evidence; use structural separation, synthesis preservation inspection and implementation/netlist fault injection. Never claim an always-healthy voter simply because single-replica bit-flip tests pass.

Acceptance: inject a logic error in the voter output or a replicated commit-decision path; the incorrect value is caught before any externally visible side effect, or the run is classified as an explicitly unprotected case. No silent-correction claim for two matching replicas.

## Priority B — external commit containment

Define the architectural side-effect boundary at RF/CSR retirement and **actual AXI handshake acceptance**, not just internal `write_rf` or `req`. Specify checks for address, write data, byte enables, operation type, target legality, trap/kill ordering and ownership, together with outstanding AW/W/B and AR/R channel states. Prevent an instruction from retiring as successful when a detected execution mismatch or integrity fatal has occurred. After an external write channel is accepted, fail-stop alone cannot undo the side effect; containment must precede acceptance. Distinguish current encoded local bus integrity from unencoded external AXI pins.

Acceptance: under one injected datapath/control fault at every chosen phase, there is neither an unexpected RF/CSR write nor an unexpected peripheral/memory write handshake. All observed errors are attributed and reproducible. Test partial AW-vs-W arrival and backpressure separately.

## Priority C — recovery discipline

Prefer local replica self-repair, then deterministic fail-stop when correct execution cannot be established. Two mismatching execution lanes detect but cannot identify the good value: never vote between two lanes. Do not implement speculative retry of non-idempotent stores. Any later resumable recovery needs a quiescence/drain/rollback contract across the actual external bus, validated with interrupts, debug and concurrent telemetry.

## Verification matrix

Every configuration must use the same compiled-C workload and independent architectural oracle, then run:
- baseline workload and retirement trace comparison;
- all three state replicas, at several active pipeline stages and nonzero architectural states;
- arithmetic result/ready/control mismatch before writeback;
- shared voter cone and next-state cone transient/output forcing;
- RF and CSR write authorization corruption;
- bus address, byte-enable, write-data and AW/W sequencing faults while stalled and while accepted;
- simultaneous detector events, fatal propagation, reset/boot/debug control;
- scrub starvation under sustained RAM traffic and recovery of damaged codewords.

Record per test: source SHA, configuration, seed, fault site, bit/force, cycle, architectural PC, expected detection/fatal/repair behavior, actual detection latency, committed side effects, and pass/fail. Assert that the injection *actually changed* the selected internal signal. Report uncovered sites, skipped tests, UNKNOWN and timeout distinctly; do not combine historical serialized-core results with current-pipeline evidence.

## Resource and implementation comparison

On one pinned Xilinx target, report post-synthesis and post-place/route LUT, FF, BRAM, DSP, Fmax, and CDC/replica-separation inspection for the same workload and clocks. Report fault outcome counts (masked / detected-fail-stop / silent corruption / inconclusive), detector latency and recovery cycles. A configuration with extra checkers must justify its incremental fabric against objectively improved coverage.

## Rollout gates

- G0: inventory exact voter/commit cones and establish reproducible baseline results.
- G1: design independent checker and prove single-replica repair parity; no extra false fatal.
- G2: instrument side-effect commit guard and verify external handshakes across backpressure/fault phases.
- G3: complete current-pipeline formal/ISA tests and integrated fault campaign.
- G4: implementation-level review and board tests; platform owner separately verifies Xilinx configuration scrub integration.

References: `docs/PROTECTION.md`, `docs/STATE_MACHINE_AUDIT.md`, `docs/VALIDATION.md`, `docs/AXI_ECC_MEMORY.md`, and AMD PG268 (MicroBlaze TMR). This plan is intentionally **not** a claim of functional parity, certification, or radiation qualification.

## AXI4-Lite Integrity Guard — detailed implementation work package (AXIG-001 through AXIG-012)

**Priority:** protection of the existing single AXI master, not three AXI masters. AMD PG268 motivates protocol-aware voter/comparator checks for triplicated AXI interfaces, but this design uses independent transaction-intent checks around the single-master boundary. It is *not* equivalent to an AMD TMR Voter, and protocol/ECC encoding of a wrong upstream address cannot make it correct.

### Proposed placement and contract

1. Inventory `riscue_pipeline_core` ECC-coded request generation, `riscue_axi_master_bridge`, `riscue_axi_core`, AXI interconnect boundary and `riscue_axi_ecc_ram` independently. Identify the earliest trustworthy source of instruction intent and a checker that does not simply recalculate from the same shared corrupted source.
2. Capture and protect an authorization descriptor (operation/read-write, byte address, size, WSTRB, WDATA or appropriately derived/checkable data, provenance/retirement order, destination window, transaction epoch). Check the descriptor against *actual output pins and ownership state* before releasing side-effecting AXI handshakes. Distinct lanes/protected registered information must be demonstrably independent; otherwise mark that fault class uncovered.
3. Model AW and W as **separately accepted channels**. Do not presume AXI transfers are atomic or that withdrawing VALID cancels an already accepted transfer. Choose and document an approach preventing unsafe half-issued writes—e.g., holding both AW/W while qualifying the descriptor and freezing payloads through acceptance; guarantee safe behavior for every accepted/unaccepted combination, including fault during backpressure. Reject authorization mismatches before first acceptance wherever possible. After partial acceptance, classify recovery as constrained, not automatically rollback-capable.
4. Check AR and R channels, response ownership and integrity, and B responses. Enforce stable payload/VALID while READY is low; detect unexpected, missing, duplicated or misattributed responses. A fail-stop must not present a mismatched read or failed write as successful architectural retirement.
5. Attribute faults with sticky detection, source identity and address/PC context; inhibit *new* requests, coordinate existing accepted transactions and fatal/drain policies with AXI and RAM controllers. No speculative replay of non-idempotent stores.
6. Prefer structurally independent voter/commit checkers with explicit synthesis hierarchy/keep review; test single-replica state faults separately from voter-output or shared combinational-cone faults. Independence is a testable property, not an assertion.
7. Keep configurable comparator diagnostics, mask behavior and injection lab-only by default; a masked field must never silently disable critical address/side-effect authorization checks.

### Required phase-aware verification

Test AW-before-W, W-before-AW, simultaneous AW/W, arbitrarily delayed READY/B/R, asserted VALID under backpressure, successful and error responses, bridge/core reset and fatal escalation. Inject into address, data, byte enables, read/write intent, AWVALID/WVALID/ARVALID, B/R response ownership, and checker/voter paths at pre-authorization, pre-first-handshake, between partial handshakes and post-acceptance phases. For each case, assert the injected signal was actually corrupted; compare the pin-level accepted transaction trace to an independent expected ledger. Categorize outcome as masked, detected/fail-stop, undetected externally visible corruption, or inconclusive; preserve evidence and source SHA.

**Acceptance gates:** (1) no unauthorized external memory/peripheral write is accepted for covered single-fault sites before acceptance; (2) no detected mismatch is reported as a successful retirement; (3) AXI channel stability/ownership holds under stalls and faults; (4) ECC/TMR mode and compiled-C baseline parity; (5) area/Fmax changes and noncovered common modes explicitly reported. The acceptance gate cannot claim universal elimination of shared-input/common-mode errors or cancellation of transactions accepted before detection.

**Xilinx configuration boundary:** FPGA configuration memory scrubbing is supplied and verified by the board/system integrator. It is intentionally not an in-core RTL feature. SEM does not replace this AXI guard, user-state correction or protection from transient illegal writes.

### Incremental prototype on `feature/axi-integrity-guard` (unverified)

The current experimental branch adds `CHECKED_VOTER=0` and `INTEGRITY_GUARD=0` parameters to `riscue_axi_master_bridge` and exposes them as `AXI_CHECKED_VOTER` / `AXI_INTEGRITY_GUARD` on `riscue_axi_core`. Defaults are disabled, existing port lists unchanged. The first checker compares the bitwise-voted state against a matching whole-record pair; **this check is mathematically redundant whenever a complete matching pair exists and does not create physical voter independence**. It must not be counted as additional proven fault coverage.

The second feature stores a separate ECC-encoded shadow descriptor of decoded address/data/control when a core request is accepted. During active AXI phases, decoded shadow fields are compared to the triplicated bridge's voted transaction, and bad ECC or mismatches inhibit AXI VALID and latch fail-stop. It is intended to detect certain after-capture corruptions, **not erroneous original address/transaction computation**. Its shared ECC decoder and control comparison are still common-mode vulnerabilities; the external pins, accepted partial AW/W writes, AXI recovery, and independent instruction intent checking are not closed. Do not credit this prototype as meeting AXIG-002 through AXIG-010.

Run `make test-axi-master-bridge` for the default and `make test-axi-integrity-guard` for the opt-in regression plus injected double-bit shadow descriptor corruption. These tests have been added but **were not executed during this change**. The design is isolated in a draft pull request pending tool-based validation and subsequent fault-coverage work.
