# Conventions

Rules this repository does not break. They exist because each one prevented a
specific problem, and the reason is written next to the rule.

## Language

Everything committed is in English: code, comments, variable names, documentation,
commit messages, issues. The audience is the global Databricks community.

## Layering

One Terraform root per **constructible provider configuration**. Azure Databricks has
exactly three — `azurerm`, `databricks` scoped to a workspace, `databricks` scoped to
the account — and a provider whose `host` is an attribute of a resource in the same
state cannot be configured at plan time. The layer count follows from the identity
model, not from taste.

| Stack | Owns | Providers |
|---|---|---|
| `infra/bootstrap` | State store, CI identities, subscription budget | `azurerm` |
| `infra/stacks/10-platform` | Everything with an ARM resource id | `azurerm` |
| `infra/stacks/20-account` | Databricks account plane | `databricks` (account) |
| `infra/stacks/30-governance` | Databricks workspace plane | `databricks` (workspace) |
| `labs/<NN>-<topic>` | One laboratory | none — Databricks bundle |

## Environments are files, not directories

A deployment is addressed by a pair: `envs/<environment>.<region>.tfvars` and
`envs/<environment>.<region>.tfbackend`. There is one copy of each stack's code,
forever. Adding an environment, a region or a subscription is a two-file change
whose entire diff is values.

Terraform CLI workspaces are not used: they share one backend, so they are not an
isolation boundary. Directory-per-environment is not used either: it guarantees
drift between copies that were meant to be identical.

The deeper reason is a Databricks one. A Unity Catalog metastore is one per region
and scoped to the account, so it spans dev, test and prod. Under a
directory-per-environment layout, whichever environment happened to own it would
become a hidden dependency of the other two.

## Naming

Azure CAF abbreviations, derived in `naming.tf` and nowhere else:
`<abbreviation>-<workload>-<environment>-<region>`, for example `rg-dbxlab-dev-neu`.

## Tags

Four keys on every resource that accepts them: `workload`, `environment`,
`managed_by`, `repository`. TFLint enforces the set by exact string comparison, so
the list in `.tflint.hcl` and the map in `naming.tf` must match character for character.

## File splitting

Root stacks split by concern (`main.network.tf`, `main.workspace.tf`), not into the
`main.tf` / `variables.tf` / `outputs.tf` triple. That triple describes a reusable
module; these are roots. `terraform_standard_module_structure` is disabled for this
reason, stated in `.tflint.hcl`.

## Terraform and bundles

Terraform owns what outlives a laboratory. A bundle owns one laboratory.

The boundary is enforced by the tool rather than by policy: a bundle structurally
cannot manage storage credentials, grants, metastores, network connectivity
configurations, groups, service principals, IP access lists or budgets. Note the
asymmetry — a bundle may declare an external location but not the storage credential
it depends on.

## Where things are applied

The platform is applied from CI. The two exceptions are stated rather than hidden:
`infra/bootstrap/state-store.sh` runs from a laptop because the storage account that
holds Terraform state cannot hold its own state, and one human must sign in to the
Databricks account console once to become its first account admin, because granting
account admin requires being one.

Per-laboratory ephemeral infrastructure is applied locally and destroyed after use.
Anything with a standing hourly charge — private endpoints, gateways, NAT — lives
there and never in the platform, so the platform costs approximately nothing at rest.

## Regions

Azure Databricks exists in `francecentral`, `germanywestcentral`, `northeurope`,
`swedencentral`, `uksouth`, `ukwest`, `westeurope`. Two facts that cost time to
discover: `westeurope` rejects new subscriptions with `RequestDisallowedByAzure`, and
Spain Central does not offer Azure Databricks at all. The list is enforced by a
variable validation block.

## Changing infrastructure that already exists

Use `moved` and `removed` blocks, never `terraform state mv` or `terraform state rm`.
Declarative refactors are reviewable in a pull request and reproducible in CI; an
imperative state command lives only in the terminal of whoever ran it.
