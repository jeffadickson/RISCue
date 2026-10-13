# Independent documentation review: five iterations

Two independent AI reviewer agents adopted embedded CPU/pipeline and embedded software/fault-protection review roles. They inspected documentation against RTL; these are agent reviews, not human sign-off, certification or completed formal proofs. Each round below follows revision of the preceding round. No RTL behavior was changed by this review.

## Round 1 — completeness and stale claims

Pipeline reviewer requested worked hazard/redirect traces, explicit absence of BTB/BHT/RAS, accepted-ID redirect semantics, WB-to-ID bypass, RF repair cadence and fatal-store caveat. Programmer reviewer requested full ISA/GPR/CSR tables, reset/mtval behavior, correction of obsolete no-interrupt claim, current packet inventory and reset/recovery semantics.

Disposition: added PROGRAMMER_REFERENCE.md with conventional instruction formats and complete mnemonic groups, ABI registers, CSR addresses/fields/resets, trap tables, pipeline event traces, no-predictor explanation and protection/repair/recovery boundaries. Corrected PROTECTION.md item 10; updated state inventory baseline and manual packet protection summary. Linked the new reference from manual and docs index. Source evidence: rtl/riscue_execute.sv, riscue_rvc.sv, riscue_pipeline_core.sv, riscue_pipeline_pkg.sv and packet guide.

## Round 2 — semantic precision

Both reviewers confirmed Round 1 substantive gaps resolved with no blocking factual errors. Pipeline reviewer requested the ALU event example allow an ordinary already-committed RF read, because unified fetch can prevent overlap, and bounded the fault claim to a stored-state model. Programmer reviewer identified that counters continue on non-reset halted/fatal clocks, requested C.LUI zero-immediate illegality and an opcode lookup.

Disposition: revised example and protection wording, corrected counter clock qualification, added C.LUI restriction and major opcode/decoder map. Evidence: pipeline unconditional next-state counter increments and ID operand capture, compressed decoder LUI zero check.

## Round 3 — cross-guide consistency

Pipeline reviewer confirmed counter/redirect/trap consistency and found misleading older wording suggesting execution selects one compared lane. Programmer reviewer found the FI guide could imply that a latched-fatal RAM accepts an overwrite, and that the pipeline guide's local address-map claim needed wrapper scope.

Disposition: clarified parallel execution/comparison, aligned stored-state-model wording, required controller recovery before overwrite of latched-fatal RAM, and scoped local SRAM access faults to the local reference SoC. Added README entry points for the programmer reference and review record. Evidence: pipeline dual lane instances and ft_ecc_ram fatal request gating; wrapper-specific address maps.

## Round 4 — integration and usability

Pipeline reviewer found no remaining technical discrepancy and requested definitions of retirement and CLINT. Programmer reviewer identified stale AXI board selection text and a packet-statistics edge case: timeout waiting for length is counted as length rejection.

Disposition: defined retirement including MEM store completion versus WB retirement; expanded CLINT; added contents navigation. Corrected AXI guide to current KC705 monitor versus KV260/legacy variants. Documented the packet length-byte timeout counter behavior exactly as firmware implements it, without changing RTL/C. Evidence: boards/kc705/monitor_top.sv, rtl/riscue_monitor_soc.sv and firmware/packet/main.c.

## Round 5 — final acceptance and boundaries

Both independent reviewers re-read the final revisions and accepted their respective documentation scopes with no remaining blocking discrepancy identified against the inspected source. Pipeline reviewer accepted hazards, accepted-ID JAL lookahead, EX conditional/JALR behavior, forwarding, killed-fetch drain, WB precise traps versus MEM side effects, and ECC/TMR repair/boundaries. Programmer reviewer accepted ISA/ABI/GPR/CSR/trap semantics, wrapper-specific memory/recovery interfaces and packet statistics.

Disposition: retained explicit pending-work boundaries and finalized navigation/review record. This final round did not manufacture additional behavior changes merely to count an iteration. The five cycles were sequential review, revision, then re-review; final acceptance is documentation review only.

## Verification and unresolved engineering work

- `make docs-check`: PASS, 27 source-synchronized excerpts and 88 manual links checked.
- Read-only audit across README and 24 current documentation files: PASS, 215 local paths/heading anchors checked before final record/changelog additions.
- No RTL or firmware changed by this documentation work; no simulation rerun is implied.
- Dynamic branch prediction/BTB/history/RAS is not implemented. Early direct jump resolution is implemented and distinctly documented.
- Exhaustive ISA/compressed-hint and privileged compliance, completed current-core formal proofs, post-route timing/resources, physical replica independence and radiation qualification remain pending.
- Serial engines remain unprotected; packet DMA and board integration remain pending. The public FI map exposes selected digital fault sites, not exhaustive physical coverage.

Reviewers are independent AI agents taking two engineering roles; they are not named human engineers, and their agreement is not third-party certification. Source-synchronized examples, explicit test evidence and future implementation/proof measurements remain the basis for stronger claims.
