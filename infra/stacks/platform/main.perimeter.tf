# Serverless compute reaches the catalog storage account from outside the
# virtual network, so the subnet rules in main.storage.tf never match it.
#
# Verified empirically rather than assumed: a serverless SQL warehouse reading a
# managed table in this catalog fails with "This Azure storage request is not
# authorized. The storage account's 'Firewalls and virtual networks' settings may
# be blocking access to storage services." Genie, Databricks Apps, serverless
# jobs and model serving all run on serverless compute, so without this file the
# catalog is readable only from classic clusters, which in turn need the NAT
# gateway.
#
# Allowlisting the serverless subnet ids on the storage account was the old
# answer and no longer works. Databricks now documents a network security
# perimeter with an inbound rule for the regional AzureDatabricksServerless
# service tag:
# https://learn.microsoft.com/azure/databricks/security/network/serverless-network-security/serverless-firewall-config
#
# Azure publishes no separate charge for a perimeter, so it can live in the
# platform, which is meant to cost approximately nothing at rest.
locals {
  # Service tags spell regions their own way, not as ARM location names, and the
  # two UK regions are not even a plain capitalisation of the location.
  service_tag_region = {
    francecentral      = "FranceCentral"
    germanywestcentral = "GermanyWestCentral"
    northeurope        = "NorthEurope"
    swedencentral      = "SwedenCentral"
    uksouth            = "UKSouth"
    ukwest             = "UKWest"
    westeurope         = "WestEurope"
  }[var.location]

  serverless_service_tag = "AzureDatabricksServerless.${local.service_tag_region}"
}

resource "azurerm_network_security_perimeter" "this" {
  name                = "nsp-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_network_security_perimeter_profile" "databricks" {
  name                          = "databricks"
  network_security_perimeter_id = azurerm_network_security_perimeter.this.id
}

# The regional tag, not the global one. The global tag admits serverless compute
# from every Azure Databricks region, which is wider than one workspace needs.
resource "azurerm_network_security_perimeter_access_rule" "serverless" {
  name                                  = "allow-databricks-serverless"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.databricks.id
  direction                             = "Inbound"
  service_tags                          = [local.serverless_service_tag]
}

# Learning is the API name for what the portal now calls transition mode:
# perimeter rules first, then the storage account's own firewall. Both halves
# are load-bearing. The subnet rules keep classic clusters working and the
# resource instance rule keeps Unity Catalog's access connector working; enforced
# mode would bypass both. Databricks recommends staying in transition mode for
# that reason, and keeping public network access on "Enabled from selected
# networks" rather than "Secured by Perimeter", which breaks external locations
# with "Request for user delegation key is not authorized".
resource "azurerm_network_security_perimeter_association" "catalog" {
  name                                  = "catalog-storage"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.databricks.id
  resource_id                           = azurerm_storage_account.catalog.id
  access_mode                           = "Learning"
}
