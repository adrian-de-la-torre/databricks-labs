output "workspace_url" {
  description = "Workspace hostname. Consumed by the Databricks-plane stacks."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_resource_id" {
  description = "ARM resource id, used by the databricks provider to authenticate via Azure CLI or OIDC."
  value       = azurerm_databricks_workspace.this.id
}

output "resource_group_name" {
  description = "Resource group holding the workspace and its network."
  value       = azurerm_resource_group.this.name
}

output "catalog_storage_account_name" {
  description = "ADLS Gen2 account backing the Unity Catalog catalog. Consumed by the governance stack."
  value       = azurerm_storage_account.catalog.name
}

output "access_connector_id" {
  description = "Access connector whose managed identity Unity Catalog authenticates with."
  value       = azurerm_databricks_access_connector.this.id
}

output "catalog_storage_url" {
  description = "abfss:// URL of the container holding managed tables."
  value       = "abfss://${azurerm_storage_container.unity.name}@${azurerm_storage_account.catalog.name}.dfs.core.windows.net/"
}
