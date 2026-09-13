terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.5"
    }
  }

  # A separate container from the one CI writes to. The pipeline identities get
  # no role on this container, so a compromised pipeline cannot rewrite the
  # definitions of the identities themselves.
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.ManagedIdentity",
  ]
}
