# Explicit outbound, and it is not optional.
#
# Verified empirically rather than assumed: with no NAT gateway and
# defaultOutboundAccess = true on both subnets, a VNet-injected cluster acquires
# a VM, the VM reaches "running", and the cluster never leaves PENDING. Databricks
# recycles the node after a timeout and launches another, indefinitely. The node
# boots but cannot reach the control plane, and nothing in the cluster state says
# so -- the message stays "Finding instances for new nodes".
#
# Azure's implicit outbound access is being retired and does not carry a
# secure-cluster-connectivity workspace. A NAT gateway is the supported path.
#
# It is billed per resource-hour (~0.045 USD/h), NOT as a monthly fee, so
# enable_nat_gateway = false between laboratory sessions costs nothing to toggle
# and saves roughly 33 USD a month. The platform is unusable while it is off,
# which is the honest trade rather than a hidden one.
resource "azurerm_public_ip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "pip-nat-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  name                    = "nat-${local.suffix}"
  resource_group_name     = azurerm_resource_group.this.name
  location                = azurerm_resource_group.this.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

# Both subnets. The container subnet carries the executors and the host subnet
# the driver; either one without egress leaves the cluster unable to register.
resource "azurerm_subnet_nat_gateway_association" "host" {
  count = var.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.host.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

resource "azurerm_subnet_nat_gateway_association" "container" {
  count = var.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.container.id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
