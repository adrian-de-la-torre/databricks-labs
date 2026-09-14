# VNet injection ships in the first build, not later.
#
# virtual_network_id, public_subnet_name and private_subnet_name are ForceNew:
# adding them to an existing workspace replaces it. Since a workspace anchors a
# Unity Catalog metastore assignment, that replacement stops being cheap almost
# immediately. The first apply is the only free moment this decision ever has.
resource "azurerm_databricks_workspace" "this" {
  name                = "dbw-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  # Premium is required for Unity Catalog, cluster policies and access control.
  sku = "premium"

  managed_resource_group_name = "rg-${local.suffix}-managed"

  custom_parameters {
    virtual_network_id  = azurerm_virtual_network.this.id
    public_subnet_name  = azurerm_subnet.host.name
    private_subnet_name = azurerm_subnet.container.name

    # Referencing the associations, not the NSG, is what orders the graph
    # correctly: Azure rejects the workspace if the subnets are not already
    # associated with a network security group.
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.host.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.container.id
  }

  # Secure cluster connectivity: cluster nodes get no public IP address.
  public_network_access_enabled = true

  # AllRules, not NoAzureDatabricksRules.
  #
  # NoAzureDatabricksRules tells Azure Databricks to omit the control-plane rules
  # from the network security group, which is correct ONLY for a workspace using
  # back-end Private Link. Without it the group holds worker-to-worker,
  # worker-to-sql, worker-to-storage and worker-to-eventhub, and omits the one
  # rule that matters:
  #
  #   Outbound TCP  VirtualNetwork -> AzureDatabricks  443, 3306, 8443-8451
  #
  # 8443 is the call from the compute plane to the control plane. Without it the
  # node boots, never registers, and the cluster reports "Finding instances for
  # new nodes" until it gives up -- a message about capacity for a problem that
  # is about routing. The rule is named worker-to-databricks-webapp and is
  # documented as Default, meaning always required:
  # https://learn.microsoft.com/azure/databricks/security/network/classic/vnet-inject
  #
  # The field is mutable, but Azure rejects the update while any cluster is
  # active (WorkspaceUpdateNotAllowed), which is circular: the cluster that keeps
  # the workspace locked is the one failing for want of the rule. Terraform
  # records the new value in state even when that call returns 400, so a later
  # plan reports "No changes" over a change that never happened. Terminate every
  # cluster first, and verify against Azure rather than against the plan.
  network_security_group_rules_required = "AllRules"

  customer_managed_key_enabled = false

  tags = local.tags

  # The workspace anchors a Unity Catalog metastore assignment, so deleting it is
  # never cheap. Removing this block is a deliberate, reviewable act.
  lifecycle {
    prevent_destroy = true
  }
}
