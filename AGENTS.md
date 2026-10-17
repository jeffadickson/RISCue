# Development instructions

- Read CONTRIBUTING.md and the current developer manual before changing RTL.
- Prefer local builds and simulations. Do not push or trigger remote CI unless the user requests it.
- Preserve uncommitted work; avoid simultaneous edits to one checkout from different chats.
- Pipeline protection and RF_TMR are independent. TMR is the default; PARITY_REPLAY requires explicit experimental opt-in and remains unqualified.
- Use `make pipeline-smoke pipeline-jump` for current-core smoke coverage. Use `make pipeline-selection-test` for selector changes and `make pipeline-replay-test` for recovery changes.
- Update canonical docs/requirements.json, regenerate its views, and run `make docs docs-check` after changing excerpted RTL.
- Store generated logs/tool downloads in ignored build/.tools paths. Preserve historical verification evidence; add new named results.
- On the configured Windows host, C:/dev is shared with Ubuntu-24.04 at /mnt/c/dev. Source /mnt/c/dev/Enter-RISCue.sh to select its Python environment; read C:/dev/LOCAL-DEVELOPMENT.md for machine-specific setup.
- Request confirmation for administrative system changes or restarts. Report unrun checks and tool failures precisely.
