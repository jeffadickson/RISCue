# RISCue — Open Work & Handoff (2026-10-20)

Branch **`pipeline-protection-variants`**. The last commit before this note ("Add Plain processor variant and required three-variant regression gate") was a completed step. The commit that adds this file is a **WIP checkpoint**: it preserves in-progress work from an earlier chat so it could move to another computer. It has **not** been confirmed against the required gates in this commit.

## What the WIP checkpoint contains

- **CORE_ARCH = MULTICYCLE** alongside PIPELINED, independent of protection. Five maintained variants: PIPELINED TMR / PARITY_REPLAY / PLAIN and MULTICYCLE TMR / PLAIN. MULTICYCLE rejects PARITY_REPLAY and uses stored-state FI ABI 4. See the AGENTS.md and CONTRIBUTING.md diffs in this commit.
- RTL: `rtl/riscue_pipeline_core.sv`, `riscue_pipeline_pkg.sv`, `riscue_pipeline_soc.sv`.
- New Makefile targets: `multicycle-test`, `architecture-compare`, `design-benchmarks`.
- New tests: `tests/tb_multicycle_faults.sv`, `tests/tb_architecture_compare.sv`, `tests/tb_design_benchmarks.sv`.
- New tools: `tools/check_multicycle.py`, `compare_architectures.py`, `run_design_benchmarks.py`, `simulation_build.py`. Updated config/selection/synth/variant-matrix tools.
- Benchmark firmware: `firmware/benchmarks/` (identical compiled C CRC/sort/integer kernels).
- Evidence (new, preserved as named results): `verification/architecture-comparison-local-2026-10-17.json`, `five-design-campaign-2026-10-17.json`, `branch-prediction-study-2026-10-19.json`.
- Docs updated: PIPELINE_PROTECTION, REQUIREMENTS (+ csv/json), RISCUE_MANUAL, STATE_MACHINE_AUDIT, UNPROTECTED.

## To finish (in order)

1. On the new machine, set up WSL Ubuntu-24.04 per `C:/dev/LOCAL-DEVELOPMENT.md`, then run `source /mnt/c/dev/Enter-RISCue.sh`. Copies of those files are in the handoff folder next to the bundles.
2. Run the gate: `make pipeline-variants-check` (all five variants: smoke/jump, selector rejection, protected replay, docs). Report any failure. Never skip a variant.
3. Run `make multicycle-test`, then `make design-benchmarks` (optionally `DESIGN_BENCH_ARGS=--synthesis`).
4. Regenerate the views from `docs/requirements.json`, then run `make docs docs-check`.
5. If everything passes, replace this WIP checkpoint with a proper commit message (or add a follow-up commit) describing the MULTICYCLE architecture. Then decide whether to push the branch. It has never been pushed, and pushing needs the user's go-ahead (AGENTS.md).

## Notes

- Clock-count simulations and mapped estimates don't establish achieved FPGA frequency (AGENTS.md).
- Don't edit this checkout from two chats at once.
