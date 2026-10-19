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
