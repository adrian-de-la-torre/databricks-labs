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
#
# Both values come from the platform stack's state (main.platform.tf). That is
# still a constructible configuration in the sense of ADR-0001: a data source in
# another state is read during the plan, whereas a resource attribute in this
# state would not be known until after the apply.
provider "databricks" {
  host                        = local.platform.workspace_url
  azure_workspace_resource_id = local.platform.workspace_resource_id
}
