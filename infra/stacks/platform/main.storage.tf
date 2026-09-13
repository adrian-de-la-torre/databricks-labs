data "azurerm_subscription" "current" {}

# Catalog data lives here, NOT in the storage account Databricks creates inside
# its managed resource group. That account is owned by the workspace: destroy the
# workspace and the data goes with it. This one is ours, in our resource group,
# under our Terraform, and it survives a workspace being rebuilt.
#
# AZU-0012 is open, not dismissed: this account has no network rules, so its
# default action allows access from any network. Closing it is a two-part change
# and both parts have to land together, or the clusters lose the catalog:
#
#   1. service_endpoints = ["Microsoft.Storage"] on snet-host and snet-container
#      in main.network.tf. Neither subnet has any service endpoint today.
#   2. network_rules on this account with default_action = "Deny",
#      bypass = ["AzureServices"] for the access connector, and both subnet ids.
#
# It is suppressed rather than fixed because it cannot be verified right now:
# enable_nat_gateway is false in dev, so no cluster starts, so nothing can prove
# the workspace still reaches the catalog after the account is closed. Turn the
# NAT gateway on, make both changes, start a cluster, read a managed table.
# shared_access_key_enabled is already false, so the key path is shut regardless.
#
#trivy:ignore:AZU-0012 exp:2026-10-15
resource "azurerm_storage_account" "catalog" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # ADLS Gen2. Unity Catalog external locations require hierarchical namespace.
  is_hns_enabled = true

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Unity Catalog authenticates through the access connector's managed identity.
  # No shared key is ever needed, so leaving them enabled would only widen the
  # blast radius of a leaked key that nothing uses.
  shared_access_key_enabled = false

  tags = local.tags

  # This account holds catalog data. Destroying it is never recoverable from
  # Terraform, and the point of this whole stack is that the data outlives the
  # workspace. Removing this block has to be a deliberate, reviewable act.

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "unity" {
  name               = "unity"
  storage_account_id = azurerm_storage_account.catalog.id

  # Deleting a container deletes every blob inside it, which is every managed
  # table in the catalog. Same protection as the account that holds it.
  lifecycle {
    prevent_destroy = true
  }
}

# Our own access connector, for the same reason as the storage account: the one
# Databricks provisions lives in the managed resource group and shares the
# workspace's lifetime.
resource "azurerm_databricks_access_connector" "this" {
  name                = "dbac-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags

  # The storage credential in Unity Catalog references this connector by id.
  # Replacing it silently breaks every external location that trusts it.
  lifecycle {
    prevent_destroy = true
  }
}

# The single role assignment the CI identity is permitted to create: the ABAC
# condition on its Role Based Access Control Administrator grant allows exactly
# this role definition and nothing else.
resource "azurerm_role_assignment" "connector_on_catalog_storage" {
  scope                = azurerm_storage_account.catalog.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# Unity Catalog refuses to register a storage credential unless the access
# connector's managed identity can read the connector itself. The error names the
# connector, not the missing role, which makes it hard to place: it reads as a
# permissions problem with the credential rather than a self-referential Reader
# assignment that nobody would think to create.
resource "azurerm_role_assignment" "connector_reader_on_itself" {
  scope                = azurerm_databricks_access_connector.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
