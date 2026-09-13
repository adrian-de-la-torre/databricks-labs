data "azurerm_subscription" "current" {}

# Least privilege, stated explicitly rather than reached for by habit.
#
# Contributor at subscription scope is genuinely required for apply, not lazily:
# creating azurerm_databricks_workspace makes the Databricks resource provider
# create its managed resource group at subscription scope.
#
# Owner is never used. The one thing Owner is normally reached for -- creating the
# access connector's role assignment on storage -- is served by Role Based Access
# Control Administrator constrained to a single assignable role.
resource "azurerm_role_assignment" "apply_contributor" {
  for_each = var.environments

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# Control-plane rights do not confer data-plane access, and the state account has
# shared keys disabled. Without these two assignments Terraform cannot read or
# write its own state, which is the failure that reads as a mysterious 403.
resource "azurerm_role_assignment" "apply_state_writer" {
  for_each = var.environments

  # Container scope, not account scope. The bootstrap state lives in a different
  # container, so a compromised pipeline identity cannot reach the definitions of
  # the identities themselves -- including its own.
  scope                = "${var.state_storage_account_id}/blobServices/default/containers/tfstate"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

# Reader, not Contributor. A plan needs to read state; it must not be able to
# overwrite it. `terraform plan -lock=false` is therefore mandatory in CI, and the
# workflow says so.
resource "azurerm_role_assignment" "plan_state_reader" {
  scope                = "${var.state_storage_account_id}/blobServices/default/containers/tfstate"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# Contributor cannot create role assignments, and Unity Catalog needs one: the
# access connector's managed identity must hold Storage Blob Data Contributor on
# the catalog's storage account.
#
# The usual shortcut is to grant the pipeline Owner. This grants Role Based Access
# Control Administrator instead, with an ABAC condition that constrains it to
# assigning exactly one role definition. The pipeline can therefore create the one
# assignment Unity Catalog requires and cannot grant itself anything else --
# notably not Owner, and not Contributor to a new principal.
resource "azurerm_role_assignment" "apply_constrained_rbac_admin" {
  for_each = var.environments

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
  principal_type       = "ServicePrincipal"

  condition_version = "2.0"
  condition         = <<-CONDITION
    (
      (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      )
      OR
      (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals{${join(", ", local.assignable_role_ids)}}
      )
    )
    AND
    (
      (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      )
      OR
      (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals{${join(", ", local.assignable_role_ids)}}
      )
    )
  CONDITION
}
