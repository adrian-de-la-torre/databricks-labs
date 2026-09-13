terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.5"
    }
  }

  # Partial configuration. The remaining keys live in envs/<env>.<region>.tfbackend
  # so that one copy of this code serves every deployment.
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}

  # azurerm 5.0 changed the default to "none" and removed skip_provider_registration.
  # Registering explicitly keeps the CI identity from needing subscription-wide
  # provider registration rights for namespaces this stack never uses.
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Databricks",
    "Microsoft.Network",
  ]
}
