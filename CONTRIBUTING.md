# Contributing to RISCue

Keep functional RTL in `rtl/`, simulation in `tests/`, formal properties in `formal/`, and platform adapters in `firmware/`. Put downloads and generated outputs in the ignored directories. Update lock files deliberately; never replace a pinned commit with a moving branch.

For behavior changes, update the affected strict requirements, the state protection inventory, and the proof/test contract. Every formal result must state reset, memory/bus assumptions, fault multiplicity and locations, and whether it is bounded or inductive. Preserve counterexamples and report timeouts as unresolved. A cover trace demonstrates reachability rather than correctness.

Choose verification targets for the affected implementation: current pipeline/AXI/monitor changes use the explicit targets in docs/RISCUE_MANUAL.md; `make test` and `make interfaces` retain legacy scope. Use the relevant `make formal-*` target when formal verification is requested. Review `docs/FORMAL.md` before running large proof jobs. All workflows are manual; there is no requirement to start a campaign merely to submit documentation or organizational changes.

Do not introduce stateful helpers without declaring their protection strategy. Keep FI_ENABLE disabled for production builds. Document common-mode logic and target-dependent physical assumptions. Avoid claims of radiation qualification based on RTL simulation/formal evidence alone.

`docs/requirements.json` is the editable source of truth. Run `python3 tools/write_requirements.py` to regenerate its CSV and Markdown views. Treat historical evidence as immutable provenance; add a new named campaign rather than changing old outcomes.

The current entry point is `docs/RISCUE_MANUAL.md`. Its code excerpts are selected by `docs/manual-excerpts.json`; run `make docs` after changing those sources and `make docs-check` before publishing documentation. Keep archived legacy descriptions clearly labeled.

Current-core functional changes require `make pipeline-variants-check`. Keep all five architecture/protection variants maintained together; see docs/UNPROTECTED.md.
