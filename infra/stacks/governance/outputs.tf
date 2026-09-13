output "catalog_name" {
  description = "Catalog laboratories write into."
  value       = databricks_catalog.this.name
}

output "cluster_policy_id" {
  description = "Policy every laboratory cluster must use. Referenced from each bundle."
  value       = databricks_cluster_policy.laboratory.id
}

output "metastore_id" {
  description = "Regional metastore this workspace is attached to. Read, not managed."
  value       = data.databricks_current_metastore.this.id
}
