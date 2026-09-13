# Azure CAF resource abbreviations, one place. Every name in this stack derives
# from here, so a rename is a single edit and tflint can enforce the tag set.
locals {
  workload = "dbxlab"

  location_short = {
    francecentral      = "frc"
    germanywestcentral = "gwc"
    northeurope        = "neu"
    swedencentral      = "sdc"
    uksouth            = "uks"
    ukwest             = "ukw"
    westeurope         = "weu"
  }[var.location]

  suffix = "${local.workload}-${var.environment}-${local.location_short}"

  # Storage account names are globally unique, lowercase alphanumeric, 3-24 chars.
  # The hash keeps it deterministic: the same subscription, environment and region
  # always produce the same name, so it is not a random value in state.
  storage_account_name = substr(
    "st${local.workload}${var.environment}${local.location_short}${substr(sha256("${data.azurerm_subscription.current.subscription_id}-${var.environment}-${var.location}"), 0, 8)}",
    0, 24
  )

  tags = {
    workload    = local.workload
    environment = var.environment
    managed_by  = "terraform"
    repository  = "databricks-labs"
  }
}
