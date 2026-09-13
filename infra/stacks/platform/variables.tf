variable "environment" {
  description = "Deployment environment. Part of every resource name."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = <<-EOT
    Azure region. Constrained to regions where Azure Databricks actually exists.

    Two facts worth knowing before changing this:
      - westeurope currently rejects new subscriptions (RequestDisallowedByAzure).
      - Spain Central does not offer Azure Databricks at all.
  EOT
  type        = string

  validation {
    condition = contains([
      "francecentral",
      "germanywestcentral",
      "northeurope",
      "swedencentral",
      "uksouth",
      "ukwest",
      "westeurope",
    ], var.location)
    error_message = "Azure Databricks is not available in that region."
  }
}

variable "address_space" {
  description = "CIDR for the workspace virtual network. /24 splits into two /25 subnets."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrsubnet(var.address_space, 1, 0))
    error_message = "address_space must be a valid CIDR block with room for two subnets."
  }
}
