output "platform_admins_group" {
  description = "Group name every governance grant targets."
  value       = databricks_group.platform_admins.display_name
}

output "storage_credential_name" {
  description = "Credential the governance stack references by name."
  value       = databricks_storage_credential.catalog.name
}
