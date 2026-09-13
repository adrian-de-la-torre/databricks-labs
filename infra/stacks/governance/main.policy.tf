# The real cost control. Budget alerts tell you money is gone; a policy stops it
# leaving. Every rule here is a prohibition the user cannot override, which is
# what makes "a cluster left running over the weekend" impossible rather than
# merely detectable.
resource "databricks_cluster_policy" "laboratory" {
  name = "laboratory-${var.environment}"

  definition = jsonencode({
    # fixed, not defaultValue: the field disappears from the UI and cannot be
    # raised, disabled, or quietly edited in a job definition.
    "autotermination_minutes" = {
      type  = "fixed"
      value = var.autotermination_minutes
    }

    # isOptional matters more than it looks. Without it the field is REQUIRED,
    # which bans single-node clusters outright -- a cost-control policy that
    # forbids the cheapest configuration there is. The ceiling still applies to
    # any cluster that does autoscale.
    "autoscale.max_workers" = {
      type         = "range"
      maxValue     = var.max_workers
      defaultValue = 2
      isOptional   = true
    }

    # Node families verified against this workspace with
    # `databricks clusters list-node-types`. No GPU family is listed, so nobody
    # starts one by accident.
    "node_type_id" = {
      type = "allowlist"
      values = [
        "Standard_D4ds_v6",
        "Standard_D4s_v3",
        "Standard_DS3_v2",
      ]
      defaultValue = "Standard_D4s_v3"
    }

    "driver_node_type_id" = {
      type         = "allowlist"
      values       = ["Standard_D4ds_v6", "Standard_D4s_v3", "Standard_DS3_v2"]
      defaultValue = "Standard_D4s_v3"
    }

    # Unity Catalog requires a single-user or shared access mode. Fixing it here
    # keeps a laboratory from silently falling back to no-isolation clusters,
    # which cannot read a Unity Catalog table at all.
    "data_security_mode" = {
      type         = "allowlist"
      values       = ["SINGLE_USER", "USER_ISOLATION"]
      defaultValue = "SINGLE_USER"
    }

    # Spot instances are excellent for generating data and disqualifying for
    # measuring it: an eviction mid-run invalidates any timing you publish.
    # On-demand is the default; a laboratory that wants spot says so explicitly.
    "azure_attributes.availability" = {
      type         = "allowlist"
      values       = ["ON_DEMAND_AZURE", "SPOT_WITH_FALLBACK_AZURE"]
      defaultValue = "ON_DEMAND_AZURE"
    }

    # Cost attribution per laboratory. The tag flows to the underlying VMs, so
    # system.billing.usage can answer "what did lab 001 cost" without estimating.
    "custom_tags.lab" = {
      type         = "unlimited"
      defaultValue = "unassigned"
    }
  })

  max_clusters_per_user = 2
}

resource "databricks_permissions" "laboratory_policy" {
  cluster_policy_id = databricks_cluster_policy.laboratory.id

  access_control {
    group_name       = var.admin_group
    permission_level = "CAN_USE"
  }
}
