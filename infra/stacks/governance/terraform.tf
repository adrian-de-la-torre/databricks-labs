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

# The WORKSPACE plane. account_id is deliberately absent: setting it here makes
# the provider reject its own configuration. Authentication resolves from the
# Azure identity -- the az CLI locally, the federated identity in CI.
provider "databricks" {
  host                        = var.workspace_url
  azure_workspace_resource_id = var.workspace_resource_id
}
