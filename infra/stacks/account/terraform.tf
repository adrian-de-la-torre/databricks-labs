terraform {
  required_version = "~> 1.16"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.131"
    }
  }

  backend "azurerm" {
    use_azuread_auth = true
  }
}

# The ACCOUNT plane, and the only provider in this root. account_id must never
# appear on a workspace-level provider: the two configurations are mutually
# exclusive, which is why this is a separate root rather than a second alias in
# the governance stack.
#
# The workspace-plane resources that only a human account admin can create (the
# storage credential, today) reach their workspace through
# provider_config { workspace_id } on this same provider. This root used to carry
# a second, workspace-scoped provider for them, and a provider block cannot be
# repeated per workspace: that alias tied the whole account plane to exactly one
# workspace. provider_config is a resource argument, so it takes for_each.
#
# account_id is not an argument here. It is an identifier, so it is resolved
# rather than committed (ADR-0005): from DATABRICKS_ACCOUNT_ID when that is set,
# otherwise from the CLI profile, which records it at `databricks auth login`.
provider "databricks" {
  host    = "https://accounts.azuredatabricks.net"
  profile = var.databricks_cli_profile
}
