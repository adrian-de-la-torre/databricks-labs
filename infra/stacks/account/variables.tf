variable "databricks_account_id" {
  description = "Databricks account id, from the account console. An identifier, not a credential."
  type        = string
}

variable "databricks_cli_profile" {
  description = <<-EOT
    Databricks CLI profile holding account-level OAuth credentials.

    This stack is applied from a laptop, not from CI. Account admin is a
    Databricks role that Azure RBAC does not confer, and granting it requires
    already holding it -- so a human bootstraps it once. Moving this to CI needs
    an account-admin service principal, which is a later decision, not a
    limitation of this design.
  EOT
  type        = string
  default     = "account"
}

variable "workspace_id" {
  description = "Numeric id of the workspace the admin group is assigned to."
  type        = string
}

variable "admin_user_names" {
  description = "Existing account users to place in the platform admin group."
  type        = set(string)
}

variable "ci_application_ids" {
  description = "Entra application ids of the CI identities that need account-level presence."
  type        = map(string)
}
