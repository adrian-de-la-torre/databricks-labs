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

# The two numeric ids change when the repository is recreated, and they are
# identifiers, so neither is committed (ADR-0005). Resolve both when planning:
#   export TF_VAR_github_owner_id="$(gh api repos/<owner>/<name> --jq .owner.id)"
#   export TF_VAR_github_repository_id="$(gh api repos/<owner>/<name> --jq .id)"
variable "github_owner_id" {
  description = "Numeric GitHub account id. Part of the immutable subject format. Set with TF_VAR_github_owner_id."
  type        = number
}

variable "github_repository_id" {
  description = "Numeric GitHub repository id. Part of the immutable subject format. Set with TF_VAR_github_repository_id."
  type        = number
}

variable "environments" {
  description = "Deployment environments that get a federated apply credential."
  type        = set(string)
  default     = ["dev"]
}
