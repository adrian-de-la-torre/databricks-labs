# The workspace this deployment governs, read from the platform stack's state
# instead of copied into envs/*.tfvars. A copied value is an identifier in a
# public repository and a second source of truth that drifts from the first;
# a remote state read is neither (ADR-0005).
#
# The key is the one in the platform stack's envs/<environment>.<location>.tfbackend,
# which is why this stack takes location although nothing in it is regional.
data "terraform_remote_state" "platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = var.state_storage_account_name
    container_name       = "tfstate"
    key                  = "platform/${var.environment}/${var.location}.tfstate"
    use_azuread_auth     = true
  }

  # A key with no state behind it reads as an empty set of outputs, which would
  # surface as an unsupported attribute three files away.
  lifecycle {
    postcondition {
      condition     = can(self.outputs.workspace_url)
      error_message = "No platform state for ${var.environment}.${var.location}: apply infra/stacks/platform for that deployment first."
    }
  }
}

locals {
  platform = data.terraform_remote_state.platform.outputs

  # A state written before the platform stack exported workspace_id carries only
  # the URL, and Azure builds that URL as adb-<workspace id>.<n>.azuredatabricks.net.
  workspace_id = try(local.platform.workspace_id, regex("^https://adb-([0-9]+)\\.", local.platform.workspace_url)[0])
}
