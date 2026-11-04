# Every workspace the account plane serves, read from the platform stack's state
# of each deployment. Only the deployment names are committed: the numeric
# workspace id and the access connector's resource id are identifiers, and they
# are resolved when the plan runs (ADR-0005).
data "terraform_remote_state" "platform" {
  for_each = var.deployments

  backend = "azurerm"

  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = var.state_storage_account_name
    container_name       = "tfstate"
    key                  = "platform/${replace(each.key, ".", "/")}.tfstate"
    use_azuread_auth     = true
  }

  # A key with no state behind it reads as an empty set of outputs, which would
  # surface as an unsupported attribute in another file.
  lifecycle {
    postcondition {
      condition     = can(self.outputs.access_connector_id)
      error_message = "No platform state for ${each.key}: apply infra/stacks/platform for that deployment first."
    }
  }
}

locals {
  workspaces = {
    for key, state in data.terraform_remote_state.platform : key => {
      # A state written before the platform stack exported workspace_id carries
      # only the URL, which Azure builds as adb-<workspace id>.<n>.azuredatabricks.net.
      workspace_id        = try(state.outputs.workspace_id, regex("^https://adb-([0-9]+)\\.", state.outputs.workspace_url)[0])
      access_connector_id = state.outputs.access_connector_id
    }
  }
}
