variable "environment" {
  type        = string
  description = "Deployment environment. Part of the catalog name."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type        = string
  description = "Region of the deployment: the second half of its envs/<environment>.<location> name. Locates the platform state this stack reads."

  validation {
    condition     = can(regex("^[a-z]+$", var.location))
    error_message = "location is an Azure region name, for example northeurope."
  }
}

variable "state_storage_account_name" {
  type        = string
  description = <<-EOT
    Storage account holding Terraform state, where the platform state is read.

    Derived from the subscription id, so it is resolved when the plan runs and
    never committed (ADR-0005): set TF_VAR_state_storage_account_name to the
    output of infra/bootstrap/state-store.sh --name.
  EOT

  validation {
    condition     = can(regex("^sttfstate[0-9a-f]{8}$", var.state_storage_account_name))
    error_message = "state_storage_account_name is sttfstate plus eight hex digits, as state-store.sh --name prints it."
  }
}

variable "storage_credential_name" {
  type        = string
  description = "Storage credential registered by the account stack. Referenced by name."
}

variable "admin_group" {
  type        = string
  description = "Account-level group that owns every securable here. Never an individual."
}

variable "max_workers" {
  type        = number
  description = "Hard ceiling on cluster size. A limit, not a default."
  default     = 4
}

variable "autotermination_minutes" {
  type        = number
  description = "Fixed idle timeout. Users cannot raise or disable it."
  default     = 20

  validation {
    condition     = var.autotermination_minutes >= 10 && var.autotermination_minutes <= 60
    error_message = "autotermination_minutes must be between 10 and 60: below 10 Databricks rejects it, above 60 it stops being a cost control."
  }
}

variable "catalog_users" {
  type = object({
    service_principals = optional(set(string), [])
    apps               = optional(set(string), [])
  })
  description = <<-EOT
    Principals outside this stack that need USE_CATALOG on the catalog, by name:
    service principals by display name, Databricks Apps by app name. Each name
    is resolved to an application id when the plan runs, so no id is committed.
  EOT
  default     = {}
}
