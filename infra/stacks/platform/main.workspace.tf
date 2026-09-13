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
  public_network_access_enabled         = true
  network_security_group_rules_required = "NoAzureDatabricksRules"
  customer_managed_key_enabled          = false

  tags = local.tags

  # The workspace anchors a Unity Catalog metastore assignment, so deleting it is
  # never cheap. Removing this block is a deliberate, reviewable act.
  lifecycle {
    prevent_destroy = true
  }
}
