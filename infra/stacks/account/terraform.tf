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

# The ACCOUNT plane. account_id must never appear on a workspace-level provider:
# the two configurations are mutually exclusive, which is why this is a separate
# root rather than a second alias in the governance stack.
provider "databricks" {
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  profile    = var.databricks_cli_profile
}

# Workspace plane, same human account admin. A storage credential is a
# workspace-plane resource that nevertheless requires Databricks account admin to
# register: a service principal holding CREATE_STORAGE_CREDENTIAL on the metastore
# is still refused. It therefore belongs with the other things only a human
# account admin can do, rather than in the CI-applied governance stack.
#
# This does not violate the one-root-per-provider-configuration rule. The
# constraint is that a provider cannot be configured from an unknown attribute;
# workspace_url is a variable, so both configurations are constructible here.
provider "databricks" {
  alias                       = "workspace"
  host                        = var.workspace_url
  azure_workspace_resource_id = var.workspace_resource_id
}
