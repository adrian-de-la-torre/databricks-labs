# 1. One Terraform root per provider configuration

Status: accepted

## Context

A Terraform provider must be fully configured at plan time. The Databricks
provider needs a `host`, and that host is an attribute of the workspace —
`azurerm_databricks_workspace.this.workspace_url`. When the workspace lives in the
same state that configures the provider, the attribute is unknown during the plan
that would create it.

Azure Databricks also has two distinct API planes with incompatible provider
configurations. The workspace plane needs `azure_workspace_resource_id`; the
account plane needs `account_id` and `host = "https://accounts.azuredatabricks.net"`.
Setting `account_id` on a workspace-plane provider fails with
`invalid Databricks Account configuration`.

## Decision

One Terraform root per constructible provider configuration. There are exactly
three, so there are three planes plus bootstrap:

| Root | Provider |
|---|---|
| `infra/bootstrap` | `azurerm` |
| `infra/stacks/10-platform` | `azurerm` |
| `infra/stacks/20-account` | `databricks`, account plane |
| `infra/stacks/30-governance` | `databricks`, workspace plane |

## Consequences

The layer count is derived from the identity model rather than chosen. It does not
grow as the platform grows: adding regions, environments or workspaces adds
deployments of existing roots, not new roots.

The cost is ordering. A change spanning two planes is two applies, and the second
depends on the first having completed. This is real, and it is the price of the
provider constraint rather than a design preference.
