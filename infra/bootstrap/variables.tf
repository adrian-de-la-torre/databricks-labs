variable "location" {
  description = "Region for the identity resource group. Identities are global; this only places their metadata."
  type        = string
  default     = "northeurope"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form. Embedded in every federated credential subject."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be in owner/name form."
  }
}

variable "github_owner_id" {
  description = "Numeric GitHub account id. Part of the immutable subject format."
  type        = number
}

variable "github_repository_id" {
  description = "Numeric GitHub repository id. Part of the immutable subject format."
  type        = number
}

variable "environments" {
  description = "Deployment environments that get a federated apply credential."
  type        = set(string)
  default     = ["dev"]
}

variable "state_storage_account_id" {
  description = "Resource id of the storage account holding Terraform state."
  type        = string
}
