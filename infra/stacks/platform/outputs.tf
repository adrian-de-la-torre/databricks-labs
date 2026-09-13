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
