# Registering a storage credential is refused for a service principal even when
# it is a workspace admin and its workspace-admins group holds
# CREATE_STORAGE_CREDENTIAL on the metastore. The error names the access
# connector and a missing Reader role, which is misleading: the same call
# succeeds as a human account admin with the identical connector and roles.
#
# So it lives here, applied once per workspace from a laptop, and the governance
# stack reads it. The credential is created once and never changes, so this
# costs nothing operationally.
#
# One credential per workspace, because a credential belongs to a metastore and a
# metastore is regional: every region gets its own. The name only carries the
# environment, which is unique within a region by construction.
resource "databricks_storage_credential" "catalog" {
  for_each = local.workspaces

  name  = "sc-dbxlab-${split(".", each.key)[0]}"
  owner = databricks_group.platform_admins.display_name

  azure_managed_identity {
    access_connector_id = each.value.access_connector_id
  }

  comment = "Managed identity of the access connector owned by the platform stack."

  # Workspace API, reached through the account provider. Left unset, the API
  # level is inferred from the provider host, which here is the account console.
  api = "workspace"

  provider_config {
    workspace_id = each.value.workspace_id
  }

  lifecycle {
    # Every external location in the workspace trusts this credential. A plan
    # that wants to replace it has to fail here, not halfway through an apply.
    prevent_destroy = true

    # api only tells the provider how to route the call; it is not a property of
    # the credential. Adding it to a credential created before this stack used
    # provider_config sends an update that the API refuses while an external
    # location depends on it: "has 0 directly dependent external table(s) and 1
    # dependent storage location(s); use force option to update anyway".
    ignore_changes = [api]
  }
}

resource "databricks_grants" "catalog_credential" {
  for_each = local.workspaces

  storage_credential = databricks_storage_credential.catalog[each.key].id

  grant {
    principal  = databricks_group.platform_admins.display_name
    privileges = ["ALL_PRIVILEGES"]
  }

  provider_config {
    workspace_id = each.value.workspace_id
  }
}

# Same reason as the assignment in main.identity.tf: both resources predate the
# workspaces map, and swedencentral was the only workspace.
moved {
  from = databricks_storage_credential.catalog
  to   = databricks_storage_credential.catalog["dev.swedencentral"]
}

moved {
  from = databricks_grants.catalog_credential
  to   = databricks_grants.catalog_credential["dev.swedencentral"]
}
