output "platform_admins_group" {
  description = "Group name every governance grant targets."
  value       = databricks_group.platform_admins.display_name
}

output "storage_credential_names" {
  description = "Credential each governance deployment references by name, keyed like var.deployments."
  value       = { for key, credential in databricks_storage_credential.catalog : key => credential.name }
}
