locals {
  tags = {
    workload    = "dbxlab"
    environment = "shared"
    managed_by  = "terraform"
    repository  = "databricks-labs"
  }

  github_issuer = "https://token.actions.githubusercontent.com"

  # GitHub presents the IMMUTABLE subject format, which interleaves numeric ids:
  #   repo:<owner>@<owner_id>/<repo>@<repo_id>:<context>
  # The classic repo:<owner>/<repo>:<context> form is what most documentation
  # still shows, and it produces AADSTS700213 with a subject that looks correct.
  #
  # The numeric ids are the point: they survive renaming the account or the
  # repository, so the pipeline does not silently lose its identity the day
  # someone tidies up a name.
  github_subject_prefix = format(
    "repo:%s@%d/%s@%d",
    split("/", var.github_repository)[0], var.github_owner_id,
    split("/", var.github_repository)[1], var.github_repository_id,
  )
}

resource "azurerm_resource_group" "identity" {
  name     = "rg-dbxlab-identity"
  location = var.location
  tags     = local.tags
}

# Two identities, because they hold genuinely different rights: plan may read
# everything and write nothing, apply may create infrastructure. A pull request
# from a branch runs as plan, so a change to the pipeline itself cannot grant
# itself write access before review.
resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-dbxlab-plan"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_user_assigned_identity" "apply" {
  for_each = var.environments

  name                = "id-dbxlab-${each.key}-apply"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

# The subject is what Entra matches against the token GitHub mints. Anything that
# does not match this string exactly gets no token, which is what replaces a
# stored secret.
resource "azurerm_federated_identity_credential" "plan_pull_request" {
  name                      = "github-pull-request"
  user_assigned_identity_id = azurerm_user_assigned_identity.plan.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = local.github_issuer
  subject                   = "${local.github_subject_prefix}:pull_request"
}

resource "azurerm_federated_identity_credential" "apply_environment" {
  for_each = var.environments

  name                      = "github-environment-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.apply[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = local.github_issuer
  subject                   = "${local.github_subject_prefix}:environment:${each.key}"
}
