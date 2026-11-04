# The platform's own privilege on the catalog targets the group. Never a user,
# and never `account users`, which is everyone in the account and would be a
# silent leak as the account grows.
#
# databricks_grant, not databricks_grants. The plural resource is authoritative
# for every principal on the catalog, and this catalog has consumers whose grants
# are not this stack's: on 04/11 a read-only plan proposed revoking USE_CATALOG
# from every principal of the Agent Cost Control deployments in dev and test,
# which an apply would have done. The singular resource is authoritative for its
# own principal only. A grant someone else made survives an apply, and a grant
# declared here is still put back when it drifts.
resource "databricks_grant" "catalog_admins" {
  catalog    = databricks_catalog.this.name
  principal  = var.admin_group
  privileges = ["ALL_PRIVILEGES"]
}

# Consumers, declared by name and resolved to an application id when the plan
# runs, because an application id is an identifier (ADR-0005). Only USE_CATALOG:
# what a consumer may do inside its own schema is granted by whoever owns that
# schema.
#
# People are not declared. A person's principal is an email address, which is an
# identifier too, and with grants that are authoritative per principal leaving
# one out revokes nothing.
data "databricks_service_principal" "catalog_users" {
  for_each = var.catalog_users.service_principals

  display_name = each.value
}

data "databricks_app" "catalog_users" {
  for_each = var.catalog_users.apps

  name = each.value
}

resource "databricks_grant" "catalog_service_principals" {
  for_each = data.databricks_service_principal.catalog_users

  catalog    = databricks_catalog.this.name
  principal  = each.value.application_id
  privileges = ["USE_CATALOG"]
}

# An App's principal is created with the App, so it is found through the App's
# name rather than through a display name that Databricks generates.
resource "databricks_grant" "catalog_apps" {
  for_each = data.databricks_app.catalog_users

  catalog    = databricks_catalog.this.name
  principal  = each.value.app.service_principal_client_id
  privileges = ["USE_CATALOG"]
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

# Until 04/11 one databricks_grants held every grant on the catalog. It is
# forgotten without revoking anything, and each declared principal's existing
# privileges are adopted rather than granted again, so the change reaches
# Databricks as nothing at all.
#
# These blocks serve that migration only, and go once governance has been
# applied in every deployment. Left in place they stop the next consumer: a
# principal that holds no grant yet has nothing to import, and its plan fails
# with "Cannot import non-existent remote object" (checked on 04/11, read-only).
removed {
  from = databricks_grants.catalog

  lifecycle {
    destroy = false
  }
}

import {
  to = databricks_grant.catalog_admins
  id = "catalog/${local.catalog_name}/${var.admin_group}"
}

import {
  for_each = data.databricks_service_principal.catalog_users

  to = databricks_grant.catalog_service_principals[each.key]
  id = "catalog/${local.catalog_name}/${each.value.application_id}"
}

import {
  for_each = data.databricks_app.catalog_users

  to = databricks_grant.catalog_apps[each.key]
  id = "catalog/${local.catalog_name}/${each.value.app.service_principal_client_id}"
}
