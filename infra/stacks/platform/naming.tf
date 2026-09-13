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

  tags = {
    workload    = local.workload
    environment = var.environment
    managed_by  = "terraform"
    repository  = "databricks-labs"
  }
}
