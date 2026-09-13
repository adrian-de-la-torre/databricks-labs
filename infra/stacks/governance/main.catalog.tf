locals {
  catalog_name = "dbxlab_${var.environment}"
}

# Read, never create. A metastore is one per region and account-scoped, so it
# spans dev, test and prod at once. Creating one fails; importing one puts a
# resource that accepts force_destroy in the path of a terraform destroy, where a
# mistake would take the governance of an entire region with it.
data "databricks_current_metastore" "this" {}

resource "databricks_storage_credential" "catalog" {
  name  = "sc-${local.catalog_name}"
  owner = var.admin_group

  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  comment = "Managed identity of the access connector owned by the platform stack."
}

resource "databricks_external_location" "catalog" {
  name            = "el-${local.catalog_name}"
  owner           = var.admin_group
  url             = var.catalog_storage_url
  credential_name = databricks_storage_credential.catalog.name

  comment = "ADLS Gen2 container in our own resource group, outliving the workspace."
}

# storage_root is mandatory here, not optional: the auto-provisioned metastore
# has no storage root of its own -- which is the current recommendation -- so a
# catalog without one has nowhere to put managed tables.
resource "databricks_catalog" "this" {
  name         = local.catalog_name
  owner        = var.admin_group
  storage_root = var.catalog_storage_url
  comment      = "Laboratory data for the ${var.environment} environment."

  # A catalog defaults to OPEN, which means every workspace attached to the
  # regional metastore can see it -- including workspaces of other environments.
  # ISOLATED plus an explicit binding is what makes environment separation real
  # rather than aspirational.
  isolation_mode = "ISOLATED"

  properties = {
    environment = var.environment
  }

  depends_on = [databricks_external_location.catalog]
}

resource "databricks_workspace_binding" "catalog" {
  securable_name = databricks_catalog.this.name
  securable_type = "catalog"
  workspace_id   = var.workspace_id
  binding_type   = "BINDING_TYPE_READ_WRITE"
}

# One shared schema. Each laboratory creates its own schema from its bundle, so
# adding an experiment never touches this stack and never waits on an approval.
resource "databricks_schema" "reference" {
  catalog_name = databricks_catalog.this.name
  name         = "reference"
  owner        = var.admin_group
  comment      = "Shared reference data used across laboratories."
}
