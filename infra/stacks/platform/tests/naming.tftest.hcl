# What this stack promises about names and tags, asserted without Azure.
#
# mock_provider means no credentials, no network and no DBUs: this runs in
# seconds on every commit. `command = plan` is deliberate — every value asserted
# here is derived from configuration, so apply would add cost and prove nothing.
#
# The negative runs matter more than the positive one. A validation block that
# rejects nothing still passes `terraform validate`, and the failure only shows
# up the day someone deploys to a region where Azure Databricks does not exist.
# `expect_failures` is what makes those blocks load-bearing.

mock_provider "azurerm" {}

variables {
  environment   = "dev"
  location      = "swedencentral"
  address_space = "10.10.0.0/24"
}

run "names_and_tags_derive_from_naming_tf" {
  command = plan

  # The CAF suffix, region abbreviation included. If location_short loses an
  # entry or the suffix order changes, every name in the stack moves at once
  # and this is the assertion that says so.
  assert {
    condition     = azurerm_resource_group.this.name == "rg-dbxlab-dev-sdc"
    error_message = "resource group name is not rg-<workload>-<environment>-<region abbreviation>"
  }

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-dbxlab-dev-sdc"
    error_message = "virtual network name does not follow the naming.tf suffix"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.name == "dbw-dbxlab-dev-sdc"
    error_message = "workspace name does not follow the naming.tf suffix"
  }

  # The managed resource group is created by Azure, not by this stack, and a
  # collision with the stack's own resource group fails the deployment late.
  assert {
    condition     = azurerm_databricks_workspace.this.managed_resource_group_name != azurerm_resource_group.this.name
    error_message = "the managed resource group name collides with the stack resource group"
  }

  # TFLint enforces the tag SET by exact string comparison against .tflint.hcl.
  # Nothing enforced the tag VALUES until here, so a typo in naming.tf passed
  # the gate and reached Azure.
  # tomap is required, not decoration: tags is map(string) and a bare object
  # literal is an object type, so `==` compares different types and never
  # matches. The first version of this assertion failed for exactly that reason.
  assert {
    condition = azurerm_resource_group.this.tags == tomap({
      workload    = "dbxlab"
      environment = "dev"
      managed_by  = "terraform"
      repository  = "databricks-labs"
    })
    error_message = "the four tag keys and their values must match naming.tf and .tflint.hcl character for character"
  }

  # Storage account names are globally unique, lowercase alphanumeric, 3-24
  # chars, and this one is a substr of a hash. The exact value depends on the
  # subscription id, which is mocked here, so the invariant is asserted instead
  # of the string: that is the constraint Azure actually rejects on.
  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", azurerm_storage_account.catalog.name))
    error_message = "catalog storage account name is not 3-24 lowercase alphanumeric characters"
  }

  assert {
    condition     = azurerm_network_security_perimeter.this.name == "nsp-dbxlab-dev-sdc"
    error_message = "network security perimeter name does not follow the naming.tf suffix"
  }

  # The regional tag, never the global one, and spelled the way Azure spells it.
  # A tag that names no region matches nothing, so the failure would show up as
  # serverless compute losing the catalog, not as a plan error.
  assert {
    condition     = azurerm_network_security_perimeter_access_rule.serverless.service_tags == tolist(["AzureDatabricksServerless.SwedenCentral"])
    error_message = "the perimeter must admit the regional AzureDatabricksServerless tag of the workspace region"
  }

  # Enforced mode bypasses the storage account's own firewall, which is what
  # admits classic clusters and the access connector. Learning is not a phase
  # here; it is the configuration Databricks recommends keeping.
  assert {
    condition     = azurerm_network_security_perimeter_association.catalog.access_mode == "Learning"
    error_message = "the catalog storage association must stay in Learning (transition) mode"
  }
}

# The UK regions are where a naive capitalisation of the location goes wrong:
# the tag is UKSouth, not Uksouth.
run "serverless_tag_spells_the_region_the_way_azure_does" {
  command = plan

  variables {
    location = "uksouth"
  }

  assert {
    condition     = azurerm_network_security_perimeter_access_rule.serverless.service_tags == tolist(["AzureDatabricksServerless.UKSouth"])
    error_message = "service tag region spelling does not match Azure's for uksouth"
  }
}

# Azure Databricks does not exist in every region, and the variable says so.
run "rejects_a_region_without_azure_databricks" {
  command = plan

  variables {
    location = "spaincentral"
  }

  expect_failures = [var.location]
}

run "rejects_an_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

# A /32 has no room for the two /25 subnets a VNet-injected workspace needs.
run "rejects_an_address_space_without_room_for_two_subnets" {
  command = plan

  variables {
    address_space = "10.10.0.0/32"
  }

  expect_failures = [var.address_space]
}
