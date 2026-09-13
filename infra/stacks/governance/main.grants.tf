# Every privilege targets the group. Never a user, and never `account users`,
# which is everyone in the account and would be a silent leak as the account grows.
resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  grant {
    principal = var.admin_group
    privileges = [
      "ALL_PRIVILEGES",
    ]
  }
}

resource "databricks_grants" "external_location" {
  external_location = databricks_external_location.catalog.id

  grant {
    principal = var.admin_group
    privileges = [
      "ALL_PRIVILEGES",
    ]
  }
}
