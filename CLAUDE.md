# CLAUDE.md

The rules that govern this repository are in [docs/CONVENTIONS.md](docs/CONVENTIONS.md).
They apply to everyone, human or otherwise. Read them before changing anything.

Two that are violated most often:

- Everything committed is in English.
- Root stacks split by concern, not into `main.tf` / `variables.tf` / `outputs.tf`.

# Compact instructions

When compacting, keep the things that cost money or credibility to recover:

- Measured numbers, with the compute they were measured on: DBR version,
  `node_type_id`, warm or cold, and the run count behind them.
- Exact error strings from providers, Spark and the CLI. A paraphrased error is
  no longer searchable.
- Every destroy and replace a plan reported, by address.
- Versions already established: provider, DBR, CLI, and any pinned SHA.
- Decisions and the reason next to them, which is what the ADRs are built from.
- What was checked and found false, so it is not investigated twice.

Drop file listings, directory walks, and tool output that has already been
acted on.
