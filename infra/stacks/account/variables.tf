variable "databricks_cli_profile" {
  description = <<-EOT
    Databricks CLI profile holding account-level credentials.

    This stack is applied from a laptop, not from CI. Account admin is a
    Databricks role that Azure RBAC does not confer, and granting it requires
    already holding it -- so a human bootstraps it once. Moving this to CI needs
    an account-admin service principal, which is a later decision, not a
    limitation of this design.
  EOT
  type        = string
  default     = "account"
}

variable "admin_user_names" {
  description = <<-EOT
    Existing account users to place in the platform admin group.

    A user name is an email address, which is an identifier, so this is never
    set in envs/ (ADR-0005). Set TF_VAR_admin_user_names when planning, for
    example to '["<user name>"]'.
  EOT
  type        = set(string)
}

variable "ci_environments" {
  description = <<-EOT
    Environments whose CI apply identity joins the platform admin group. Each
    identity is bootstrap's apply identity for that environment, and its
    application id is read from the bootstrap state.

    An environment belongs here once its identity is registered in the
    Databricks account, which happens the first time it signs in to a
    workspace: until then the lookup in main.identity.tf finds nothing.
  EOT
  type        = set(string)
}

variable "deployments" {
  description = <<-EOT
    Every workspace the platform stack has deployed, as <environment>.<region>:
    the names of the platform env files, so the key here and the file names
    there are the same string. The environment half names the storage
    credential; the rest is read from that deployment's platform state.
  EOT
  type        = set(string)

  validation {
    condition     = alltrue([for key in var.deployments : can(regex("^(dev|test|prod)\\.[a-z]+$", key))])
    error_message = "deployments must be <environment>.<region>, for example dev.northeurope, matching the platform env files."
  }
}

variable "state_storage_account_name" {
  description = <<-EOT
    Storage account holding Terraform state, where the platform and bootstrap
    states are read.

    Derived from the subscription id, so it is resolved when the plan runs and
    never committed (ADR-0005): set TF_VAR_state_storage_account_name to the
    output of infra/bootstrap/state-store.sh --name.
  EOT
  type        = string

  validation {
    condition     = can(regex("^sttfstate[0-9a-f]{8}$", var.state_storage_account_name))
    error_message = "state_storage_account_name is sttfstate plus eight hex digits, as state-store.sh --name prints it."
  }
}
