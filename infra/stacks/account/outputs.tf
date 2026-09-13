output "platform_admins_group" {
  description = "Group name every governance grant targets."
  value       = databricks_group.platform_admins.display_name
}
