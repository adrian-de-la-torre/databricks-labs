# Every Unity Catalog grant in the governance stack targets this group and never
# a person. Ownership and privileges survive someone changing role or leaving,
# and the duplicate-identity problem that Entra guest accounts create stops
# mattering: fix the membership once instead of every grant.
resource "databricks_group" "platform_admins" {
  display_name = "labs-platform-admins"
}

# Users are provisioned into the account by Entra; this reads them rather than
# creating them, so the identity provider stays the source of truth.
data "databricks_user" "admins" {
  for_each = var.admin_user_names

  user_name = each.value
}

# The CI apply identities are bootstrap's, and their application ids are read
# from its state rather than committed (ADR-0005). This stack can reach that
# state because the human who applies it created both; CI holds no role on the
# bootstrap container.
data "terraform_remote_state" "bootstrap" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = var.state_storage_account_name
    container_name       = "tfstate-bootstrap"
    key                  = "bootstrap/labs.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  # Keyed <environment>-apply, the keys this stack used while the ids were
  # committed, so no address moves.
  ci_application_ids = {
    for environment in var.ci_environments :
    "${environment}-apply" => data.terraform_remote_state.bootstrap.outputs.apply_client_ids[environment]
  }
}

# Databricks registers the service principal automatically when it creates a
# workspace, so this reads it rather than creating it. Same reasoning as for
# users: the identity is provisioned outside Terraform, and Terraform that
# insists on owning it only fights the source of truth.
data "databricks_service_principal" "ci" {
  for_each = local.ci_application_ids

  application_id = each.value
}

resource "databricks_group_member" "admin_users" {
  for_each = var.admin_user_names

  group_id  = databricks_group.platform_admins.id
  member_id = data.databricks_user.admins[each.value].id
}

resource "databricks_group_member" "ci" {
  for_each = local.ci_application_ids

  group_id  = databricks_group.platform_admins.id
  member_id = data.databricks_service_principal.ci[each.key].id
}

# Account-level groups exist but reach no workspace until assigned. Without this
# the group is real, the grants resolve, and nobody can use them.
resource "databricks_mws_permission_assignment" "platform_admins" {
  for_each = local.workspaces

  workspace_id = each.value.workspace_id
  principal_id = databricks_group.platform_admins.id
  permissions  = ["ADMIN"]
}

# The stack served a single workspace before the workspaces map existed. These
# addresses keep the original assignment instead of revoking and re-granting it.
moved {
  from = databricks_mws_permission_assignment.platform_admins
  to   = databricks_mws_permission_assignment.platform_admins["dev.swedencentral"]
}
