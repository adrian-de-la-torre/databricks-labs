variable "environment" {
  type        = string
  description = "Deployment environment. Part of the catalog name."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "workspace_url" {
  type        = string
  description = "Workspace URL, from the platform stack output."
}

variable "workspace_resource_id" {
  type        = string
  description = "ARM id of the workspace, used by the provider to authenticate through Azure."
}

variable "workspace_id" {
  type        = string
  description = "Numeric workspace id, used to bind the catalog to this workspace only."
}

variable "storage_credential_name" {
  type        = string
  description = "Storage credential registered by the account stack. Referenced by name."
}

variable "catalog_storage_url" {
  type        = string
  description = "abfss:// URL of the container backing managed tables."
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
