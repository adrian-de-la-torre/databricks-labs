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
