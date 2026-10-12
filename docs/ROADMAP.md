# RISCue roadmap

1. Close whole-core M and register-consistency proof timeouts with compositional invariants and solver tuning.
2. Complete ECC/TMR whole-core fault containment; retain reachability and explicit fault-model limits.
3. Broaden RAM proofs to arbitrary partial writes, scrub arbitration and realistic memory/bus consistency.
4. Add decoded-ISA completeness and equivalence checks for RVFI-enabled/disabled builds.
5. Add target synthesis/placement constraints and netlist fault injection before physical radiation claims.

The formal campaigns were stopped at the user's request after setup. Historical successful checks are useful development evidence, not complete processor signoff. Current details are in `verification/evidence/formal/RUN_STATUS.md`.

KC705 next steps: actual Vivado/board bring-up, placement-separated replica regions, configuration-memory scrubbing and a target-specific clock/reset fault model.
