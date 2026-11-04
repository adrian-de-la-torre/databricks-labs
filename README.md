# databricks-labs

Reproducible Databricks experiments on Azure, and the platform that runs them.

Every laboratory here ships as a deployable Databricks bundle with its measurements
and its cost. The claim and the evidence live in the same directory, so anything
stated about performance can be re-run rather than taken on faith.

Built with AI-assisted development. Architecture decisions, experiment design and
interpretation of results are mine; the AI accelerated implementation and research.
The conventions that govern this repository are in [docs/CONVENTIONS.md](docs/CONVENTIONS.md).

## Layout

```
infra/
  bootstrap/              State store, CI identities, subscription budget
  stacks/platform/        Resource group, network, Databricks workspace
  stacks/account/         Databricks account plane: groups, storage credentials
  stacks/governance/      Databricks workspace plane: catalog, grants, policies
labs/
  <NN>-<topic>/           One experiment: bundle, results, cost
docs/
  CONVENTIONS.md          Rules this repository does not break
  adr/                    Why the non-obvious decisions were made
```

## How it is layered

One Terraform root per constructible provider configuration. Azure Databricks has
exactly three — `azurerm`, `databricks` scoped to a workspace, `databricks` scoped to
the account — and a provider whose `host` is an attribute of a resource in the same
state cannot be configured at plan time. The number of roots follows from that, not
from preference.

Terraform owns what outlives a laboratory. A bundle owns one laboratory. The boundary
is enforced by the tool rather than by policy: a bundle structurally cannot manage
storage credentials, grants, metastores, groups or budgets.

## Where things are applied

The platform is applied from CI through OpenID Connect, with no stored credentials.
Two steps genuinely cannot be, and are documented rather than disguised:

1. `infra/bootstrap/state-store.sh` runs once from a laptop. The storage account that
   holds Terraform state cannot hold its own state.
2. One human signs in to the Databricks account console once to become its first
   account admin. Granting account admin requires being one.

Per-laboratory infrastructure is applied locally and destroyed afterwards. Anything
with a standing hourly charge lives there and never in the platform, which is why the
platform costs approximately nothing at rest.

## Regions

Azure Databricks is available in `francecentral`, `germanywestcentral`, `northeurope`,
`swedencentral`, `uksouth`, `ukwest` and `westeurope`. Two facts worth knowing before
choosing: `westeurope` currently rejects new subscriptions with
`RequestDisallowedByAzure`, and Spain Central does not offer Azure Databricks at all.

## Getting started

```bash
az login
./infra/bootstrap/state-store.sh

# The state account's name derives from the subscription id, so it is passed
# rather than committed.
export TF_VAR_state_storage_account_name="$(./infra/bootstrap/state-store.sh --name)"

cd infra/stacks/platform
terraform init -backend-config=envs/dev.northeurope.tfbackend \
  -backend-config="storage_account_name=${TF_VAR_state_storage_account_name}"
terraform plan -var-file=envs/dev.northeurope.tfvars
```

The env files hold names, regions and address ranges, never identifiers
([ADR-0005](docs/adr/0005-identifiers-are-resolved-not-committed.md)). What a
plan needs beyond them:

| Stack | Beyond `az login` and the state account |
|---|---|
| `infra/stacks/platform` | Nothing |
| `infra/stacks/governance` | Nothing: the workspace comes from the platform state |
| `infra/stacks/account` | An account-level CLI profile (`-var=databricks_cli_profile=<profile>`), which carries the account id, or `DATABRICKS_ACCOUNT_ID`; and `TF_VAR_admin_user_names` |
| `infra/bootstrap` | `TF_VAR_github_owner_id` and `TF_VAR_github_repository_id`, from `gh api repos/<owner>/<name>` |

## Before the first commit

```bash
pre-commit install
git config user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
```

A commit publishes its author and committer along with its files. The gate refuses
an address that identifies someone
([ADR-0005](docs/adr/0005-identifiers-are-resolved-not-committed.md)), and GitHub's
noreply address is the one it accepts.

## Licence

Apache-2.0. Take what is useful.
