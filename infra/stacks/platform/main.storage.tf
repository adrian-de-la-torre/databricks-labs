data "azurerm_subscription" "current" {}

# Catalog data lives here, NOT in the storage account Databricks creates inside
# its managed resource group. That account is owned by the workspace: destroy the
# workspace and the data goes with it. This one is ours, in our resource group,
# under our Terraform, and it survives a workspace being rebuilt.
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

  # Deny by default, and name the two things that are allowed through.
  #
  # The subnets get in by id, through the Microsoft.Storage service endpoint
  # declared on each of them: cluster nodes have no public address, so there is
  # no IP for an ip_rules entry to match.
  #
  # The access connector gets in as a resource instance. Unity Catalog reaches
  # this account from the control plane, outside the virtual network, so the
  # subnet rules do not cover it.
  #
  # bypass is None on purpose. Enabling the trusted Azure services exception
  # would admit every access connector in the tenant, which is wider than this
  # account needs and wider than the resource instance rule below, so Databricks
  # documents turning it off:
  # https://learn.microsoft.com/azure/databricks/connect/unity-catalog/cloud-storage/azure-managed-identities
  #
  # That choice trips AZU-0010, which asks for the bypass this account is
  # deliberately not granting. The check is generic and the guidance here is the
  # storage provider's own, so the check loses. No expiry: this is a decision,
  # not debt waiting for a better moment.
  #trivy:ignore:AZU-0010
  network_rules {
    default_action             = "Deny"
    bypass                     = ["None"]
    virtual_network_subnet_ids = [azurerm_subnet.host.id, azurerm_subnet.container.id]

    private_link_access {
      endpoint_resource_id = azurerm_databricks_access_connector.this.id
    }
  }

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
