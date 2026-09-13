# Registering a storage credential is refused for a service principal even when
# it is a workspace admin and its workspace-admins group holds
# CREATE_STORAGE_CREDENTIAL on the metastore. The error names the access
# connector and a missing Reader role, which is misleading: the same call
# succeeds as a human account admin with the identical connector and roles.
#
# So it lives here, applied once from a laptop, and the governance stack reads it.
# The credential is created once and never changes, so this costs nothing
# operationally.
resource "databricks_storage_credential" "catalog" {
  provider = databricks.workspace

  name  = "sc-dbxlab-${var.environment}"
  owner = databricks_group.platform_admins.display_name

  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  comment = "Managed identity of the access connector owned by the platform stack."
}

resource "databricks_grants" "catalog_credential" {
  provider = databricks.workspace

  storage_credential = databricks_storage_credential.catalog.id

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}
